extends TestCase


func _cfg(mods: Dictionary = {}) -> SimConfig:
	var bal := {"tick_rate": 10, "shift_seconds": 180, "target": 100, "ramp_start": 1.0, "ramp_end": 1.0, "repair_seconds": 2.0, "vent_seconds": 1.0, "vent_min_heat": 50, "vent_cool_per_sec": 40, "repair_mode": "tap"}
	bal.merge(mods, true)
	var fac := SimConfig._read(SimConfig.MACHINES_PATH)
	return SimConfig.from_dicts(fac, bal)


func _run_until(f: Factory, pred: Callable, max_ticks: int = 3000) -> bool:
	for i in max_ticks:
		if pred.call():
			return true
		f.step()
	return pred.call()


func _quiet(f: Factory) -> void:
	for m in f.machines:
		if m.bot != null:
			m.bot.rates = {}


func test_overheat_at_100() -> void:
	var f := Factory.new(_cfg(), 1)
	f.worker.place(Worker.Location.FLOOR)  # crew jobs need the worker on the floor
	_quiet(f)
	var m := f.get_machine("proc_a")
	m.heat_per_sec = 50.0
	assert_true(_run_until(f, func(): return m.state == Machine.State.OVERHEATED))
	assert_eq(m.heat, 100.0)


func test_vent_reduces_heat() -> void:
	var f := Factory.new(_cfg(), 1)
	f.worker.place(Worker.Location.FLOOR)  # crew jobs need the worker on the floor
	_quiet(f)
	var m := f.get_machine("generator")
	m.heat = 90.0
	f.step()
	assert_eq(f.request_action("generator"), Factory.ActionResult.STARTED_VENT)
	for i in 5:
		f.step()
	assert_true(m.heat < 80.0, "heat=%f" % m.heat)
	assert_true(m.venting)


func test_nothing_to_do() -> void:
	var f := Factory.new(_cfg(), 1)
	f.worker.place(Worker.Location.FLOOR)  # crew jobs need the worker on the floor
	f.step()
	assert_eq(f.request_action("generator"), Factory.ActionResult.NOTHING_TO_DO)


func test_crew_busy_rejects_second() -> void:
	var f := Factory.new(_cfg(), 1)
	f.worker.place(Worker.Location.FLOOR)  # crew jobs need the worker on the floor
	f.step()
	f.get_machine("proc_a").state = Machine.State.JAMMED
	f.get_machine("proc_b").state = Machine.State.JAMMED
	f.get_machine("assembler").state = Machine.State.JAMMED
	assert_eq(f.request_action("proc_a"), Factory.ActionResult.STARTED_REPAIR)
	assert_true(f.crew_busy)
	assert_eq(f.request_action("proc_b"), Factory.ActionResult.QUEUED, "second tap queues")
	assert_eq(f.request_action("assembler"), Factory.ActionResult.QUEUED)
	assert_eq(f.request_action("proc_a"), Factory.ActionResult.CREW_BUSY, "current job")
	assert_eq(f.crew_target, "proc_a")
	assert_eq(f.crew_queue, ["proc_b", "assembler"] as Array[String])


func test_repair_clears_fault() -> void:
	var f := Factory.new(_cfg(), 1)
	f.worker.place(Worker.Location.FLOOR)  # crew jobs need the worker on the floor
	_quiet(f)
	f.step()
	var m := f.get_machine("proc_a")
	m.state = Machine.State.OVERHEATED
	m.heat = 100.0
	f.request_action("proc_a")
	for i in 19:
		f.step()
	assert_true(m.is_faulted(), "still repairing")
	f.step()
	assert_true(not m.is_faulted())
	assert_true(m.heat < 1.0, "heat reset, got %f" % m.heat)
	assert_true(not f.crew_busy)


func test_hold_release_cancels() -> void:
	var f := Factory.new(_cfg({"repair_mode": "hold"}), 1)
	f.worker.place(Worker.Location.FLOOR)  # crew jobs need the worker on the floor
	f.step()
	var m := f.get_machine("proc_a")
	m.state = Machine.State.JAMMED
	f.request_action("proc_a")
	for i in 10:
		f.step()
	assert_true(f.crew_progress > 0.4, "progress=%f" % f.crew_progress)
	f.release_action()
	assert_true(not f.crew_busy)
	assert_eq(f.crew_progress, 0.0)
	for i in 50:
		f.step()
	assert_true(m.is_faulted(), "not repaired after release")


func test_jam_ramp_and_determinism() -> void:
	var cfg := _cfg({"ramp_start": 1.0, "ramp_end": 3.0})
	var a := Factory.new(cfg, 5)
	a.go_to_floor()
	for i in 900:
		if i % 40 == 0:
			for m in a.machines:
				if m.is_faulted():
					a.request_action(m.id)
					break
		a.step()
	var b := Factory.replay(cfg, 5, a.actions, 900)
	assert_eq(a.shipped, b.shipped)
	assert_eq(a.fault_counts, b.fault_counts)
	assert_eq(a.rng.randi(), b.rng.randi())
	assert_true(a.fault_counts["JAMMED"] + a.fault_counts["OVERHEATED"] > 0)


func test_shift_over() -> void:
	var f := Factory.new(_cfg(), 1)
	f.worker.place(Worker.Location.FLOOR)  # crew jobs need the worker on the floor
	for i in 1799:
		f.step()
	assert_true(not f.is_over())
	f.step()
	assert_true(f.is_over())
	assert_eq(f.target, 100)


func _repaired_overheat(grace: float) -> Array:
	var f := Factory.new(_cfg({"fix_grace_seconds": grace}), 1)
	f.worker.place(Worker.Location.FLOOR)
	_quiet(f)
	var m := f.get_machine("proc_a")
	m.heat_per_sec = 50.0
	_run_until(f, func(): return m.state == Machine.State.OVERHEATED)
	f.request_action("proc_a")
	_run_until(f, func(): return not m.is_faulted())
	return [f, m]


func test_grace_blocks_same_fault_only_for_window() -> void:
	var r := _repaired_overheat(4.0)
	var f: Factory = r[0]
	var m: Machine = r[1]
	for i in 35:  # 3.5 s < 4 s grace, heat gain is 50/s
		f.step()
		assert_true(m.state != Machine.State.OVERHEATED, "re-overheated inside grace")
	assert_eq(f.fix_recurrences, 0)
	assert_true(_run_until(f, func(): return m.state == Machine.State.OVERHEATED, 100), "fault possible after grace")


func test_no_grace_recurs_immediately() -> void:
	var r := _repaired_overheat(0.0)
	var f: Factory = r[0]
	var m: Machine = r[1]
	assert_true(_run_until(f, func(): return m.state == Machine.State.OVERHEATED, 50))
	assert_eq(f.fix_recurrences, 1)


func test_grace_does_not_block_a_different_fault() -> void:
	var r := _repaired_overheat(30.0)
	var f: Factory = r[0]
	var m: Machine = r[1]
	m.bot.rates = {"jam": 600000.0}
	assert_true(_run_until(f, func(): return m.state == Machine.State.JAMMED, 100), "jam blocked by overheat grace")


func test_grace_replay_is_deterministic() -> void:
	var cfg := _cfg({"ramp_start": 1.0, "ramp_end": 3.0, "fix_grace_seconds": 6.0})
	var a := Factory.new(cfg, 5)
	a.go_to_floor()
	for i in 900:
		if i % 40 == 0:
			for m in a.machines:
				if m.is_faulted():
					a.request_action(m.id)
					break
		a.step()
	var b := Factory.replay(cfg, 5, a.actions, 900)
	assert_eq(a.fault_counts, b.fault_counts)
	assert_eq(a.fix_recurrences, b.fix_recurrences)
	assert_eq(a.rng.randi(), b.rng.randi())
