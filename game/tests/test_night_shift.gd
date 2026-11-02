extends TestCase

const P := "user://t_night.json"


func _roster() -> Array[Bot]:
	return Career.new(SimConfig.load_tier(1), 5).roster


func test_cap_and_24h_not_more_than_8h() -> void:
	var r := NightShift.load_rules()
	var cap := int(r["cap_seconds"])
	var a := NightShift.estimate(_roster(), cap, 3)
	var b := NightShift.estimate(_roster(), cap * 3, 3)
	assert_eq(b["commendations"], a["commendations"])
	assert_eq(b["mess_level"], a["mess_level"])
	assert_true(int(b["commendations"]) <= int(r["max_commendations"]))
	assert_true(int(b["mess_level"]) <= int(r["max_mess"]))
	for secs in [200, 3600, 20000, 10000000]:
		assert_true(int(NightShift.estimate(_roster(), secs, 9)["commendations"]) <= int(r["max_commendations"]))


func test_short_absence_nothing() -> void:
	var e := NightShift.estimate(_roster(), 60, 1)
	assert_eq(e["commendations"], 0)
	assert_eq((e["lines"] as Array).size(), 0)


func test_clock_backwards_forwards() -> void:
	var r := NightShift.load_rules()
	var cap := int(r["cap_seconds"])
	assert_eq(NightShift.away_seconds(1000, 5000, r), 0)  # clock set backwards
	assert_eq(NightShift.away_seconds(5000 + cap * 10, 5000, r), cap)  # forward is capped
	assert_eq(NightShift.away_seconds(1000, 0, r), 0)  # no last_seen
	assert_eq(NightShift.next_last_seen(1000, 5000), 5000)  # never moves backwards


func test_clock_change_cannot_farm() -> void:
	var m := Meta.new()
	var ros := _roster()
	m.last_seen_unix = 1_000_000
	var t0 := 1_000_000 + 8 * 3600
	var rep := m.night_check(t0, ros, 1)
	assert_true(not rep.is_empty())
	var got := m.collect_night()
	assert_true(got > 0)
	m.pending_night = {}
	assert_eq(m.collect_night(), 0)
	# set the clock back a day, return (nothing), set it forward again to t0: nothing more to earn
	assert_true(m.night_check(t0 - 86400, ros, 2).is_empty())
	assert_true(m.night_check(t0 + 60, ros, 3).is_empty())
	assert_eq(m.last_seen_unix, t0)


func test_uncollected_report_not_rerolled() -> void:
	var m := Meta.new()
	m.last_seen_unix = 1000
	var a := m.night_check(1000 + 4 * 3600, _roster(), 1)
	var b := m.night_check(1000 + 9 * 3600, _roster(), 77)
	assert_eq(a["commendations"], b["commendations"])
	assert_eq(a["lines"], b["lines"])


func test_determinism() -> void:
	var a := NightShift.estimate(_roster(), 20000, 4)
	var b := NightShift.estimate(_roster(), 20000, 4)
	assert_eq(a, b)
	var n := (a["lines"] as Array).size()
	assert_true(n >= 3 and n <= 5, "3-5 lines, got %d" % n)


func test_lessons_lower_mess() -> void:
	var ros := _roster()
	var before := 0.0
	var after := 0.0
	for b in ros:
		before += NightShift.bot_mess_rate(b)
		for k: String in Bot.MISTAKES:
			b.levels[k] = 2
		after += NightShift.bot_mess_rate(b)
	assert_true(after < before)


func test_mess_only_mid_career() -> void:
	var cfg := SimConfig.load_tier(1)
	var c := Career.new(cfg, 11)
	c.night_mess = 3
	var f1 := c.start_day()  # day 1: none
	var jam1 := 0
	for m in f1.machines:
		jam1 += 1 if m.state == Machine.State.JAMMED else 0
	assert_eq(jam1, 0)
	assert_eq(c.night_mess, 0)
	c.next_day()
	c.night_mess = 3
	var f2 := c.start_day()
	var jam2 := 0
	for m in f2.machines:
		jam2 += 1 if m.state == Machine.State.JAMMED else 0
	assert_eq(jam2, 3)
	var meta := Meta.new()
	meta.pending_night = {"commendations": 1, "mess_level": 2, "lines": [], "collected": true}
	assert_eq(meta.take_mess(1), 0)  # a new career's day 1
	meta.pending_night = {"commendations": 1, "mess_level": 2, "lines": [], "collected": true}
	assert_eq(meta.take_mess(2), 2)
	assert_true(meta.pending_night.is_empty())


func test_save_round_trip_and_corrupt() -> void:
	var m := Meta.new()
	m.last_seen_unix = 12345
	m.pending_night = {"commendations": 4, "mess_level": 2, "lines": ["a", "b", "c"], "collected": false}
	assert_true(SaveIO.write_meta(m, P))
	var r := SaveIO.load_meta(P, P + ".bad", P + ".legacy")
	assert_eq(r.last_seen_unix, 12345)
	assert_eq(r.pending_night["commendations"], 4)
	assert_eq(r.pending_night["mess_level"], 2)
	assert_eq(r.pending_night["lines"], ["a", "b", "c"])
	var bad := Meta.from_dict({"last_seen_unix": "zz", "pending_night": {"commendations": "x", "mess_level": 99, "lines": 5}})
	assert_eq(bad.last_seen_unix, 0)
	assert_eq(bad.pending_night["mess_level"], 3)
	assert_eq(Meta.from_dict({"pending_night": [1]}).pending_night, {})
	DirAccess.remove_absolute(ProjectSettings.globalize_path(P))
