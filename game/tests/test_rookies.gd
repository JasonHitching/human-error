extends TestCase


func _career(seed: int = 1) -> Career:
	return Career.new(SimConfig.load_default(), seed)


func _names(c: Career) -> Array:
	var out: Array = []
	for b in c.roster:
		out.append(b.name)
	return out


func test_rookie_joins_on_configured_day_deterministic() -> void:
	var a := _career(3)
	var b := _career(3)
	var before := _names(a).size()
	for d in range(1, 5):
		a.day = d
		b.day = d
		a.start_day()
		b.start_day()
		if d < 4:
			assert_eq(a.rookies_joined, 0)
	assert_eq(a.rookies_joined, 1)
	assert_eq(a.arrival["name"], "Pip")
	assert_eq(_names(a), _names(b))
	assert_eq(_names(a).size(), before)  # layout is full: it replaced someone
	assert_true(_names(a).has("Pip"))
	assert_true(a.arrival_line().contains("Pip"))
	a.day = 4
	a.start_day()  # same day again: no second rookie
	assert_eq(a.rookies_joined, 1)


func test_rookie_replaces_most_trained() -> void:
	var c := _career(2)
	c.roster[1].levels["jam"] = 3
	var victim := c.roster[1].name
	c.day = 4
	c.start_day()
	assert_eq(c.arrival["replaced"], victim)
	assert_eq(c.roster[1].name, "Pip")
	assert_true(c.roster[1].rookie)


func test_three_rookies_by_day_ten() -> void:
	var c := _career(5)
	for d in range(1, 11):
		c.day = d
		c.start_day()
	assert_eq(c.rookies_joined, 3)


func test_learning_after_n_fixes_once() -> void:
	var b := Bot.from_dict({"name": "T", "rates": {"jam": 6.0}}, 0.6, 0.5)
	var base := b.rate_per_tick("jam", 10, 1.0, 1.0)
	assert_true(not b.note_fix("jam", 3, 1.0, 0.0))
	assert_true(not b.note_fix("jam", 3, 1.0, 0.0))
	assert_true(b.note_fix("jam", 3, 1.0, 0.0))
	assert_near(b.rate_per_tick("jam", 10, 1.0, 1.0), base * 0.5, 1e-9)
	assert_true(not b.note_fix("jam", 3, 1.0, 0.0))  # only once per mistake type
	assert_near(b.rate_per_tick("jam", 10, 1.0, 1.0), base * 0.5, 1e-9)


func test_failed_roll_keeps_trying() -> void:
	var b := Bot.from_dict({"name": "T", "rates": {"jam": 6.0}}, 0.6, 0.5)
	for i in 3:
		assert_true(not b.note_fix("jam", 3, 0.5, 0.9))
	assert_true(b.note_fix("jam", 3, 0.5, 0.1))


func test_factory_fixes_teach_bot_deterministically() -> void:
	var out: Array = []
	for _run in 2:
		var cfg := SimConfig.load_default()
		cfg.learn_after = 2
		cfg.learn_chance = 1.0
		var f := Factory.new(cfg, 9)
		f.worker.place(Worker.Location.FLOOR)
		var m: Machine = null
		for x in f.machines:
			if x.bot != null:
				m = x
				break
		for i in 2:
			m.misrouted = true
			f.request_action(m.id)
			for _t in 200:
				f.step()
			assert_true(not m.misrouted)
		out.append(f.lessons.duplicate())
		assert_true(m.bot.learned.has("misroute"))
	assert_eq(out[0].size(), 1)
	assert_eq(out[0], out[1])
