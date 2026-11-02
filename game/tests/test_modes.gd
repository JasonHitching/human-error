extends TestCase
## Game modes (data/modes/*.json): a switched-off system never fires.


func _core() -> SimConfig:  # every switch off, on the tier_1 layout (the real core layout is tested below)
	var c := SimConfig.load_mode("full")
	for k: String in SimConfig.FEATURES:
		c.features[k] = false
	c.decoy_chance = 0.0
	return c


func _only_on(id: String) -> SimConfig:
	var c := _core()
	c.features[id] = true
	return c


func test_modes_load() -> void:
	assert_true(SimConfig.load_mode("full").is_valid())
	assert_true(_core().is_valid())
	assert_true(SimConfig.load_mode("core").is_valid())
	assert_true(not SimConfig.load_mode("nope").is_valid())
	for id: String in SimConfig.FEATURES:
		assert_true(SimConfig.load_default().feature(id), id)
		assert_true(not _core().feature(id), id)


func test_full_equals_tier_1() -> void:
	var a := SimConfig.load_default()
	var b := SimConfig.load_tier(1)
	assert_eq(a.decoy_chance, b.decoy_chance)
	assert_eq(a.machines.size(), b.machines.size())
	assert_eq(a.shift_seconds, b.shift_seconds)


func test_mistakes_never_fire_when_off() -> void:
	for seed in 5:
		var c := Career.new(_core(), seed + 1)
		for d in range(1, 8):
			c.day = d
			var f := c.start_day()
			f.worker.place(Worker.Location.FLOOR)
			for i in 3000:
				f.step()
			assert_eq(int(f.mistake_counts["misroute"]), 0)
			assert_eq(int(f.mistake_counts["wrong_recipe"]), 0)
	# ... and with only misroute on they do happen, so the test can fail
	var n := 0
	for seed in 5:
		var f := Factory.new(_only_on("misroute"), seed + 1)
		f.day_mult = 3.0
		for i in 3000:
			f.step()
		n += int(f.mistake_counts["misroute"])
	assert_true(n > 0, "misroute fires when on")


func test_twists_off() -> void:
	var on := Career.new(_only_on("twists"), 1)
	var off := Career.new(_core(), 1)
	var saw := false
	for d in range(1, 15):
		on.day = d
		off.day = d
		assert_true(off.twist().is_empty())
		saw = saw or not on.twist().is_empty()
	assert_true(saw)


func test_spec_change_and_subtle_back_off() -> void:
	for seed in 20:
		for d in range(1, 20):
			var s := QaSpec.for_day(_core(), seed, d)
			assert_eq(s["change"], "")
			assert_eq(s["extra"].size() + s["allowed"].size(), 0)
			assert_eq(s["subtle_share"], 0.0)
			assert_eq(s["back_share"], 0.0)
	var on := QaSpec.for_day(SimConfig.load_default(), 1, 12)
	assert_true(on["subtle_share"] > 0.0 and on["back_share"] > 0.0)
	assert_true(QaSpec.for_day(_only_on("subtle_defects"), 1, 12)["back_share"] == 0.0)


func test_decoys_off() -> void:
	assert_eq(_core().decoy_chance, 0.0)
	var f := Factory.new(_core(), 1)
	for i in 3000:
		f.step()
	for it in f.qa_queue():
		assert_eq(it["decoy"], "")


func test_rookies_off() -> void:
	var c := Career.new(_core(), 3)
	for d in range(1, 12):
		c.day = d
		c.start_day()
	assert_eq(c.rookies_joined, 0)


func test_bot_learning_off() -> void:
	var f := Factory.new(_core(), 1)
	var m := f.get_machine("assembler")
	m.overclocked = true
	for i in 10:
		f._note_fixed(m, Factory.ActionResult.STARTED_FIX)
	assert_eq(f.lessons.size(), 0)
	assert_eq(m.bot.fixes.size(), 0)


func test_extra_offers_off() -> void:
	var c := Career.new(_core(), 1)
	for r in 200:
		c.day = 1 + r % 10
		c.history.append({})
		for o in c.offers():
			assert_true(not ["radio", "auto_inspect", "supervise"].has(o["kind"]), o["kind"])
			if o["kind"] == "train":
				assert_true(o["mistake"] != "misroute" and o["mistake"] != "wrong_recipe")
	var on := Career.new(_only_on("offers_extra"), 1)
	var saw := false
	for r in 200:
		on.day = 1 + r % 10
		on.history.append({})
		for o in on.offers():
			saw = saw or o["kind"] == "radio"
	assert_true(saw)


func test_perks_off() -> void:
	var c := Career.new(_core(), 1, ["repair", "shelf"])
	assert_true(c.meta_perks.is_empty())
	var m := Meta.new()
	m.features = {"perks": false}
	m.commendations = {"balance": 500}
	assert_true(not m.buy("shelf"))


func test_meta_systems_off() -> void:
	var m := Meta.new()
	m.features = _core().features
	var r := m.award({"days": 10, "automated": true, "automation_bonus": 30})
	assert_eq(r["total"], 0)
	assert_eq(m.balance(), 0)
	m.unlock_after(1)
	assert_eq(m.tier, 1)
	m.pick_tier(2)
	assert_eq(m.picked_tier, 1)
	var d := m.note_daily("2026-01-02", 5)
	assert_true(not d["first"] and not d["new_best"])
	m.last_seen_unix = 1000
	assert_true(m.night_check(1000 + 100000, Career.new(_core(), 1).roster, 1).is_empty())
	var on := Meta.new()
	assert_true(on.award({"days": 10, "automated": true, "automation_bonus": 30})["total"] > 0)


func test_core_factory_two_machines_two_bots() -> void:
	var c := SimConfig.load_mode("core")
	assert_true(c.is_valid(), str(c.errors))
	var working: Array[String] = []
	for m: Dictionary in c.machines:
		if m["type"] != "qa" and m["type"] != "warehouse":
			working.append(String(m["id"]))
	assert_eq(working.size(), 2)
	var pool: Array[String] = []
	for d: Dictionary in c.bot_defs:
		pool.append(String(d["name"]))
		assert_eq(float(d["rates"]["misroute"]), 0.0)
		assert_eq(float(d["rates"]["wrong_recipe"]), 0.0)
	var car := Career.new(c, 1)
	assert_eq(car.roster.size(), 2)
	for b in car.roster:
		assert_true(pool.has(b.name), b.name)
	var f := car.start_day()
	for id in working:
		assert_true(f.bot_for(id) != null, id)
	# every machine is reachable along belts from the generator
	var seen := {"hopper": true}
	var todo: Array[String] = ["hopper"]
	while not todo.is_empty():
		var cur: String = todo.pop_back()
		for l: Dictionary in c.links:
			if l["from"] == cur and not seen.has(l["to"]):
				seen[l["to"]] = true
				todo.append(String(l["to"]))
	assert_eq(seen.size(), c.machines.size())
