extends TestCase


func _fac(seed: int = 1) -> Factory:
	var f := Factory.new(SimConfig.load_default(), seed)
	for m in f.machines:
		if m.bot != null:
			m.bot.rates = {}  # no random mistakes
	f.worker.place(Worker.Location.FLOOR)  # crew jobs need the worker on the floor
	return f


func _run(f: Factory, ticks: int) -> void:
	for i in ticks:
		f.step()


func test_misroute_scraps_output() -> void:
	var f := _fac()
	f.get_machine("assembler").misrouted = true
	_run(f, 1200)
	assert_eq(f.shipped, 0)
	assert_true(f.scrapped > 0, "scrapped")
	var saw_scrap := false
	var g := _fac()
	g.get_machine("assembler").misrouted = true
	for i in 1200:
		g.step()
		for it in g.items_in_transit():
			saw_scrap = saw_scrap or it["to"] == "scrap"
	assert_true(saw_scrap, "scrap items visible in transit")


func test_wrong_recipe_clogs_next_and_clear_restores() -> void:
	var f := _fac()
	f.get_machine("proc_a").wrong_recipe = true
	f.get_machine("proc_b").wrong_recipe = true
	_run(f, 400)
	var asm := f.get_machine("assembler")
	assert_eq(asm.state, Machine.State.CLOGGED)
	assert_true(asm.junk_count > 0)
	var walk := f.worker.walk_ticks_to(asm.pos)  # the job starts once the worker arrives
	assert_eq(f.request_action("assembler"), Factory.ActionResult.STARTED_CLEAR)
	_run(f, walk + 20)
	assert_eq(asm.junk_count, 0)
	# fix the sources, then flow resumes
	f.get_machine("proc_a").wrong_recipe = false
	f.get_machine("proc_b").wrong_recipe = false
	for i in 600:
		if asm.state == Machine.State.CLOGGED and not f.crew_busy:
			if f.worker_location() == Worker.Location.FLOOR:
				f.request_action("assembler")
			else:
				f.go_to_floor()
		elif not f.qa_queue().is_empty():
			if f.worker_at_desk():
				f.inspect(String(f.qa_queue()[0]["defect"]) == "")
			else:
				f.go_to_office()
		f.step()
	assert_true(f.shipped > 0, "flow restored")


func test_fix_stops_junk() -> void:
	var f := _fac()
	var a := f.get_machine("proc_a")
	a.wrong_recipe = true
	a.overclocked = true
	a.misrouted = true
	var walk := f.worker.walk_ticks_to(a.pos)  # the job starts once the worker arrives
	assert_eq(f.request_action("proc_a"), Factory.ActionResult.STARTED_FIX)
	_run(f, walk + 15)
	assert_true(not a.wrong_recipe and not a.misrouted and not a.overclocked, "one fix clears all")


func test_qa_desk_clogs_on_junk() -> void:
	var f := _fac()
	f.get_machine("assembler").wrong_recipe = true
	_run(f, 800)
	assert_eq(f.get_machine("qa_desk").state, Machine.State.CLOGGED)
	assert_eq(f.shipped, 0)


func test_tap_priority() -> void:
	var f := _fac()
	var m := f.get_machine("proc_a")
	m.state = Machine.State.CLOGGED
	m.junk_count = 1
	m.input_count = 1
	m.misrouted = true
	assert_eq(f.request_action("proc_a"), Factory.ActionResult.STARTED_CLEAR)
	var f2 := _fac()
	var m2 := f2.get_machine("proc_a")
	m2.state = Machine.State.JAMMED
	m2.junk_count = 1
	assert_eq(f2.request_action("proc_a"), Factory.ActionResult.STARTED_REPAIR)
	var f3 := _fac()
	var m3 := f3.get_machine("proc_a")
	m3.state = Machine.State.WORKING
	m3.heat = 90.0
	m3.wrong_recipe = true
	assert_eq(f3.request_action("proc_a"), Factory.ActionResult.STARTED_FIX)


func test_deterministic_with_new_mistakes() -> void:
	var cfg := SimConfig.load_default()
	var res: Array = []
	for k in 2:
		var f := Factory.new(cfg, 5)
		for m in f.machines:
			if m.bot != null:
				m.bot.rates = {"misroute": 20.0, "wrong_recipe": 20.0, "jam": 2.0, "overclock": 5.0}
		for i in 1500:
			if i % 37 == 0:
				for m in f.machines:
					if m.state == Machine.State.CLOGGED or m.misrouted or m.wrong_recipe:
						f.request_action(m.id)
						break
			f.step()
		res.append([f.shipped, f.scrapped, f.clog_count, f.mistake_counts.duplicate()])
	assert_eq(res[0], res[1])
	assert_true(res[0][1] + res[0][2] > 0, "new mistakes happened")
