extends TestCase


func test_pitch_steps_and_cap() -> void:
	var f := Feel.new()
	for i in 10:
		assert_eq(f.pitch_steps(), mini(i, 7))
		f.on_call(true, true, false, false)
	assert_eq(f.pitch_steps(), 7)


func test_sfx_pitch_changes_length_content() -> void:
	var s := Sfx.new()
	s.params = {"volume": 0.3, "ship": {"pitch": 500, "pitch_end": 500, "length": 0.05, "volume": 1.0}}
	assert_true(s.render("ship", 0) != s.render("ship", 7))
	assert_true(s.render("ship", 99) == s.render("ship", 7))
	s.free()


func test_deflate_on_break() -> void:
	var f := Feel.new()
	f.on_call(true, true, false, false)
	var snd := f.on_call(true, false, false, true)
	assert_true("deflate" in snd)
	assert_eq(f.streak, 0)
	assert_true(not ("deflate" in f.on_call(true, false, false, true)))


func test_milestones_fanfare_gold() -> void:
	var f := Feel.new()
	var got := false
	for i in 5:
		got = "fanfare" in f.on_call(false, true, false, false)
	assert_true(got)
	assert_true(f.gold_t > 0.0)


func test_effects_decay_to_zero() -> void:
	var f := Feel.new()
	f.on_call(false, true, true, false)
	f.on_call(true, false, false, true)
	assert_true(f.shake_offset() != Vector2.ZERO or f.shake_t == 0.0)
	for i in 120:
		f.update(0.016)
	assert_true(f.is_quiet())
	assert_eq(f.shake_offset(), Vector2.ZERO)


func test_alert_rate_limit() -> void:
	var f := Feel.new()
	f.update(10.0)
	assert_true(f.allow_alert())
	f.update(1.0)
	assert_true(not f.allow_alert())
	f.update(3.0)
	assert_true(f.allow_alert())


func test_haptics_noop_without_support() -> void:
	assert_true(not Haptics.supported())
	assert_true(not Haptics.pulse(30))
