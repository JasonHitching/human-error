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


func test_bots_and_worker_never_stand_on_belts_both_tiers() -> void:
	for tier in [1, 2]:
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
	for tier in [1, 2]:
		var iso := _floor(tier)
		for msg in iso.facing_mismatches():
			failures.append("tier %d: %s" % [tier, msg])
		for id: String in iso.cells:
			if iso.types[id] == "qa":
				continue
			if iso.press_axis(id) != "":
				continue  # drawn with the press frames (test_processors_use_press_sprite_along_their_belts)
			var path := "res://assets/sprites/%s.png" % iso.machine_sprite(id, iso.types[id])
			assert_true(FileAccess.file_exists(path), "tier %d %s: missing facing sprite %s" % [tier, id, path])


func test_processors_use_press_sprite_along_their_belts() -> void:
	for tier in [1, 2]:
		var iso := _floor(tier)
		for i in PressAnim.FRAMES:
			assert_true(FileAccess.file_exists("res://assets/sprites/%s.png" % PressAnim.sprite_name(i)), "press frame %d" % i)
		for id: String in iso.cells:
			if iso.types[id] != "processor":
				continue
			var axis := iso.press_axis(id)
			assert_true(axis != "", "tier %d %s: belts must run straight through the press" % [tier, id])
			# sprite belt is SW-NE (gy); gx machines draw it flipped, so every belt edge is on that axis
			var want: Array = ["ne", "sw"] if axis == "gy" else ["nw", "se"]
			var edges := iso.machine_edges(id)
			edges.sort()
			assert_eq(edges, want, "tier %d %s belt edges vs press axis" % [tier, id])
			# its baked belt replaces the tile: no belt tile in the machine's own cell
			assert_true(not iso.edges.has(iso.cells[id]), "tier %d %s: belt tile under baked belt" % [tier, id])


func test_press_frame_selection() -> void:
	assert_eq(PressAnim.frame(Machine.State.IDLE, 5.0, true), 0)
	assert_eq(PressAnim.frame(Machine.State.STARVED, 5.0, true), 0)
	assert_eq(PressAnim.frame(Machine.State.JAMMED, 5.0, true), PressAnim.PRESSED)
	assert_eq(PressAnim.frame(Machine.State.OVERHEATED, 5.0, true), PressAnim.PRESSED)
	assert_eq(PressAnim.frame(Machine.State.WORKING, 0.0, false), 0)
	assert_eq(PressAnim.frame(Machine.State.WORKING, 7.3, false), 0)
	var seen: Dictionary = {}
	for i in 60:
		seen[PressAnim.frame(Machine.State.WORKING, float(i) / 30.0, true)] = true
	assert_eq(seen.size(), PressAnim.FRAMES, "working cycles through all frames")


func test_press_belt_reach_matches_sprite() -> void:
	var img := Sprites.tex(PressAnim.sprite_name(0)).get_image()
	var box := img.get_used_rect()
	var anchor_x: float = IsoFloor.anchor("press").x
	assert_true(absf((anchor_x - box.position.x) - PressAnim.BELT_REACH_PX) <= 2.0, "left belt tip vs BELT_REACH_PX")
	assert_true(absf((box.end.x - anchor_x) - PressAnim.BELT_REACH_PX) <= 2.0, "right belt tip vs BELT_REACH_PX")


func test_press_belt_ends_meet_neighbouring_belt_tiles_both_tiers() -> void:
	for tier in [1, 2]:
		var iso := _floor(tier)
		# belt tip must land on the far end of the hidden neighbour tile (1.5 cells out = 96 px along screen x)
		assert_true(absf(PressAnim.belt_reach() - IsoFloor.HW * 1.5) <= 2.0, "press belt end vs neighbour tile end")
		for id: String in iso.cells:
			var axis := iso.press_axis(id)
			if axis == "":
				continue
			var d := Vector2i(0, 1) if axis == "gy" else Vector2i(1, 0)
			for k in [-1, 1]:
				var n: Vector2i = iso.cells[id] + d * k
				assert_true(iso.press_hidden.has(n), "tier %d %s: neighbour tile %s is hidden under the press belt" % [tier, id, n])
				var bs: String = iso.belt_sprite(n)["name"]
				assert_eq(bs, "belt_straight_a" if axis == "gy" else "belt_straight_b", "tier %d %s: hidden tile must be straight, not a bend" % [tier, id])
				var after: Vector2i = iso.cells[id] + d * (2 * k)
				assert_true(iso.edges.has(after) or iso.by_cell.has(after), "tier %d %s: belt or machine meets the press belt end at %s" % [tier, id, after])
		for c: Vector2i in iso.press_hidden:
			assert_true(iso.edges.has(c), "hidden cell is a belt cell")
