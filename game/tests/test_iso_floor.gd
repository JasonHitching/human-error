extends TestCase
## Iso layout data: every machine has a cell, belts join linked machines, belt tiles are valid.


func _floor(tier: int) -> IsoFloor:
	var c := SimConfig.load_tier(tier)
	var iso := IsoFloor.new()
	iso.setup(c.machines, c.links, c.floor_art)
	return iso


func test_every_machine_has_a_distinct_cell_both_tiers() -> void:
	for tier in [1, 2]:
		var c := SimConfig.load_tier(tier)
		var iso := _floor(tier)
		assert_eq(iso.cells.size(), c.machines.size(), "tier %d cells" % tier)
		assert_eq(iso.by_cell.size(), c.machines.size(), "tier %d distinct cells" % tier)


func test_paths_join_linked_machines_with_adjacent_cells() -> void:
	for tier in [1, 2]:
		var iso := _floor(tier)
		for key: String in iso.paths:
			var p: Array = iso.paths[key]
			var ids := key.split(">")
			assert_eq(p[0], iso.cells[ids[0]], key + " start")
			assert_eq(p[p.size() - 1], iso.cells[ids[1]], key + " end")
			for i in range(1, p.size()):
				assert_eq(absi(p[i].x - p[i - 1].x) + absi(p[i].y - p[i - 1].y), 1, key + " step")


func test_belt_cells_are_free_and_have_a_sprite() -> void:
	for tier in [1, 2]:
		var iso := _floor(tier)
		for c: Vector2i in iso.edges:
			assert_true(not iso.by_cell.has(c), "belt on a machine cell %s" % c)
			assert_true(String(iso.belt_sprite(c)["name"]).begins_with("belt_"), "belt sprite %s" % c)


func test_tier_one_is_a_diamond() -> void:
	var iso := _floor(1)
	var g := IsoFloor.to_local(Vector2(iso.cells["generator"]))
	var a := IsoFloor.to_local(Vector2(iso.cells["proc_a"]))
	var b := IsoFloor.to_local(Vector2(iso.cells["proc_b"]))
	var s := IsoFloor.to_local(Vector2(iso.cells["assembler"]))
	assert_true(a.x < g.x and b.x > g.x and absf(a.y - b.y) < 0.01, "presses left and right of the generator")
	assert_true(s.y > a.y and s.y > g.y, "assembler below the presses")
