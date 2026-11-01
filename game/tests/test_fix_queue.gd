extends TestCase
## Fix queue of 3, worst-first and self-clearing jams.


func _cfg(mods: Dictionary = {}) -> SimConfig:
	var bal := SimConfig._read(SimConfig.BALANCE_PATH)
	bal.merge(mods, true)
	return SimConfig.from_dicts(SimConfig._read(SimConfig.MACHINES_PATH), bal)


func _floor(cfg: SimConfig) -> Factory:
	var f := Factory.new(cfg, 1)
	for m in f.machines:
		if m.bot != null:
			m.bot.rates = {}
			m.bot.sloppy = 0.0
	f.worker.place(Worker.Location.FLOOR)
	f.step()
	return f


func _jam(f: Factory, id: String) -> Machine:
	var m := f.get_machine(id)
	m.state = Machine.State.JAMMED
	return m


func test_queue_holds_three_in_order() -> void:
	var f := _floor(_cfg())
	var ids: Array[String] = ["proc_a", "proc_b", "assembler", "generator"]
	for id in ids:
		f.get_machine(id).misrouted = true
	f.request_action("proc_a")
	assert_eq(f.request_action("proc_b"), Factory.ActionResult.QUEUED)
	assert_eq(f.request_action("assembler"), Factory.ActionResult.QUEUED)
	assert_eq(f.request_action("generator"), Factory.ActionResult.QUEUED)
	assert_eq(f.crew_queue.size(), 3)
	var order: Array[String] = []
	for i in 600:
		f.step()
		if f.crew_busy and (order.is_empty() or order[-1] != f.crew_target):
			order.append(f.crew_target)
	assert_eq(order, ids, "runs in tap order")
	assert_true(f.crew_queue.is_empty())


func test_queue_limit_refuses_extra() -> void:
	var f := _floor(_cfg({"fix_queue_max": 2}))
	for id in ["proc_a", "proc_b", "assembler", "generator"]:
		f.get_machine(id).misrouted = true
	f.request_action("proc_a")
	f.request_action("proc_b")
	f.request_action("assembler")
	assert_eq(f.request_action("generator"), Factory.ActionResult.CREW_BUSY)
	assert_eq(f.crew_queue.size(), 2)


func test_cancel_in_the_middle() -> void:
	var f := _floor(_cfg())
	for id in ["proc_a", "proc_b", "assembler"]:
		f.get_machine(id).misrouted = true
	f.request_action("proc_a")
	f.request_action("proc_b")
	f.request_action("assembler")
	assert_eq(f.request_action("proc_b"), Factory.ActionResult.UNQUEUED)
	assert_eq(f.crew_queue, ["assembler"] as Array[String])


func test_worst_first_order() -> void:
	var f := _floor(_cfg({"fix_queue_max": 5}))
	f.get_machine("proc_a").misrouted = true
	f.get_machine("proc_b").state = Machine.State.CLOGGED
	f.get_machine("proc_b").junk_count = 1
	f.get_machine("assembler").state = Machine.State.JAMMED
	f.get_machine("generator").state = Machine.State.OVERHEATED
	var picked: Array[String] = []
	for i in 4:
		f.request_worst()
		picked.append(f.crew_target if i == 0 else f.crew_queue[-1])
	assert_eq(picked, ["generator", "assembler", "proc_b", "proc_a"] as Array[String])
	assert_eq(f.request_worst(), Factory.ActionResult.NOTHING_TO_DO, "nothing left to queue")


func test_worst_first_misrouted_before_hot() -> void:
	var f := _floor(_cfg())
	f.get_machine("proc_a").state = Machine.State.WORKING
	f.get_machine("proc_a").heat = 80.0
	f.get_machine("proc_b").overclocked = true
	f.request_worst()
	assert_eq(f.crew_target, "proc_b")
	f.request_worst()
	assert_eq(f.crew_queue, ["proc_a"] as Array[String])


func test_worst_first_ties_nearest() -> void:
	var f := _floor(_cfg())
	var js: Array[Machine] = []
	for m in f.machines:
		if m.bot != null and m.type != "qa":
			js.append(_jam(f, m.id))
	var near: Machine = js[0]
	for m in js:
		if f.worker.floor_pos.distance_to(m.pos) < f.worker.floor_pos.distance_to(near.pos):
			near = m
	f.request_worst()
	assert_eq(f.crew_target, near.id)


func test_jam_self_clears_after_delay_only() -> void:
	var f := _floor(_cfg({"jam_self_clear_seconds": 5}))
	var m := _jam(f, "proc_a")
	for i in 49:
		f.step()
	assert_eq(m.state, Machine.State.JAMMED, "not before the delay")
	var saw := false
	for i in 3:
		f.step()
		for e in f.events:
			if e["type"] == "self_clear" and e["machine_id"] == "proc_a":
				saw = true
	assert_true(saw, "event emitted")
	assert_true(m.state != Machine.State.JAMMED)


func test_overheat_never_self_clears() -> void:
	var f := _floor(_cfg({"jam_self_clear_seconds": 2}))
	var m := f.get_machine("proc_a")
	m.state = Machine.State.OVERHEATED
	for i in 400:
		f.step()
	assert_eq(m.state, Machine.State.OVERHEATED)


func test_crew_job_cancels_jam_timer() -> void:
	var f := _floor(_cfg({"jam_self_clear_seconds": 2, "repair_seconds": 3.0}))
	var m := _jam(f, "proc_a")
	assert_eq(f.request_action("proc_a"), Factory.ActionResult.STARTED_REPAIR)
	for i in 25:
		f.step()
		assert_true(m.state == Machine.State.JAMMED, "repair still running, no self-clear")
	for i in 20:
		f.step()
	assert_true(m.state != Machine.State.JAMMED)
	for e in f.events:
		assert_true(e["type"] != "self_clear")


func test_replay_with_queue_adds_cancels_and_worst() -> void:
	var cfg := _cfg()
	var a := Factory.new(cfg, 9)
	a.go_to_floor()
	for i in 40:
		a.step()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var ids: Array[String] = []
	for m in a.machines:
		if m.bot != null and m.type != "qa":
			ids.append(m.id)
	for i in 1460:
		if i % 25 == 0:
			var r := rng.randi() % 3
			if r == 0:
				a.request_worst()
			else:
				a.request_action(ids[rng.randi() % ids.size()])
		a.step()
	var b := Factory.replay(cfg, 9, a.actions, 1500)
	assert_eq(a.shipped, b.shipped)
	assert_eq(a.fault_counts, b.fault_counts)
	assert_eq(a.crew_queue, b.crew_queue)
	assert_eq(a.worker.floor_pos, b.worker.floor_pos)
