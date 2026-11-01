extends TestCase


func _fac(seed: int = 1, sloppy: float = 0.0) -> Factory:
	var f := Factory.new(SimConfig.load_default(), seed)
	for m in f.machines:
		if m.bot != null:
			m.bot.rates = {}  # no random machine mistakes
			m.bot.sloppy = sloppy
	return f


func _run(f: Factory, ticks: int) -> void:
	for i in ticks:
		f.step()


## Run until the QA queue has at least n products (or give up).
func _until_queue(f: Factory, n: int) -> void:
	for i in 3000:
		if f.qa_queue().size() >= n:
			return
		f.step()


func _put(f: Factory, defect: String) -> void:
	var qa := f.get_machine("qa_desk")
	f._qa_items.append({"defect": defect, "decoy": "", "bot": "Test"})
	qa.input_count += 1


func test_nothing_ships_without_inspection() -> void:
	var f := _fac()
	_run(f, 1500)
	assert_eq(f.shipped, 0)
	assert_true(f.qa_queue().size() > 0, "products wait at the desk")


func test_not_at_desk_while_crew_busy() -> void:
	var f := _fac()
	_put(f, "")
	f.get_machine("proc_a").overclocked = true
	assert_eq(f.request_action("proc_a"), Factory.ActionResult.STARTED_FIX)
	assert_eq(f.inspect(true), Factory.InspectResult.NOT_AT_DESK)
	assert_eq(f.qa_queue().size(), 1)


func test_empty_queue() -> void:
	assert_eq(_fac().inspect(true), Factory.InspectResult.EMPTY)


func test_full_queue_blocks_assembler() -> void:
	var f := _fac()
	_until_queue(f, f.qa_capacity)
	_run(f, 300)
	assert_eq(f.qa_queue().size(), f.qa_capacity)
	assert_eq(f.get_machine("assembler").state, Machine.State.BLOCKED)


func test_ship_good_arrives() -> void:
	var f := _fac()
	_put(f, "")
	assert_eq(f.inspect(true), Factory.InspectResult.SHIPPED)
	_run(f, 30)
	assert_eq(f.shipped, 1)
	assert_eq(f.complaints, 0)


func test_ship_defective_is_complaint_and_penalty() -> void:
	var f := _fac()
	f.shipped = 10
	_put(f, "crack")
	assert_eq(f.inspect(true), Factory.InspectResult.COMPLAINT)
	assert_eq(f.complaints, 1)
	assert_eq(f.score(), 7)
	_run(f, 30)
	assert_eq(f.shipped, 11)
	assert_eq(f.score(), 8)
	f.complaints = 100
	assert_eq(f.score(), 0, "score never below 0")


func test_reject_defective_caught_and_streak() -> void:
	var f := _fac()
	_put(f, "dent")
	_put(f, "crack")
	assert_eq(f.inspect(false), Factory.InspectResult.CAUGHT)
	_run(f, 10)
	assert_eq(f.inspect(false), Factory.InspectResult.CAUGHT)
	assert_eq(f.caught, 2)
	assert_eq(f.streak, 2)
	assert_eq(f.shipped, 0)


func test_reject_good_is_wasted_and_resets_streak() -> void:
	var f := _fac()
	f.streak = 3
	_put(f, "")
	assert_eq(f.inspect(false), Factory.InspectResult.WASTED)
	assert_eq(f.wasted, 1)
	assert_eq(f.streak, 0)


func test_complaint_resets_streak() -> void:
	var f := _fac()
	f.streak = 3
	_put(f, "dent")
	f.inspect(true)
	assert_eq(f.streak, 0)


func test_inspect_cooldown_is_busy() -> void:
	var f := _fac()
	_put(f, "")
	_put(f, "")
	assert_eq(f.inspect(true), Factory.InspectResult.SHIPPED)
	assert_eq(f.inspect(true), Factory.InspectResult.BUSY)
	_run(f, 5)  # inspect_seconds 0.5 at 10 ticks/s
	assert_eq(f.inspect(true), Factory.InspectResult.SHIPPED)


func test_training_lowers_defect_rate() -> void:
	var rates: Array[float] = []
	for level in [0, 3]:
		var made := 0
		var defects := 0
		for seed in 6:
			var f := _fac(seed + 1, 0.3)
			f.get_machine("assembler").bot.levels["sloppy"] = level
			f.get_machine("proc_a").bot.levels["sloppy"] = level
			f.get_machine("proc_b").bot.levels["sloppy"] = level
			for i in 1500:
				if not f.qa_queue().is_empty():
					f.inspect(false)
				f.step()
			made += f.caught + f.wasted + f.qa_queue().size()
			defects += f.mistake_counts["sloppy"]
		rates.append(float(defects) / float(maxi(1, made)))
	assert_true(rates[0] > 0.02, "defects happen: " + str(rates))
	assert_true(rates[1] < rates[0] * 0.6, "training lowers: " + str(rates))


func test_defect_emits_mistake_event_and_data() -> void:
	var f := _fac(3, 1.0)
	var saw := false
	for i in 2500:
		f.step()
		for e in f.events:
			if e["type"] == "mistake" and e["mistake"] == "sloppy":
				saw = true
	assert_true(saw, "sloppy event")
	var q := f.qa_queue()
	assert_true(q.size() > 0)
	for p: Dictionary in q:
		assert_true(p.has("defect") and p.has("decoy") and p.has("bot"))
		assert_true(Factory.DEFECTS.has(p["defect"]) or p["defect"] == "")


func test_idle_counts_only_when_nothing_to_do() -> void:
	var f := _fac()
	_run(f, 5)
	assert_true(f.idle_ticks > 0, "empty factory start is idle")
	var g := _fac()
	_put(g, "")
	_run(g, 3)
	assert_eq(g.idle_ticks, 0, "queue not empty")


func test_deterministic_with_inspects() -> void:
	var cfg := SimConfig.load_default()
	var a := Factory.new(cfg, 9)
	var rng := Autoplayers.make_rng(9)
	for i in 1500:
		Autoplayers.act("greedy", a, rng)
		a.step()
	var b := Factory.replay(cfg, 9, a.actions, 1500)
	assert_true(a.caught + a.wasted + a.complaints + a.shipped > 0, "something was inspected")
	assert_eq(a.shipped, b.shipped)
	assert_eq(a.complaints, b.complaints)
	assert_eq(a.caught, b.caught)
	assert_eq(a.wasted, b.wasted)
	assert_eq(a.idle_ticks, b.idle_ticks)
	assert_eq(a.qa_queue(), b.qa_queue())


func test_career_offers_and_score() -> void:
	var c := Career.new(SimConfig.load_default(), 1)
	c.points = 5
	c.apply({"kind": "qa_capacity"})
	c.apply({"kind": "inspect_speed"})
	assert_eq(c.start_day().qa_capacity, 10)
	assert_near(c.start_day().inspect_speed, 0.8)
	var texts := ""
	for k in 40:
		c.history.append({})
		for o in c.offers():
			texts += o["text"] + "|"
	assert_true(texts.contains("Bigger desk: +2 queue") and texts.contains("Quick eye: inspect −20%") and texts.contains("sloppy −40%"), texts)
	var f := c.start_day()
	f.shipped = f.target
	f.complaints = 1
	assert_true(not c.end_day(f)["hit"], "complaint penalty can cause a miss")


func test_careful_stays_at_desk() -> void:
	var f := _fac()
	for i in 4:
		_put(f, "")
	f.get_machine("proc_a").overclocked = true
	Autoplayers.act("careful", f, Autoplayers.make_rng(1))
	assert_true(not f.crew_busy, "careful keeps inspecting with a long queue")
	var g := _fac()
	g.get_machine("proc_a").overclocked = true
	Autoplayers.act("careful", g, Autoplayers.make_rng(1))
	assert_true(g.crew_busy, "careful fixes when the queue is short")
