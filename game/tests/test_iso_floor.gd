extends TestCase
## Iso layout data: every machine has a cell, belts join linked machines, belt tiles are valid.


func _floor(tier: int) -> IsoFloor:
	var c := SimConfig.load_mode("core") if tier == 0 else SimConfig.load_tier(tier)
	var iso := IsoFloor.new()
	iso.setup(c.machines, c.links, c.floor_art)
	return iso


func test_every_machine_has_a_distinct_cell_both_tiers() -> void:
	for tier in [0, 1, 2]:
		var c := SimConfig.load_mode("core") if tier == 0 else SimConfig.load_tier(tier)
		var iso := _floor(tier)
		assert_eq(iso.cells.size(), c.machines.size(), "tier %d cells" % tier)
		assert_eq(iso.by_cell.size(), c.machines.size(), "tier %d distinct cells" % tier)


func test_paths_join_linked_machines_with_adjacent_cells() -> void:
	for tier in [0, 1, 2]:
		var iso := _floor(tier)
		for key: String in iso.paths:
			var p: Array = iso.paths[key]
			var ids := key.split(">")
			assert_eq(p[0], iso.cells[ids[0]], key + " start")
			assert_eq(p[p.size() - 1], iso.cells[ids[1]], key + " end")
			for i in range(1, p.size()):
				assert_eq(absi(p[i].x - p[i - 1].x) + absi(p[i].y - p[i - 1].y), 1, key + " step")


func test_belt_cells_are_free_and_have_a_sprite() -> void:
	for tier in [0, 1, 2]:
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


func test_bots_and_worker_never_stand_on_belts_both_tiers() -> void:
	for tier in [0, 1, 2]:
		var iso := _floor(tier)
		var stands: Dictionary = {}
		for id: String in iso.cells:
			var sc := iso.stand_cell(id)
			assert_true(iso.is_free_floor(sc), "tier %d %s bot cell %s not free floor" % [tier, id, sc])
			assert_true(not stands.has(sc), "tier %d %s shares a bot cell" % [tier, id])
			stands[sc] = true
			var bot_p := IsoFloor.to_local(Vector2(sc))
			var stop_p := IsoFloor.to_local(Vector2(iso.cells[id])) + IsoFloor.WORKER_STOP
			for b: Vector2i in iso.edges:
				assert_true(not IsoFloor.in_cell(bot_p, b), "tier %d %s bot on belt %s" % [tier, id, b])
				assert_true(not IsoFloor.in_cell(stop_p, b), "tier %d %s worker stop on belt %s" % [tier, id, b])
		var stairs_p := IsoFloor.to_local(iso.stairs_cell)
		for b: Vector2i in iso.edges:
			assert_true(not IsoFloor.in_cell(stairs_p, b), "tier %d stairs on belt %s" % [tier, b])


func test_machines_face_their_belts_both_tiers() -> void:
	for tier in [0, 1, 2]:
		var iso := _floor(tier)
		for msg in iso.facing_mismatches():
			failures.append("tier %d: %s" % [tier, msg])
		for id: String in iso.cells:
			if iso.types[id] == "qa":
				continue
			var path := "res://assets/sprites/%s.png" % iso.machine_sprite(id, iso.types[id])
			assert_true(FileAccess.file_exists(path), "tier %d %s: missing facing sprite %s" % [tier, id, path])


func test_core_factory_opens_whole_and_big_factories_open_close_up() -> void:
	var cam := FloorCamera.new()
	cam.set_view(Vector2(390, 700))
	var core := _floor(0).content_rect()
	assert_near(cam.opening_zoom(core), cam.fit_zoom(core), 0.0001, "core opens on the whole factory")
	assert_true(cam.opening_zoom(core) >= FloorCamera.READABLE_FIT, "readable")
	assert_eq(cam.opening_zoom(_floor(1).content_rect()), cam.start_zoom(), "tier 1 unchanged")


func _kit_names(iso: IsoFloor) -> Array[String]:
	var out: Array[String] = []
	for id: String in iso.cells:
		var t: String = iso.types[id]
		out.append("desk_hatch" if t == "qa" else iso.machine_sprite(id, t))
	for c: Vector2i in iso.edges:
		out.append(String(iso.belt_sprite(c)["name"]))
	return out


func test_core_floor_draws_only_factory_kit_machines_and_belts() -> void:
	var iso := _floor(0)
	assert_eq(iso.sprite_set, "factory_kit", "core.json picks the Factory Kit set")
	assert_eq(iso.facing_mismatches().size(), 0, "core facings match")
	for n in _kit_names(iso):
		assert_eq(iso.resolve_sprite(n), "factory_kit/" + n, "core uses the kit sprite for " + n)
	assert_eq(iso.resolve_sprite("floor_tile"), "floor_tile", "floor stays in the normal set")


func test_full_mode_and_tiers_keep_the_normal_sprites() -> void:
	for iso: IsoFloor in [_floor(1), _floor(2)]:
		assert_eq(iso.sprite_set, "", "no sprite set")
		for n in _kit_names(iso):
			assert_eq(iso.resolve_sprite(n), n, "normal sprite for " + n)


func test_factory_kit_set_covers_corners_and_two_edge_facings() -> void:
	var iso := IsoFloor.new()
	iso.sprite_set = "factory_kit"
	for n in ["belt_corner_ne_se", "belt_corner_nw_ne", "belt_corner_se_sw", "belt_corner_sw_nw", "machine_generator_se_sw", "machine_processor_ne_se", "machine_processor_nw_se", "machine_processor_nw_sw", "machine_assembler_ne_sw"]:
		assert_eq(iso.resolve_sprite(n), "factory_kit/" + n, "kit has " + n)
