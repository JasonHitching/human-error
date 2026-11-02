extends TestCase
## Factory tiers (#88): layouts as data, tier 2, unlocking and the picker.


func _reachable(c: SimConfig) -> Dictionary:
	var seen := {}
	var todo: Array[String] = []
	for md in c.machines:
		if md["type"] == "generator":
			todo.append(String(md["id"]))
	while not todo.is_empty():
		var id: String = todo.pop_back()
		if seen.has(id):
			continue
		seen[id] = true
		for l in c.links:
			if l["from"] == id:
				todo.append(String(l["to"]))
	return seen


func test_layouts_validate() -> void:
	for t in range(1, SimConfig.MAX_TIER + 1):
		var c := SimConfig.load_tier(t)
		assert_true(c.is_valid(), "tier %d: %s" % [t, str(c.errors)])
		var reach := _reachable(c)
		for md in c.machines:
			assert_true(reach.has(md["id"]), "tier %d: %s not reachable from the generator" % [t, md["id"]])
		var has_wh := false
		for md in c.machines:
			has_wh = has_wh or md["type"] == "warehouse"
		assert_true(has_wh)


func test_tier_two_shape() -> void:
	var c1 := SimConfig.load_tier(1)
	var c2 := SimConfig.load_tier(2)
	assert_true(c2.machines.size() >= 6 and c2.machines.size() > c1.machines.size())
	var asm := 0
	var proc := 0
	for md in c2.machines:
		asm += 1 if md["type"] == "assembler" else 0
		proc += 1 if md["type"] == "processor" else 0
	assert_true(asm >= 2 and proc >= 3)
	assert_true(c2.target_base > c1.target_base)
	assert_true(c2.bot_defs.size() > c1.bot_defs.size())
	assert_eq(SimConfig.load_tier(99).machines.size(), c2.machines.size())  # clamped
	assert_eq(SimConfig.load_tier(-3).machines.size(), c1.machines.size())


func test_tier_two_runs_50_shifts() -> void:
	var c := SimConfig.load_tier(2)
	for s in 50:
		var f := Factory.new(c, s + 1)
		for _t in 600:
			f.step()
		assert_true(f.get_machine("assembler_b") != null)


func test_automation_unlocks_tier_two() -> void:
	var m := Meta.new()
	assert_eq(m.tier, 1)
	m.unlock_after(1)
	assert_eq(m.tier, 2)
	m.unlock_after(2)
	assert_eq(m.tier, SimConfig.MAX_TIER)
	m.pick_tier(5)
	assert_eq(m.picked_tier, 2)
	m.pick_tier(1)
	assert_eq(m.picked_tier, 1)


func test_tier_best_is_per_tier() -> void:
	var m := Meta.new()
	assert_true(m.note_best(1, 5))
	assert_true(not m.note_best(1, 4))
	assert_true(m.note_best(2, 2))
	assert_eq(m.best_for(1), 5)
	assert_eq(m.best_for(2), 2)


func test_picker_round_trip_through_save() -> void:
	var p := "user://t_tier_save.json"
	var m := Meta.new()
	m.unlock_after(1)
	m.pick_tier(2)
	m.note_best(2, 7)
	assert_true(SaveIO.write_meta(m, p))
	var r := SaveIO.load_meta(p, p + ".bad", p + ".legacy")
	assert_eq(r.tier, 2)
	assert_eq(r.picked_tier, 2)
	assert_eq(r.best_for(2), 7)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	var bad := Meta.from_dict({"version": 1, "tier": 9, "picked_tier": 7, "tier_best": {"x": 3, "2": -4}})
	assert_eq(bad.tier, SimConfig.MAX_TIER)
	assert_true(bad.picked_tier <= bad.tier)
	assert_eq(bad.best_for(2), 0)
