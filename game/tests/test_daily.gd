extends TestCase

const RULES := {"daily_first_bonus": 5}


func _play(seed_value: int) -> Array:
	var cfg := SimConfig.load_tier(Daily.TIER)
	var c := Career.new(cfg, seed_value, [])
	var out: Array = []
	while not c.fired and c.day <= 4:
		var f := c.start_day()
		var prng := Autoplayers.make_rng(c.seed * 1000 + c.day)
		var mem := {}
		for _t in int(cfg.shift_seconds * cfg.tick_rate):
			Autoplayers.act("human_careful", f, prng, mem)
			f.step()
		out.append(c.end_day(f)["points"])
	return out


func test_same_date_same_career() -> void:
	assert_eq(Daily.seed_for("2026-01-01"), Daily.seed_for("2026-01-01"))
	assert_eq(_play(Daily.seed_for("2026-01-01")), _play(Daily.seed_for("2026-01-01")))


func test_different_dates_differ() -> void:
	assert_true(Daily.seed_for("2026-01-01") != Daily.seed_for("2026-01-02"))
	assert_true(Daily.seed_for("2026-01-01") > 0)


func test_best_streak_round_trip() -> void:
	var m := Meta.new()
	var r := m.note_daily("2026-03-01", 6, RULES)
	assert_true(r["first"] and r["new_best"])
	assert_eq(r["bonus"], 5)
	m.note_daily("2026-03-02", 4, RULES)
	assert_eq(m.daily_streak, 2)
	m.note_daily("2026-03-02", 9, RULES)
	var m2 := Meta.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	assert_eq(m2.daily_best_for("2026-03-02"), 9)
	assert_eq(m2.daily_best_for("2026-03-01"), 6)
	assert_eq(m2.daily_streak, 2)
	assert_eq(m2.daily_last, "2026-03-02")
	m2.note_daily("2026-03-05", 1, RULES)
	assert_eq(m2.daily_streak, 1)


func test_clock_backwards_keeps_best_no_double_bonus() -> void:
	var m := Meta.new()
	m.note_daily("2026-03-10", 7, RULES)
	var bal := m.balance()
	var r := m.note_daily("2026-03-10", 3, RULES)  # replay: lower, same day
	assert_true(not r["first"])
	assert_eq(m.daily_best_for("2026-03-10"), 7)
	r = m.note_daily("2026-03-02", 5, RULES)  # clock set back to an unplayed older date
	assert_true(not r["first"])
	assert_eq(r["bonus"], 0)
	assert_eq(m.balance(), bal)
	assert_eq(m.daily_last, "2026-03-10")
	assert_eq(m.daily_best_for("2026-03-10"), 7)


func test_cap_30_and_corrupt_safe() -> void:
	var m := Meta.new()
	for i in 40:
		m.note_daily("2026-01-%02d" % (i % 28 + 1) if i < 28 else "2026-02-%02d" % (i - 27), i, RULES)
	assert_true(m.daily_best.size() <= Daily.KEEP)
	var bad := Meta.from_dict({"daily_best": {"junk": 3, "2026-01-01": "x"}, "daily_streak": "a", "daily_last": 5})
	assert_eq(bad.daily_best.size(), 1)
	assert_eq(bad.daily_streak, 0)
	assert_eq(bad.daily_last, "")
	assert_eq(Meta.from_dict({"daily_best": [1, 2]}).daily_best.size(), 0)
