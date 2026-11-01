extends TestCase


func _fac(seed: int = 1) -> Factory:
	var f := Factory.new(SimConfig.load_default(), seed)
	f.worker.place(Worker.Location.FLOOR)  # crew jobs need the worker on the floor
	return f


func _names(f: Factory) -> Array:
	var out: Array = []
	for m in f.machines:
		out.append(m.bot.name if m.bot != null else "-")
	return out


func test_deal_deterministic_no_duplicates() -> void:
	assert_eq(_names(_fac(7)), _names(_fac(7)))
	var any_diff := false
	for s in range(1, 12):
		var n := _names(_fac(s))
		var seen := {}
		for x: String in n:
			if x != "-":
				assert_true(not seen.has(x), "duplicate %s" % x)
				seen[x] = true
		assert_eq(n[n.size() - 1], "-")
		any_diff = any_diff or n != _names(_fac(1))
	assert_true(any_diff, "dealing should vary by seed")


func test_zero_jam_rate_never_jams() -> void:
	var f := _fac()
	for m in f.machines:
		if m.bot != null:
			m.bot.rates = {"jam": 0.0}
	for i in 3000:
		f.step()
		for m in f.machines:
			assert_true(m.state != Machine.State.JAMMED)
	assert_eq(f.fault_counts["JAMMED"], 0)


func test_overclock_heats_faster_and_fix_clears() -> void:
	var f := _fac()
	var g := _fac()
	for fac: Factory in [f, g]:
		for m in fac.machines:
			if m.bot != null:
				m.bot.rates = {}
	var a := f.get_machine("generator")
	a.overclocked = true
	for i in 200:
		f.step()
		g.step()
	var plain := g.get_machine("generator").heat
	assert_true(a.heat > plain * 2.0, "oc=%f plain=%f" % [a.heat, plain])
	a.heat = 80.0
	assert_eq(f.request_action("generator"), Factory.ActionResult.STARTED_FIX)
	for i in 12:
		f.step()
	assert_true(not a.overclocked)
	assert_true(a.heat < 40.0, "heat %f" % a.heat)


func test_overclock_event_recorded() -> void:
	var f := _fac()
	var s := f.get_machine("generator")
	s.bot.rates = {"overclock": 6000.0}
	for i in 5:
		f.step()
	assert_true(s.overclocked)
	assert_true(f.mistake_counts["overclock"] >= 1)
	var seen := false
	for e in f.mistake_log:
		seen = seen or (e["machine_id"] == "generator" and e["bot"] == s.bot.name)
	assert_true(seen)


func test_training_level_reduces_rate() -> void:
	var b := Bot.from_dict({"name": "T", "rates": {"jam": 6.0}}, 0.6)
	var r0 := b.rate_per_tick("jam", 10, 1.0, 1.0)
	assert_true(absf(r0 - 6.0 / 60.0 / 10.0) < 1e-9)
	b.levels["jam"] = 1
	assert_true(absf(b.rate_per_tick("jam", 10, 1.0, 1.0) - r0 * 0.6) < 1e-9)
	assert_true(absf(b.rate_per_tick("jam", 10, 2.0, 1.5) - r0 * 0.6 * 3.0) < 1e-9)


func test_tap_priority() -> void:
	var f := _fac()
	for m in f.machines:
		if m.bot != null:
			m.bot.rates = {}
	f.step()
	var m := f.get_machine("proc_a")
	m.state = Machine.State.WORKING
	m.heat = 90.0
	m.overclocked = true
	m.state = Machine.State.JAMMED
	assert_eq(f.request_action("proc_a"), Factory.ActionResult.STARTED_REPAIR)
	f.crew_busy = false
	m.state = Machine.State.WORKING
	assert_eq(f.request_action("proc_a"), Factory.ActionResult.STARTED_FIX)
	f.crew_busy = false
	m.overclocked = false
	assert_eq(f.request_action("proc_a"), Factory.ActionResult.STARTED_VENT)
