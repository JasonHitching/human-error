extends TestCase
## Day phases: clock_in -> shift -> end_of_day. The sim clock only runs in the shift; dialogue picks are seeded.


func _career(mode: String, seed: int) -> Career:
	return Career.new(SimConfig.load_mode(mode), seed)


func test_clock_only_runs_in_shift() -> void:
	for mode in ["full", "core"]:
		var c := _career(mode, 3)
		var f := c.start_day()
		assert_eq(c.phase, Career.PHASE_CLOCK_IN)
		assert_true(not c.step(f))
		assert_eq(f.tick, 0)
		assert_true(c.start_shift())
		assert_true(not c.start_shift())
		for _i in 50:
			c.step(f)
		assert_eq(f.tick, 50)
		c.end_day(f)
		assert_eq(c.phase, Career.PHASE_END_OF_DAY)
		assert_true(not c.step(f))
		assert_eq(f.tick, 50)
		c.next_day()
		c.start_day()
		assert_eq(c.phase, Career.PHASE_CLOCK_IN)


func _replay(seed: int) -> Array:
	var c := _career("core", seed)
	var out: Array = []
	for _d in 3:
		var f := c.start_day()
		out.append(c.clock_in())
		c.start_shift()
		for _i in 200:
			c.step(f)
		var res := c.end_day(f)
		out.append([f.tick, res["shipped"], c.reaction(res)])
		c.next_day()
	return out


func test_replay_identical() -> void:
	assert_eq(str(_replay(7)), str(_replay(7)))
	assert_true(str(_replay(7)) != str(_replay(8)))


func test_core_bots_have_three_clock_in_lines() -> void:
	var d := Dialogue.new()
	var cfg := SimConfig.load_mode("core")
	assert_true(not cfg.bot_defs.is_empty())
	for b: Dictionary in cfg.bot_defs:
		assert_true(d.bot_lines(String(b["name"])).size() >= 3, String(b["name"]))
	for key in ["hit", "bonus", "miss"]:
		assert_true(d.foreman_lines("foreman_reaction", key).size() >= 1, key)


func test_line_choice_is_seeded_and_leaves_career_rng_alone() -> void:
	var c := _career("core", 5)
	c.start_day()
	var state := c.rng.state
	var a := c.clock_in()
	assert_eq(c.rng.state, state)
	assert_eq(str(a), str(_career_clock_in(5)))
	var seen := {}
	for s in 30:
		seen[str(_career_clock_in(s))] = true
	assert_true(seen.size() > 3)


func _career_clock_in(seed: int) -> Dictionary:
	var c := _career("core", seed)
	c.start_day()
	return c.clock_in()
