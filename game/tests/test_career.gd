extends TestCase


func _c(seed: int = 1) -> Career:
	return Career.new(SimConfig.load_default(), seed)


func _fake(c: Career, shipped: int) -> Dictionary:
	var f := c.start_day()
	f.shipped = shipped
	return c.end_day(f)


func test_target_and_rate_scale_by_day() -> void:
	var c := _c()
	var cfg := c.config
	cfg.twist_start_day = 99  # no twist: the base scaling is what is tested here
	var f1 := c.start_day()
	assert_eq(f1.target, cfg.target_base)
	assert_near(f1.day_mult, 1.0)
	c.day = 4
	var f4 := c.start_day()
	assert_eq(f4.target, cfg.target_base + cfg.target_per_day * 3)
	assert_near(f4.day_mult, pow(cfg.day_rate_mult, 3))


func test_strikes_fire_at_max() -> void:
	var c := _c()
	c.day = c.config.probation_days + 1  # past probation
	var r := _fake(c, 0)
	assert_eq(r["strikes"], 1)
	assert_true(not r["fired"])
	for _i in c.config.max_strikes - 1:
		r = _fake(c, 0)
	assert_true(r["fired"] and c.fired)


func test_points_and_bonus() -> void:
	var c := _c()
	var r := _fake(c, c.day_target())
	assert_eq(r["points"], 1)
	assert_true(r["hit"])
	r = _fake(c, int(ceil(c.day_target() * c.config.bonus_threshold)))
	assert_eq(r["points"], 3)


func test_offers_distinct_deterministic() -> void:
	var a := _c(5).offers()
	var b := _c(5).offers()
	assert_eq(a, b)
	assert_eq(a.size(), _c().config.offers_per_review)
	var seen := {}
	for o in a:
		assert_true(not seen.has(o["text"]), "dup offer")
		seen[o["text"]] = true


func test_train_lowers_rate_and_persists() -> void:
	var c := _c()
	var f1 := c.start_day()
	var bot: Bot = f1.machines[0].bot
	var mistake := "jam"
	var before := bot.rate_per_tick(mistake, 10, 1.0, 1.0)
	c.points = 1
	c.apply({"kind": "train", "bot": bot.name, "mistake": mistake})
	assert_eq(c.points, 0)
	c.next_day()
	var f2 := c.start_day()
	var same: Bot = null
	for m in f2.machines:
		if m.bot != null and m.bot.name == bot.name:
			same = m.bot
	assert_true(same == bot, "same bot object persists")
	assert_near(same.rate_per_tick(mistake, 10, 1.0, 1.0), before * c.config.train_factor, 1e-9)


func test_crew_speed_upgrade() -> void:
	var c := _c()
	c.points = 1
	c.apply({"kind": "crew_speed"})
	assert_near(c.crew_speed, c.config.crew_speed_upgrade)
	assert_near(c.start_day().crew_speed, c.config.crew_speed_upgrade)


func test_same_seed_same_career() -> void:
	var out: Array = []
	for _i in 2:
		var c := _c(3)
		var log: Array = []
		for _d in 3:
			var f := c.start_day()
			for _t in 600:
				f.step()
			log.append(c.end_day(f))
			c.points = 1
			var o := c.offers()
			log.append(o[0]["text"])
			c.apply(o[0])
			c.next_day()
		out.append(log)
	assert_eq(out[0], out[1])


func test_foreman_lines() -> void:
	var c := _c()
	c.day = 3
	for k in ["start", "hit", "miss", "fired"]:
		assert_true(c.foreman_line(k) != "", k)
	assert_true(not c.foreman_line("start").contains("{"))


func test_no_twist_on_days_1_and_2() -> void:
	var c := _c()
	c.twists.twist_chance = 1.0
	for d in [1, 2]:
		c.day = d
		assert_true(c.twist().is_empty())
		assert_eq(c.start_day().twist_id, "")
	c.day = 3
	assert_true(not c.twist().is_empty())
	assert_eq(c.start_day().twist_id, c.twist()["id"])


func test_twists_deterministic_and_never_repeat() -> void:
	for s in 20:
		var a := _c(s)
		var b := _c(s)
		a.twists.twist_chance = 0.8
		b.twists.twist_chance = 0.8
		var prev := ""
		for d in range(1, 30):
			a.day = d
			b.day = d
			var id: String = a.twist().get("id", "")
			assert_eq(id, b.twist().get("id", ""))
			if d < 3:
				assert_eq(id, "")
			elif id != "":
				assert_true(id != prev, "seed %d day %d repeats %s" % [s, d, prev])
			prev = id


func test_each_twist_applies_and_reverts() -> void:
	var c := _c()
	var cfg := c.config
	var plain := Factory.new(cfg, 1)
	for t in c.twists.defs:
		var f := Factory.new(cfg, 1)
		f.apply_twist(t)
		assert_eq(f.twist_id, t["id"])
		match t["id"]:
			"heatwave":
				assert_near(f.heat_mult, 1.2)
				assert_near(f.overclock_mult, 1.25)
			"rush_order":
				assert_near(f.line_speed, 1.1)
			"inspection_day":
				assert_true(f.complaint_penalty > cfg.complaint_penalty)
				assert_true(f.decoy_chance > cfg.decoy_chance)
			"power_flicker":
				assert_true(f.flicker_every > 0)
				var out := 0
				for _i in 600:
					f.step()
					out += 1 if f.power_out() else 0
				assert_true(out > 0, "power never flickered")
	# rush order raises the quota, then the next twist-free day is back to normal
	c.day = 3
	var rush: Dictionary = c.twists.get_def("rush_order")
	assert_true(roundi(float(c.day_target()) * float(rush["target_mult"])) > c.day_target())
	assert_near(plain.heat_mult, 1.0)
	assert_eq(plain.complaint_penalty, cfg.complaint_penalty)
	c.day = 2
	var f2 := c.start_day()
	assert_eq(f2.target, c.day_target())
	assert_near(f2.line_speed, 1.0)
	assert_eq(f2.complaint_penalty, cfg.complaint_penalty)


func _twist_days(chance: float, seed: int = 1) -> Array[bool]:
	var t := Twists.new(seed, 3)
	t.twist_chance = chance
	var out: Array[bool] = []
	for d in range(1, 40):
		out.append(not t.for_day(d).is_empty())
	return out


func test_twist_chance_zero_and_one() -> void:
	for s in 5:
		var none := _twist_days(0.0, s)
		var all := _twist_days(1.0, s)
		for i in none.size():
			assert_true(not none[i], "chance 0 gave a twist")
			assert_eq(all[i], i + 1 >= 3, "chance 1 day %d" % (i + 1))


func test_twist_chance_default_is_partial() -> void:
	var n := 0
	for s in 20:
		for b in _twist_days(Twists.new(s, 3).twist_chance, s):
			n += 1 if b else 0
	assert_true(n > 20 * 37 * 0.5 and n < 20 * 37 * 0.9, "twist share %d" % n)


func test_twist_yardstick_math() -> void:
	var ys := TwistStats.new()
	# day 3: 10 twist (5 failed), 10 plain (1 failed); day 4: 20 twist (4 failed), 20 plain (4 failed)
	# day 5: only 9 plain -> not pooled -> not pooled
	for i in 10:
		ys.add(3, true, i < 5)
		ys.add(3, false, i < 1)
		ys.add(5, true, true)
	for i in 20:
		ys.add(4, true, i < 4)
		ys.add(4, false, i < 4)
	ys.add(5, true, true)
	for i in 9:
		ys.add(5, false, false)
	assert_eq(ys.eligible_days(), [3, 4])
	var r := ys.pooled()
	# weights 20 and 40: twist (20*.5+40*.2)/60 = .3; plain (20*.1+40*.2)/60 = 1/6
	assert_near(r["twist"], 0.3)
	assert_near(r["plain"], 1.0 / 6.0)
	assert_near(r["ratio"], 1.8)
