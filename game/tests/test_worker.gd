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
