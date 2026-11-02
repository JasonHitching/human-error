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


func test_item_anchor_sits_on_belt_top_surface_centre() -> void:
	# The belt top face's left/right corners lie on the row where the sprite first touches its edge column.
	var anchor_y: float = IsoFloor.anchor("belt_").y
	var target_y: float = anchor_y + IsoFloor.belt_top_offset().y * 2.0  # baked px
	for n in ["belt_straight_a", "belt_straight_b", "belt_corner_ne_se", "belt_corner_nw_ne", "belt_corner_se_sw", "belt_corner_sw_nw", "belt_merge", "belt_split"]:
		var img := Sprites.tex(n).get_image()
		var best := 9999
		for x in [0, img.get_width() - 1]:
			for y in img.get_height():
				if img.get_pixel(x, y).a > 0.5:
					best = mini(best, y)
					break
			if best == 65:
				break
		assert_true(absf(float(best) - target_y) <= 4.0, "%s corner row %d vs item row %.1f" % [n, best, target_y])
		# Item (centred on the anchor) lies on opaque belt pixels, i.e. on the surface.
		assert_true(img.get_pixel(int(IsoFloor.anchor(n).x), int(target_y)).a > 0.5, n + " item over belt")
