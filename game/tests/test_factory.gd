extends TestCase


func _factory(seed: int = 1) -> Factory:
	return Factory.new(SimConfig.load_default(), seed)


func test_config_valid() -> void:
	var c := SimConfig.load_default()
	assert_true(c.is_valid(), str(c.errors))
	assert_eq(c.machines.size(), 6)


func test_config_bad_data() -> void:
	var c := SimConfig.from_dicts({"machines": [{"id": "x", "type": "bogus"}], "links": [{"from": "x", "to": "y"}]}, {"tick_rate": 0})
	assert_true(not c.is_valid())
	assert_true(c.errors.size() >= 3, str(c.errors))


func test_flow_reaches_warehouse() -> void:
	var f := _factory()
	for i in 600:
		if not f.qa_queue().is_empty():
			f.inspect(String(f.qa_queue()[0]["defect"]) == "")
		f.step()
	assert_true(f.shipped > 0, "shipped=%d" % f.shipped)


func test_starved_without_input() -> void:
	var f := _factory()
	f.step()
	assert_eq(f.get_machine("warehouse").state, Machine.State.STARVED)
	assert_eq(f.get_machine("generator").state, Machine.State.WORKING)


func test_blocked_when_downstream_full() -> void:
	var f := _factory()
	# Fill the QA desk (nothing consumes without the worker).
	var w := f.get_machine("qa_desk")
	var a := f.get_machine("assembler")
	w.input_count = w.input_cap
	a.output_count = a.output_cap
	a.input_count = 1
	for i in 5:
		f.step()
	assert_eq(a.state, Machine.State.BLOCKED)


func test_deterministic() -> void:
	var a := _factory(7)
	var b := _factory(7)
	for i in 800:
		a.step()
		b.step()
	assert_eq(a.shipped, b.shipped)
	assert_eq(a.items_in_transit(), b.items_in_transit())
	for i in a.machines.size():
		assert_eq(a.machines[i].state, b.machines[i].state)
		assert_eq(a.machines[i].input_count, b.machines[i].input_count)
		assert_eq(a.machines[i].progress, b.machines[i].progress)
	assert_eq(a.rng.randi(), b.rng.randi())
