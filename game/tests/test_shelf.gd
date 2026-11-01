extends TestCase


func _fac() -> Factory:
	return Factory.new(SimConfig.load_default(), 3, [], 1.0)


func _item(tag: String) -> Dictionary:
	return {"defect": "", "decoy": "", "bot": tag}


func test_shelf_absorbs_overflow_without_blocking() -> void:
	var f := _fac()
	assert_true(f.shelf_slots > 0)
	var asm := f.get_machine("assembler")
	for _i in 4000:
		f.step()
		if f.qa_queue().size() >= f.qa_capacity and f.qa_shelf().size() >= 1:
			break
	assert_eq(f.qa_queue().size(), f.qa_capacity)
	assert_true(f.qa_shelf().size() >= 1, "overflow went to the shelf")
	for _i in 4000:
		f.step()
	assert_eq(f.qa_queue().size(), f.qa_capacity)
	assert_eq(f.qa_shelf().size(), f.shelf_slots)
	assert_eq(f.get_machine("assembler").state, Machine.State.BLOCKED, "blocks only when queue and shelf are full")


func test_shelf_feeds_queue_fifo() -> void:
	var f := _fac()
	f.qa_capacity = 2
	f.shelf_slots = 2
	for t in ["a", "b", "c", "d"]:
		f._qa_items.append(_item(t))
	assert_eq(f.qa_queue().size(), 2)
	assert_eq(f.qa_shelf().size(), 2)
	f.worker.place(Worker.Location.OFFICE)
	f.inspect(true)
	assert_eq(f.qa_queue()[0]["bot"], "b")
	assert_eq(f.qa_queue()[1]["bot"], "c", "shelf feeds the queue in order")
	assert_eq(f.qa_shelf()[0]["bot"], "d")


func test_probation_day_gives_no_strike() -> void:
	var c := Career.new(SimConfig.load_default(), 1)
	var f := c.start_day()
	f.shipped = 0
	var r := c.end_day(f)
	assert_true(r["probation"])
	assert_eq(c.strikes, 0)
	c.next_day()
	var f2 := c.start_day()
	f2.shipped = 0
	var r2 := c.end_day(f2)
	assert_true(not r2["probation"])
	assert_eq(c.strikes, 1)


func test_new_day_one_target() -> void:
	var cfg := SimConfig.load_default()
	assert_eq(cfg.target_base, 24)
	assert_eq(Career.new(cfg, 1).day_target(), 24)


func test_replay_with_shelf_is_exact() -> void:
	var cfg := SimConfig.load_default()
	var a := Factory.new(cfg, 5, [], 1.0)
	for _t in 2000:  # nobody inspects: queue and shelf both fill
		a.step()
	var b := Factory.replay(cfg, 5, a.actions, 2000)
	assert_eq(a.qa_queue(), b.qa_queue())
	assert_eq(a.qa_shelf(), b.qa_shelf())
	assert_true(a.qa_shelf().size() > 0)
