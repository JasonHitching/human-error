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
