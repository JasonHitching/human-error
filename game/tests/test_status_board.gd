extends TestCase


func _board() -> Array:
	var f := Factory.new(SimConfig.load_default(), 1)
	return [f, StatusBoard.new(f.machines, 60.0)]


func test_lights() -> void:
	var r := _board()
	var f: Factory = r[0]
	var b: StatusBoard = r[1]
	var m := f.get_machine("proc_a")
	m.state = Machine.State.IDLE
	m.heat = 0.0
	assert_eq(b.machine_light(m), StatusBoard.Light.GREEN)
	m.heat = 60.0
	assert_eq(b.machine_light(m), StatusBoard.Light.AMBER)
	m.heat = 10.0
	m.overclocked = true
	assert_eq(b.machine_light(m), StatusBoard.Light.AMBER)
	m.overclocked = false
	m.state = Machine.State.BLOCKED
	assert_eq(b.machine_light(m), StatusBoard.Light.AMBER)
	for s: Machine.State in [Machine.State.JAMMED, Machine.State.OVERHEATED, Machine.State.CLOGGED]:
		m.state = s
		assert_eq(b.machine_light(m), StatusBoard.Light.RED)
	m.state = Machine.State.IDLE
	m.misrouted = true
	assert_eq(b.machine_light(m), StatusBoard.Light.RED)
	m.misrouted = false
	m.wrong_recipe = true
	assert_eq(b.machine_light(m), StatusBoard.Light.RED)


func test_monitored_excludes_desk_and_warehouse() -> void:
	var r := _board()
	var b: StatusBoard = r[1]
	for m in b.monitored():
		assert_true(m.type != "qa" and m.type != "warehouse")
	assert_eq(b.monitored().size(), 4)


func test_alarms_once_per_red_spell() -> void:
	var r := _board()
	var f: Factory = r[0]
	var b: StatusBoard = r[1]
	assert_eq(b.new_alarms().size(), 0)
	var m := f.get_machine("proc_b")
	m.state = Machine.State.JAMMED
	var a := b.new_alarms()
	assert_eq(a.size(), 1)
	assert_eq(a[0].id, "proc_b")
	assert_eq(b.new_alarms().size(), 0)
	m.state = Machine.State.IDLE
	assert_eq(b.new_alarms().size(), 0)
	m.state = Machine.State.OVERHEATED
	assert_eq(b.new_alarms().size(), 1)


func test_bots_have_call_ins() -> void:
	var f: Factory = _board()[0]
	for m in f.machines:
		if m.bot != null:
			assert_true(m.bot.call_in.size() >= 3, "%s needs 3+ call_in lines" % m.bot.name)
