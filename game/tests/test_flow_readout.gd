extends TestCase
## Flow readability: a forced-slow machine backs up its upstream belt and is named the bottleneck.


func _slow_run(ticks: int) -> Factory:
	var f := Factory.new(SimConfig.load_default(), 1)
	f.get_machine("assembler").process_ticks = 400
	for i in ticks:
		f.step()
	return f


func test_slow_machine_is_the_bottleneck_and_queues_upstream() -> void:
	var f := _slow_run(600)
	assert_eq(FlowReadout.bottleneck(f), "assembler", "bottleneck id")
	var q := 0
	for l in SimConfig.load_default().links:
		if l["to"] == "assembler":
			q += FlowReadout.queued_on(f, String(l["from"]), "assembler")
	assert_true(q > 0, "items queued on belts into the assembler: %d" % q)
	assert_eq(FlowReadout.role(f, f.get_machine("assembler")), FlowReadout.ROLE_BOTTLENECK)
	assert_true(FlowReadout.input_fill(f.get_machine("assembler")) >= FlowReadout.FULL_FILL, "input queue shows full")


func test_starved_and_blocked_neighbours_are_not_bottlenecks() -> void:
	var f := _slow_run(600)
	var warehouse := f.get_machine("warehouse")
	assert_true(FlowReadout.role(f, warehouse) != FlowReadout.ROLE_BOTTLENECK, "downstream is not the bottleneck")
	for m in f.machines:
		if m.state == Machine.State.STARVED:
			assert_eq(FlowReadout.role(f, m), FlowReadout.ROLE_STARVED, m.id)


func test_healthy_line_has_no_bottleneck_at_start() -> void:
	var f := Factory.new(SimConfig.load_default(), 1)
	assert_eq(FlowReadout.bottleneck(f), "", "nothing queued yet")


func test_view_exposes_bottleneck_and_belt_queue() -> void:
	var cfg := SimConfig.load_default()
	var f := Factory.new(cfg, 1)
	f.get_machine("assembler").process_ticks = 400
	for i in 600:
		f.step()
	var v := FactoryView.new()
	v.setup(f, cfg)
	assert_eq(v.bottleneck_id(), "assembler", "view bottleneck")
	var q := 0
	for l in cfg.links:
		if l["to"] == "assembler":
			q += v.belt_queue(String(l["from"]), "assembler")
	assert_true(q > 0, "view reports queued items")
	v.free()
