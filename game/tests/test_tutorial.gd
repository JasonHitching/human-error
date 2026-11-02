extends TestCase
## Day-1 tutorial (#97): steps fire once and in order, skip persists, save round trip, sim untouched.

const P := "user://t_tut.json"
const B := "user://t_tut.bad.json"
const L := "user://t_tut_stats.json"


func _tut() -> Tutorial:
	var t := Tutorial.new()
	t.start()
	return t


func test_steps_are_data() -> void:
	var s := Tutorial.load_steps()
	assert_eq(s.size(), 3)
	for st: Dictionary in s:
		for k: String in ["id", "trigger", "text", "target"]:
			assert_true(st.has(k), "step has " + k)


func test_steps_fire_once_and_in_order() -> void:
	var t := _tut()
	t.observe({"desk_item": true, "offers": true})  # later triggers wait for the first step
	assert_true(t.fired.is_empty())
	t.observe({"fault": true})
	assert_eq(t.fired, ["fix"] as Array[String])
	t.observe({"fault": true})  # still true: no second firing
	assert_eq(t.fired.size(), 1)
	t.observe({"fault": true, "crew_busy": true})  # do-this done
	t.observe({"desk_item": true})
	assert_eq(t.fired, ["fix", "inspect"] as Array[String])
	t.dismiss()
	t.observe({"offers": true})
	assert_eq(t.fired, ["fix", "inspect", "train"] as Array[String])
	var done := [false]
	t.finished.connect(func(_s: bool) -> void: done[0] = true)
	t.dismiss()
	assert_true(done[0])
	assert_true(not t.active)
	t.observe({"fault": true})
	assert_eq(t.fired.size(), 3, "nothing fires after finishing")


func test_skip_finishes_and_persists() -> void:
	var t := _tut()
	var got: Array = []
	t.finished.connect(func(s: bool) -> void: got.append(s))
	t.skip()
	t.skip()
	assert_eq(got, [true])
	var m := Meta.new()
	assert_true(not m.tutorial_done)
	m.tutorial_done = true
	for p: String in [P, B, L, P + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	SaveIO.write_meta(m, P)
	assert_true(SaveIO.load_meta(P, B, L).tutorial_done)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(P))


func test_save_round_trip_and_corrupt() -> void:
	var m := Meta.new()
	m.tutorial_done = true
	assert_eq(Meta.from_dict(m.to_dict()).to_dict(), m.to_dict())
	assert_true(not Meta.from_dict({}).tutorial_done, "missing = not done")
	assert_true(not Meta.from_dict({"tutorial_done": "banana"}).tutorial_done)
	assert_true(not Meta.from_dict({"tutorial_done": [1]}).tutorial_done)
	assert_true(Meta.from_dict({"tutorial_done": 1}).tutorial_done)


func _run(with_tutorial: bool) -> Array:
	var f := Factory.new(SimConfig.load_default(), 1)
	var t := Tutorial.new()
	if with_tutorial:
		t.start()
	for i in 1800:
		f.step()
		if with_tutorial:
			t.observe(Tutorial.snapshot(f, i % 50 == 0))
	return [f.shipped, f.score(), f.tick, f.complaints]


func test_sim_identical_with_tutorial() -> void:
	assert_eq(_run(true), _run(false))
