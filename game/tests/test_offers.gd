extends TestCase
## Radio, supervise and auto-inspector offers.


func _cfg(mods: Dictionary = {}) -> SimConfig:
	var bal := SimConfig._read(SimConfig.BALANCE_PATH)
	bal.merge(mods, true)
	return SimConfig.from_dicts(SimConfig._read(SimConfig.MACHINES_PATH), bal)


func _calm(f: Factory) -> void:
	for m in f.machines:
		if m.bot != null:
			m.bot.rates = {}
			m.bot.sloppy = 0.0


func test_radio_clears_jam_then_cooldown() -> void:
	var f := Factory.new(_cfg(), 1)
	_calm(f)
	f.apply_perks({"radio": true})
	f.get_machine("proc_a").state = Machine.State.JAMMED
	f.get_machine("proc_b").state = Machine.State.JAMMED
	assert_eq(f.radio_fix("proc_a"), Factory.RadioResult.FIXED)
	assert_eq(f.get_machine("proc_a").state, Machine.State.IDLE)
	assert_eq(f.radio_fix("proc_b"), Factory.RadioResult.COOLDOWN)
	for i in 130:
		f.step()
	assert_eq(f.radio_fix("proc_b"), Factory.RadioResult.FIXED)


func test_radio_refusals() -> void:
	var f := Factory.new(_cfg(), 1)
	_calm(f)
	f.get_machine("proc_a").state = Machine.State.JAMMED
	assert_eq(f.radio_fix("proc_a"), Factory.RadioResult.NO_RADIO)
	f.apply_perks({"radio": true})
	f.get_machine("proc_b").state = Machine.State.OVERHEATED
	assert_eq(f.radio_fix("proc_b"), Factory.RadioResult.NOT_ALLOWED)
	f.worker.place(Worker.Location.FLOOR)
	assert_eq(f.radio_fix("proc_a"), Factory.RadioResult.NOT_IN_OFFICE)


func test_radio_replay_matches() -> void:
	var cfg := _cfg({"ramp_start": 1.0, "ramp_end": 1.0, "mistake_rate_mult": 20.0})
	var f := Factory.new(cfg, 3)
	f.apply_perks({"radio": true})
	for i in 600:
		for m in f.machines:
			if m.state == Machine.State.JAMMED and f.radio_ready():
				f.radio_fix(m.id)
		f.step()
	assert_true(f.radio_fixes > 0, "run used the radio")
	var g := Factory.replay(cfg, 3, f.actions, 600, {"radio": true})
	assert_eq(g.shipped, f.shipped)
	assert_eq(g.radio_fixes, f.radio_fixes)


func test_supervise_cuts_rate_only_when_near() -> void:
	var cfg := _cfg({"supervise_mult": 0.0, "ramp_start": 1.0, "ramp_end": 1.0})
	var f := Factory.new(cfg, 1)
	var m := f.get_machine("proc_a")
	f.apply_perks({"supervise": m.bot.name})
	m.bot.rates = {"jam": 6000.0}
	m.heat = 0.0
	f.worker.place(Worker.Location.FLOOR)
	f.worker.floor_pos = m.pos
	for i in 200:
		f.step()
		m.state = Machine.State.WORKING if m.state == Machine.State.JAMMED else m.state
	assert_eq(f.mistake_counts["jam"], 0)
	f.worker.place(Worker.Location.OFFICE)
	for i in 200:
		f.step()
	assert_true(f.mistake_counts["jam"] > 0, "unsupervised bot jams")


func test_auto_inspector_works_only_away() -> void:
	var f := Factory.new(_cfg({"auto_inspect_error": 0.0}), 1)
	_calm(f)
	f.apply_perks({"auto_inspect": true})
	f._qa_items.append({"defect": "", "decoy": ""})
	f._qa_items.append({"defect": "crack", "decoy": ""})
	for i in 100:
		f.step()
	assert_eq(f.auto_inspected, 0)  # worker at desk
	f.worker.place(Worker.Location.FLOOR)
	for i in 100:
		f.step()
	assert_true(f.auto_inspected >= 2, "inspected while away")
	assert_true(f.caught >= 1, "caught the crack")
	assert_eq(f.complaints, 0)


func test_auto_inspector_errs() -> void:
	var f := Factory.new(_cfg({"auto_inspect_error": 1.0}), 1)
	_calm(f)
	f.apply_perks({"auto_inspect": true})
	f._qa_items.append({"defect": "crack", "decoy": ""})
	f.worker.place(Worker.Location.FLOOR)
	for i in 100:
		f.step()
	assert_eq(f.complaints, 1)


func test_offers_apply_perks() -> void:
	var c := Career.new(_cfg(), 1)
	c.points = 3
	c.apply({"kind": "radio"})
	c.apply({"kind": "auto_inspect"})
	c.apply({"kind": "supervise", "bot": c.roster[0].name})
	var f := c.start_day()
	assert_true(f.radio_enabled and f.auto_inspect)
	assert_eq(f.supervise_bot, c.roster[0].name)
	for d in 6:
		for o in c.offers():
			assert_true(o["kind"] != "radio" and o["kind"] != "auto_inspect", "owned offers not repeated")
		c.next_day()
