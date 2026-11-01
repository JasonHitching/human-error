extends TestCase


func _cfg(mods: Dictionary = {}) -> SimConfig:
	var bal := {"tick_rate": 10, "shift_seconds": 180, "target": 100, "ramp_start": 1.0, "ramp_end": 1.0, "repair_seconds": 2.0, "vent_seconds": 1.0, "vent_min_heat": 50, "vent_cool_per_sec": 40, "repair_mode": "tap",
		"max_active_problems": 2, "breather_seconds": 7.0, "breather_shrink_per_day": 0.3, "breather_floor": 3.0, "wave_seconds": 0.0}
	bal.merge(mods, true)
	return SimConfig.from_dicts(SimConfig._read(SimConfig.MACHINES_PATH), bal)


func _pacing(mods: Dictionary = {}, day: int = 1) -> Pacing:
	var r := RandomNumberGenerator.new()
	r.seed = 1
	var p := Pacing.new(_cfg(mods), r)
	p.day = day
	return p


func test_soft_cap() -> void:
	var p := _pacing()
	p.step(1)
	assert_true(p.allows(), "1 of 2 allowed")
	p.note_mistake()
	assert_true(not (p.allows()), "2 active blocks more")
	p.step(2)
	assert_true(not (p.allows()), "still capped")
	assert_eq(_pacing({}, 6).max_problems(), 3)


func test_breather_length_and_shrink() -> void:
	var p := _pacing()
	p.step(1)
	p.step(0)
	assert_true(p.calm_started, "calm began")
	var n := 0
	while not p.allows() and n < 1000:
		p.step(0)
		n += 1
	assert_eq(n, 69, "7 s breather (70 ticks incl. start)")
	assert_near(_pacing({}, 1).breather_seconds(), 7.0)
	assert_near(_pacing({}, 5).breather_seconds(), 5.8)
	assert_near(_pacing({}, 40).breather_seconds(), 3.0)


func test_delayed_mistake_still_fires() -> void:
	var f := Factory.new(_cfg(), 3)
	var held := 0
	var fired := 0
	for i in 3000:
		f.step()
		fired = f.mistake_log.size()
		if f.pacing.active >= 2 and not f.pacing.allows():
			held += 1
	assert_true(held > 0, "cap held something back")
	assert_true(fired > 0, "mistakes still fire")


func test_deterministic_and_cap_respected() -> void:
	var a := Factory.new(_cfg(), 7)
	var b := Factory.new(_cfg(), 7)
	for i in 1500:
		a.step()
		b.step()
	assert_eq(a.mistake_log.size(), b.mistake_log.size())
	assert_eq(a.shipped, b.shipped)
	assert_eq(a.pacing.active, b.pacing.active)
