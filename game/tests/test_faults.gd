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
		m.jam_chance_per_sec = 0.0


func test_overheat_at_100() -> void:
	var f := Factory.new(_cfg(), 1)
	_quiet(f)
	var m := f.get_machine("proc_a")
	m.heat_per_sec = 50.0
	assert_true(_run_until(f, func(): return m.state == Machine.State.OVERHEATED))
	assert_eq(m.heat, 100.0)


func test_vent_reduces_heat() -> void:
	var f := Factory.new(_cfg(), 1)
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
	f.step()
	assert_eq(f.request_action("generator"), Factory.ActionResult.NOTHING_TO_DO)


func test_crew_busy_rejects_second() -> void:
	var f := Factory.new(_cfg(), 1)
	f.step()
	f.get_machine("proc_a").state = Machine.State.JAMMED
	f.get_machine("proc_b").state = Machine.State.JAMMED
	assert_eq(f.request_action("proc_a"), Factory.ActionResult.STARTED_REPAIR)
	assert_true(f.crew_busy)
	assert_eq(f.request_action("proc_b"), Factory.ActionResult.CREW_BUSY)
	assert_eq(f.crew_target, "proc_a")


func test_repair_clears_fault() -> void:
	var f := Factory.new(_cfg(), 1)
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
	for i in 1799:
		f.step()
	assert_true(not f.is_over())
	f.step()
	assert_true(f.is_over())
	assert_eq(f.target, 100)
