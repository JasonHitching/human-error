extends TestCase

const P := "user://test_perks_save.json"


func _cfg() -> SimConfig:
	return SimConfig.load_default()


func _meta(bal: int) -> Meta:
	var m := Meta.new()
	m.commendations = {"balance": bal, "earned": bal}
	return m


func test_buy_rules_and_save() -> void:
	var m := _meta(50)
	assert_true(not m.buy("forgive"))  # costs 60
	assert_true(not m.buy("nope"))
	assert_true(m.buy("shelf"))  # 30
	assert_eq(m.balance(), 20)
	assert_true(not m.buy("shelf"))  # owned
	assert_true(SaveIO.write_meta(m, P))
	var m2 := SaveIO.load_meta(P, P + ".bad", "user://none.json")
	assert_true(m2.owns("shelf"))
	assert_eq(m2.balance(), 20)


func test_no_perks_matches_baseline() -> void:
	var a := Career.new(_cfg(), 5)
	var b := Career.new(_cfg(), 5, [])
	var fa := a.start_day()
	var fb := b.start_day()
	assert_eq(fa.shelf_slots, fb.shelf_slots)
	assert_eq(fa.crew_speed, fb.crew_speed)
	assert_eq(a.offers().size(), 3)
	assert_eq(a.banner_news(), "")


func test_shelf_and_repair_apply_without_leak() -> void:
	var base := Career.new(_cfg(), 5).start_day()
	var f := Career.new(_cfg(), 5, ["shelf", "repair"]).start_day()
	assert_eq(f.shelf_slots, base.shelf_slots + 1)
	assert_true(absf(f.crew_speed - base.crew_speed * 0.9) < 0.0001)
	var again := Career.new(_cfg(), 5).start_day()
	assert_eq(again.shelf_slots, base.shelf_slots)
	assert_eq(again.crew_speed, base.crew_speed)


func test_choice_adds_offer() -> void:
	var c := Career.new(_cfg(), 5, ["choice"])
	assert_eq(c.offers().size(), 4)
	assert_eq(Career.new(_cfg(), 5).offers().size(), 3)


func test_lesson_levels_one_bot_deterministically() -> void:
	var total := func(c: Career) -> int:
		var n := 0
		for b in c.roster:
			for k: String in b.levels:
				n += int(b.levels[k])
		return n
	assert_eq(total.call(Career.new(_cfg(), 7, ["lesson"])), 1)
	assert_eq(total.call(Career.new(_cfg(), 7)), 0)
	var a := Career.new(_cfg(), 7, ["lesson"])
	var b := Career.new(_cfg(), 7, ["lesson"])
	assert_eq(a.banner_news(), b.banner_news())
	assert_true(a.banner_news().contains("PERKS: Orientation"))


func _miss(c: Career, shipped: int = 0) -> void:
	var f := c.start_day()
	f.shipped = shipped
	f.target = 99
	c.end_day(f)
	c.next_day()


func test_grace_extends_probation() -> void:
	var c := Career.new(_cfg(), 3)
	_miss(c)
	_miss(c)
	assert_eq(c.strikes, 1)
	var g := Career.new(_cfg(), 3, ["grace"])
	_miss(g, 60)
	_miss(g, 60)
	assert_eq(g.strikes, 0)
	_miss(g, 60)
	assert_eq(g.strikes, 1)
	var z := Career.new(_cfg(), 3, ["grace", "forgive"])  # doing nothing gets no mercy
	_miss(z)
	_miss(z)
	assert_eq(z.strikes, 1)


func test_forgive_once_per_career() -> void:
	var c := Career.new(_cfg(), 3, ["forgive"])
	_miss(c, 60)  # probation
	_miss(c, 60)  # forgiven
	assert_eq(c.strikes, 0)
	_miss(c, 60)
	assert_eq(c.strikes, 1)
	assert_eq(Career.new(_cfg(), 3, ["forgive"]).strikes, 0)  # fresh career, fresh forgiveness


func test_determinism_with_perks() -> void:
	var perks := ["shelf", "repair", "lesson", "choice"]
	var runs: Array = []
	for _i in 2:
		var c := Career.new(_cfg(), 9, perks)
		var f := c.start_day()
		var prng := Autoplayers.make_rng(9001)
		var mem := {}
		for _t in 600:
			Autoplayers.act("greedy", f, prng, mem)
			f.step()
		runs.append([f.shipped, f.complaints])
	assert_eq(runs[0], runs[1])
