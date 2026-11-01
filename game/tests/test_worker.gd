extends TestCase


func _fac(seed: int = 1) -> Factory:
	var f := Factory.new(SimConfig.load_default(), seed)
	for m in f.machines:
		if m.bot != null:
			m.bot.rates = {}
			m.bot.sloppy = 0.0
	return f


func _put(f: Factory) -> void:
	f._qa_items.append({"defect": "", "decoy": "", "bot": "Test"})
	f.get_machine("qa_desk").input_count += 1


func _trip_ticks() -> int:
	var c := SimConfig.load_default()
	return roundi(c.transition_seconds * c.tick_rate)


func test_starts_in_office() -> void:
	var f := _fac()
	assert_eq(f.worker_location(), Worker.Location.OFFICE)
	assert_true(f.worker_at_desk())


func test_trip_takes_configured_ticks() -> void:
	var n := _trip_ticks()
	assert_true(n > 0, "transition_seconds > 0 in balance.json")
	var f := _fac()
	assert_true(f.go_to_floor())
	for i in n - 1:
		f.step()
		assert_eq(f.worker_location(), Worker.Location.TRANSIT, "tick %d" % i)
	f.step()
	assert_eq(f.worker_location(), Worker.Location.FLOOR)
	assert_eq(f.worker.ticks_in[Worker.Location.TRANSIT], n)
	var bal := SimConfig._read(SimConfig.BALANCE_PATH)
	bal["transition_seconds"] = 1.5
	var g := Factory.new(SimConfig.from_dicts(SimConfig._read(SimConfig.MACHINES_PATH), bal), 1)
	g.go_to_floor()
	for i in 14:
		g.step()
	assert_eq(g.worker_location(), Worker.Location.TRANSIT)
	g.step()
	assert_eq(g.worker_location(), Worker.Location.FLOOR)


func test_go_is_noop_when_there_or_heading() -> void:
	var f := _fac()
	assert_true(f.go_to_office(), "already in office")
	assert_eq(f.worker.trips, 0)
	f.go_to_floor()
	f.step()
	f.go_to_floor()
	assert_eq(f.worker.trips, 1, "already heading to floor")
	assert_eq(f.transit_target(), Worker.Location.FLOOR)


func test_inspect_blocked_on_floor_and_in_transit() -> void:
	var f := _fac()
	_put(f)
	f.go_to_floor()
	f.step()
	assert_eq(f.inspect(true), Factory.InspectResult.NOT_AT_DESK, "transit")
	for i in _trip_ticks():
		f.step()
	assert_eq(f.worker_location(), Worker.Location.FLOOR)
	assert_eq(f.inspect(true), Factory.InspectResult.NOT_AT_DESK, "floor")
	assert_eq(f.qa_queue().size(), 1)
	f.go_to_office()
	for i in _trip_ticks():
		f.step()
	assert_eq(f.inspect(true), Factory.InspectResult.SHIPPED, "back at desk")


func test_tap_blocked_in_office_and_transit() -> void:
	var f := _fac()
	f.get_machine("proc_a").overclocked = true
	assert_eq(f.request_action("proc_a"), Factory.ActionResult.NOT_ON_FLOOR, "office")
	f.go_to_floor()
	f.step()
	assert_eq(f.request_action("proc_a"), Factory.ActionResult.NOT_ON_FLOOR, "transit")
	assert_true(not f.crew_busy)
	for i in _trip_ticks():
		f.step()
	assert_eq(f.request_action("proc_a"), Factory.ActionResult.STARTED_FIX, "floor")


func test_cannot_leave_floor_mid_job() -> void:
	var f := _fac()
	f.worker.place(Worker.Location.FLOOR)
	f.get_machine("proc_a").state = Machine.State.JAMMED
	assert_eq(f.request_action("proc_a"), Factory.ActionResult.STARTED_REPAIR)
	assert_true(not f.go_to_office(), "refused while crew busy")
	assert_eq(f.worker_location(), Worker.Location.FLOOR)
	for i in 200:
		if not f.crew_busy:
			break
		f.step()
	assert_true(f.go_to_office(), "allowed once the job is done")


func test_idle_on_floor_only_when_nothing_to_fix() -> void:
	var f := _fac()
	_put(f)
	f.worker.place(Worker.Location.FLOOR)
	f.step()
	assert_eq(f.idle_ticks, 1, "on floor with nothing to fix is idle even with a queue")
	f.get_machine("proc_a").overclocked = true
	f.step()
	assert_eq(f.idle_ticks, 1, "on floor with something to fix is not idle")


func test_replay_with_trips() -> void:
	var cfg := SimConfig.load_default()
	var a := Factory.new(cfg, 4)
	var rng := Autoplayers.make_rng(4)
	for i in 1200:
		Autoplayers.act("greedy", a, rng)
		a.step()
	assert_true(a.worker.trips > 2, "greedy made trips")
	var b := Factory.replay(cfg, 4, a.actions, 1200)
	assert_eq(a.worker.trips, b.worker.trips)
	assert_eq(a.worker.ticks_in, b.worker.ticks_in)
	assert_eq(a.worker_location(), b.worker_location())
	assert_eq(a.shipped, b.shipped)
	assert_eq(a.complaints, b.complaints)
	assert_eq(a.idle_ticks, b.idle_ticks)
	assert_eq(a.fault_counts, b.fault_counts)


func _walk_cfg(speed: float) -> SimConfig:
	var bal := SimConfig._read(SimConfig.BALANCE_PATH)
	bal["walk_speed"] = speed
	return SimConfig.from_dicts(SimConfig._read(SimConfig.MACHINES_PATH), bal)


func _quiet(f: Factory) -> Factory:
	for m in f.machines:
		if m.bot != null:
			m.bot.rates = {}
			m.bot.sloppy = 0.0
	f.worker.place(Worker.Location.FLOOR)
	return f


func test_arrives_at_stairs() -> void:
	var f := _fac()
	f.go_to_floor()
	for i in _trip_ticks():
		f.step()
	assert_eq(f.worker_location(), Worker.Location.FLOOR)
	assert_eq(f.worker.floor_pos, SimConfig.load_default().stairs)


func test_walk_time_matches_distance_over_speed() -> void:
	var cfg := _walk_cfg(0.5)  # 0.05 units/tick
	var f := _quiet(Factory.new(cfg, 1))
	var gen := f.get_machine("generator")
	var dist := cfg.stairs.distance_to(gen.pos)
	var want := ceili(dist / (0.5 / cfg.tick_rate))
	assert_eq(want, 9, "stairs (0.08,0.06) -> generator (0.5,0.08) is 0.42 units")
	assert_eq(f.worker.walk_ticks_to(gen.pos), want)
	gen.overclocked = true
	assert_eq(f.request_action("generator"), Factory.ActionResult.STARTED_FIX)
	assert_true(not f.go_to_office(), "walking to a job counts as busy")
	for i in want:
		assert_true(f.crew_walking(), "walking, tick %d" % i)
		f.step()
	assert_true(not f.crew_walking(), "arrived")
	assert_eq(f.worker.floor_pos, gen.pos)
	assert_eq(f.worker.walk_ticks, want)
	assert_eq(f.crew_progress, 0.0, "job timer starts on arrival")


func test_job_starts_on_arrival() -> void:
	var cfg := _walk_cfg(0.5)
	var f := _quiet(Factory.new(cfg, 1))
	var a := f.get_machine("proc_a")
	a.misrouted = true
	var walk := f.worker.walk_ticks_to(a.pos)
	var job := roundi(cfg.fix_seconds * cfg.tick_rate)
	assert_true(walk > 0)
	f.request_action("proc_a")
	for i in walk + job - 1:
		f.step()
	assert_true(a.misrouted and f.crew_busy, "not done one tick early")
	f.step()
	assert_true(not a.misrouted and not f.crew_busy, "done after walk + job ticks")
	var g := _quiet(Factory.new(_walk_cfg(0.0), 1))  # walk_speed 0: instant, the old behaviour
	g.get_machine("proc_a").misrouted = true
	g.request_action("proc_a")
	for i in job:
		g.step()
	assert_true(not g.get_machine("proc_a").misrouted)


func test_queued_fix_runs_next_and_can_be_cancelled() -> void:
	var cfg := _walk_cfg(0.5)
	var f := _quiet(Factory.new(cfg, 1))
	var a := f.get_machine("proc_a")
	var b := f.get_machine("proc_b")
	a.misrouted = true
	b.misrouted = true
	f.request_action("proc_a")
	assert_eq(f.request_action("proc_b"), Factory.ActionResult.QUEUED)
	assert_eq(f.request_action("proc_b"), Factory.ActionResult.UNQUEUED, "tap again cancels")
	assert_eq(f.crew_queue.size(), 0)
	assert_eq(f.request_action("proc_b"), Factory.ActionResult.QUEUED)
	var first := f.worker.walk_ticks_to(a.pos) + roundi(cfg.fix_seconds * cfg.tick_rate)
	for i in first:
		f.step()
	assert_true(not a.misrouted)
	assert_eq(f.crew_target, "proc_b", "queued fix runs next")
	assert_true(f.crew_walking())
	assert_eq(f.crew_queue.size(), 0)
	var second := f.worker.walk_ticks_to(b.pos) + roundi(cfg.fix_seconds * cfg.tick_rate)
	assert_eq(f.worker.walk_ticks_to(b.pos), ceili(a.pos.distance_to(b.pos) / (0.5 / cfg.tick_rate)), "walks from proc_a")
	for i in second:
		f.step()
	assert_true(not b.misrouted and not f.crew_busy)


func test_leaving_walks_to_stairs_first() -> void:
	var cfg := _walk_cfg(0.5)
	var f := _quiet(Factory.new(cfg, 1))
	var a := f.get_machine("proc_a")
	a.misrouted = true
	f.request_action("proc_a")
	for i in 200:
		if not f.crew_busy:
			break
		f.step()
	var back := f.worker.walk_ticks_to(cfg.stairs)
	assert_true(back > 0)
	assert_true(f.go_to_office())
	for i in back:
		assert_eq(f.worker_location(), Worker.Location.FLOOR, "walking to the stairs")
		f.step()
	assert_eq(f.worker_location(), Worker.Location.TRANSIT)
	for i in _trip_ticks():
		f.step()
	assert_eq(f.worker_location(), Worker.Location.OFFICE)
	assert_eq(f.worker.trips, 1)


func test_tap_on_the_way_out_turns_back() -> void:
	var cfg := _walk_cfg(0.5)
	var f := _quiet(Factory.new(cfg, 1))
	f.worker.floor_pos = f.get_machine("assembler").pos
	f.go_to_office()
	f.step()
	f.get_machine("proc_b").misrouted = true
	assert_eq(f.request_action("proc_b"), Factory.ActionResult.STARTED_FIX)
	assert_eq(f.transit_target(), Worker.Location.FLOOR)
	for i in 200:
		f.step()
	assert_eq(f.worker_location(), Worker.Location.FLOOR, "stayed on the floor")
	assert_true(not f.get_machine("proc_b").misrouted)


func test_replay_with_walks_and_queued_fixes() -> void:
	var cfg := SimConfig.load_default()
	var a := Factory.new(cfg, 6)
	var rng := Autoplayers.make_rng(6)
	var mem := {}
	var queued := 0
	for i in 1200:
		Autoplayers.act("careful", a, rng, mem)
		if not a.crew_queue.is_empty():
			queued += 1
		a.step()
	assert_true(a.worker.walk_ticks > 0, "walked")
	assert_true(queued > 0, "queued fixes")
	var b := Factory.replay(cfg, 6, a.actions, 1200)
	assert_eq(a.worker.walk_ticks, b.worker.walk_ticks)
	assert_eq(a.worker.floor_pos, b.worker.floor_pos)
	assert_eq(a.worker.ticks_in, b.worker.ticks_in)
	assert_eq(a.shipped, b.shipped)
	assert_eq(a.complaints, b.complaints)
	assert_eq(a.fault_counts, b.fault_counts)
	assert_eq(a.idle_ticks, b.idle_ticks)
