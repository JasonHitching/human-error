class_name FactoryView
extends Node2D
## Draws the factory. Reads sim state only; never mutates it.

const RECT_W := 120.0  # machine hit rect, logical px (sprite is wider; 8 px gaps between neighbours)
const RECT_H := 130.0
const RECT_UP := 110.0  # rect top above the ground centre
const NAMES := {"generator": "Generator", "proc_a": "Press A", "proc_b": "Press B", "proc_c": "Press C", "proc_d": "Press D", "assembler": "Assembler", "assembler_a": "Assembler A", "assembler_b": "Assembler B", "warehouse": "Warehouse"}
const COL_BELT := Color("343A46")

var factory: Factory
var board: StatusBoard  # light ring colours (same language as the office monitor)
var area := Rect2(0, 0, 100, 100):  # screen rect the iso floor is fitted into
	set(v):
		area = v
		_relayout()
var alpha: float = 0.0  # 0..1 progress between ticks
var _link_ticks: Dictionary = {}  # "from>to" -> ticks
var _tick_rate: int = 10
var _font: Font = ThemeDB.fallback_font
var _bubbles: Array[Dictionary] = []  # {id, text, left}
var _event_idx: int = 0
var _time: float = 0.0
var _iso := IsoFloor.new()
var _s: float = 1.0  # logical px -> screen px
var _origin := Vector2.ZERO
var _cam := FloorCamera.new()
var _cam_ready := false
var _fit_size := Vector2.ZERO
var selected: String = ""  # machine id; highlighted and labelled
var _scrap_runs: Dictionary = {}  # machine id -> seconds into the scrap-bin roll
var _pulse: Dictionary = {}  # machine id -> seconds left of the fix pulse
var _sparks: Array[Dictionary] = []  # fixed pool: {p, v, life}
var _was_crew: String = ""
var _qa_seen: int = 0
var _bounce: float = 0.0
var _fx := FloorFx.new()
var _fx_kinds := PackedInt32Array()
var _fx_tops := PackedVector2Array()
var _bottleneck: String = ""  # machine limiting throughput (FlowReadout), refreshed each draw
var _links: Array = []  # {from, to, path: Array[Vector2i]} for chevrons and belt queues
var _chevrons: Array[Dictionary] = []  # {a, b, key}: one arrow per belt step, cell-local
const WALL_HALF := 0.07  # half the baked wall thickness, in cells
const CHAR_K := 1.3  # bot / worker sprite scale; 1.0 = same scale as the machines
const SCRAP_RUN := 2.4
const PULSE_TIME := 0.3
const SPARK_N := 12


func setup(f: Factory, config: SimConfig) -> void:
	factory = f
	_tick_rate = config.tick_rate
	_iso.setup(config.machines, config.links, config.floor_art)
	_cam_ready = false
	selected = ""
	_cam.cancel()
	_relayout()
	_link_ticks.clear()
	_bubbles.clear()
	_event_idx = 0
	_scrap_runs.clear()
	_pulse.clear()
	_sparks.clear()
	_was_crew = ""
	_qa_seen = 0
	_bounce = 0.0
	_fx.reset(f.machines.size())
	_fx_kinds.resize(f.machines.size())
	_fx_tops.resize(f.machines.size())
	_links.clear()
	_chevrons.clear()
	var seen := {}
	for l in config.links:
		var key := "%s>%s" % [l["from"], l["to"]]
		var pth: Array = _iso.paths.get(key, [])
		_links.append({"from": String(l["from"]), "to": String(l["to"]), "path": pth})
		for i in range(1, pth.size()):
			var st := "%s%s" % [pth[i - 1], pth[i]]
			if not seen.has(st):
				seen[st] = true
				_chevrons.append({"a": pth[i - 1], "b": pth[i], "from": String(l["from"]), "to": String(l["to"])})
	for l in config.links:
		_link_ticks["%s>%s" % [l["from"], l["to"]]] = maxf(1.0, float(l["transit_time"]) * config.tick_rate)
	queue_redraw()


## Bottom strip of the floor area reserved for the screen-space machine info panel.
const PANEL_H := 72.0
const SAFE_PAD := 8.0


## Part of the floor that is clear of UI (view coords, relative to `area`).
func safe_rect() -> Rect2:
	return Rect2(Vector2(SAFE_PAD, SAFE_PAD), Vector2(area.size.x - 2.0 * SAFE_PAD, area.size.y - PANEL_H - 2.0 * SAFE_PAD))


func select(id: String) -> void:
	selected = id
	queue_redraw()


## Select a machine and tween the camera so it ends inside the safe rect.
func focus_machine(id: String) -> void:
	if factory == null or not _iso.cells.has(id):
		return
	selected = id
	var w := IsoFloor.to_local(Vector2(_iso.cells[id])) + Vector2(0, RECT_H * 0.5 - RECT_UP)
	_cam.focus_on(w, safe_rect())
	queue_redraw()


func _relayout() -> void:
	if factory == null:
		return
	var cr := _iso.content_rect()
	_cam.set_view(area.size)
	if not _cam_ready or area.size != _fit_size:
		_fit_size = area.size
		_cam.reset(cr, _cam.opening_zoom(cr))
		_cam_ready = true
	else:
		_cam.set_bounds(cr)
	_s = _cam.zoom
	_origin = area.position + _cam.view * 0.5 - _cam.center * _s


## Zoom out to the whole-factory overview (also used by headless layout checks).
func show_overview() -> void:
	if factory == null:
		return
	var cr := _iso.content_rect()
	_cam.set_view(area.size)
	_cam.reset(cr, _cam.fit_zoom(cr))
	_cam_ready = true
	_fit_size = area.size
	_relayout()
	queue_redraw()


## Id of the machine limiting throughput ("" when the line flows freely).
func bottleneck_id() -> String:
	return FlowReadout.bottleneck(factory) if factory != null else ""


## Items queued on the belt from -> to.
func belt_queue(from_id: String, to_id: String) -> int:
	return FlowReadout.queued_on(factory, from_id, to_id) if factory != null else 0


func camera() -> FloorCamera:
	return _cam


## Drag-pan by a screen delta.
func pan_by(delta: Vector2) -> void:
	_cam.cancel()
	_cam.pan_screen(delta)
	_relayout()
	queue_redraw()


## Wheel/pinch/key zoom around a screen point (absolute coordinates).
func zoom_by(factor: float, at: Vector2) -> void:
	_cam.cancel()
	_cam.zoom_at(factor, at - area.position)
	_relayout()
	queue_redraw()


func keys(d: float) -> void:
	var v := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_key_pressed(KEY_A):
		v.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		v.x += 1.0
	if Input.is_key_pressed(KEY_W):
		v.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		v.y += 1.0
	if v != Vector2.ZERO:
		pan_by(-v.limit_length(1.0) * FloorCamera.KEY_PAN * d)
	var z := (1.0 if Input.is_key_pressed(KEY_EQUAL) or Input.is_key_pressed(KEY_KP_ADD) else 0.0) - (1.0 if Input.is_key_pressed(KEY_MINUS) or Input.is_key_pressed(KEY_KP_SUBTRACT) else 0.0)
	if z != 0.0:
		zoom_by(pow(FloorCamera.KEY_ZOOM, z * d), area.get_center())


## Screen position of a (fractional) grid cell centre.
func ground(g: Vector2) -> Vector2:
	return _origin + IsoFloor.to_local(g) * _s


func machine_ground(m: Machine) -> Vector2:
	return ground(Vector2(_iso.cells.get(m.id, Vector2i.ZERO)))


func machine_h() -> float:
	return RECT_H * _s


func machine_rect(m: Machine) -> Rect2:
	var c := machine_ground(m)
	return Rect2(c + Vector2(-RECT_W * 0.5, -RECT_UP) * _s, Vector2(RECT_W, RECT_H) * _s)


## Heat bar, along the bottom of the machine rect.
func heat_rect(m: Machine) -> Rect2:
	var r := machine_rect(m)
	return Rect2(Vector2(r.get_center().x - 35.0 * _s, r.end.y - 14.0 * _s), Vector2(70.0 * _s, 5.0))


## Bot standing on a free floor cell beside the machine (never a belt); the sprite is centred here.
func bot_anchor(m: Machine) -> Vector2:
	return ground(Vector2(_iso.stand_cell(m.id)))


## Chip under the machine with its name and bot.
func badge_rect(m: Machine) -> Rect2:
	var c := machine_ground(m)
	var w := _font.get_string_size(_badge_text(m), HORIZONTAL_ALIGNMENT_LEFT, -1, _chip_fs()).x + 14.0
	return Rect2(Vector2(c.x - w * 0.5, c.y + 24.0 * _s), Vector2(w, 22.0))


func _badge_text(m: Machine) -> String:
	return friendly_name(m) + (" - " + m.bot.name if m.bot != null else "")


func _chip_fs() -> int:
	return roundi(clampf(15.0 * _s, 13.0, 17.0))


## Machine status chip, just above the machine rect.
func status_rect(m: Machine) -> Rect2:
	var st := _status(m)
	var r := machine_rect(m)
	var w := _font.get_string_size(String(st["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, _chip_fs()).x + 16.0
	return Rect2(Vector2(r.get_center().x - w * 0.5, r.position.y - 26.0), Vector2(w, 24.0))


## Queue-position badge (1/2/3) of a queued fix, inside the machine rect (top right).
func queue_badge_rect(m: Machine) -> Rect2:
	var r := machine_rect(m)
	return Rect2(r.position + Vector2(r.size.x - 34.0, 4.0), Vector2(30, 30))


## Front-most machine under p (largest ground y wins). `grow` widens the rects (used by tests).
func machine_at(p: Vector2, grow: float = 0.0) -> Machine:
	var best: Machine = null
	for m in factory.machines:
		if m.type != "qa" and machine_rect(m).grow(grow).has_point(p):
			if best == null or machine_ground(m).y > machine_ground(best).y:
				best = m
	return best


## Scrap bin rect.
func scrap_rect() -> Rect2:
	var c := ground(Vector2(_iso.scrap_cell))
	return Rect2(c + Vector2(-40.0, -56.0) * _s, Vector2(80.0, 76.0) * _s)


func belt_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Vector2i in _iso.edges:
		out.append(c)
	return out


## Screen rect of one belt tile's diamond.
func belt_rect(c: Vector2i) -> Rect2:
	var g := ground(Vector2(c))
	return Rect2(g - Vector2(IsoFloor.HW, IsoFloor.HH) * _s, Vector2(IsoFloor.HW * 2.0, IsoFloor.HH * 2.0) * _s)


## Show a speech bubble for each mistake event. Line pick is by event index (deterministic).
func push_events(events: Array[Dictionary]) -> void:
	for e in events:
		if e.get("type") == "self_clear":
			_bubbles = _bubbles.filter(func(b: Dictionary) -> bool: return b["id"] != e["machine_id"])
			_bubbles.append({"id": e["machine_id"], "text": "Fixed itself. Probably.", "left": 2.0})
			continue
		if e.get("type") == "trained":
			_bubbles = _bubbles.filter(func(b: Dictionary) -> bool: return b["id"] != e["machine_id"])
			_bubbles.append({"id": e["machine_id"], "text": "Trained! Honestly? Better than you.", "left": 3.0})
			continue
		if e.get("type") == "lesson":
			_bubbles = _bubbles.filter(func(b: Dictionary) -> bool: return b["id"] != e["machine_id"])
			_bubbles.append({"id": e["machine_id"], "text": "Noted. Will not do that again.", "left": 2.5})
			continue
		if e.get("type") != "mistake":
			continue
		if e.get("mistake") == "misroute":
			_scrap_runs[String(e["machine_id"])] = 0.0
		var m := factory.get_machine(String(e["machine_id"]))
		var text := "!"
		if m != null and m.bot != null and not m.bot.lines.is_empty():
			text = m.bot.lines[_event_idx % m.bot.lines.size()]
		_event_idx += 1
		_bubbles = _bubbles.filter(func(b: Dictionary) -> bool: return b["id"] != e["machine_id"])
		_bubbles.append({"id": e["machine_id"], "text": text, "left": 2.0})


func _process(d: float) -> void:
	_time += d
	for b in _bubbles:
		b["left"] -= d
	_bubbles = _bubbles.filter(func(b: Dictionary) -> bool: return b["left"] > 0.0)
	if factory != null:
		_update_juice(d)
		_update_fx(d)
		if _cam.moving:
			_cam.step(d)
			_relayout()
	queue_redraw()


func _update_fx(d: float) -> void:
	for i in factory.machines.size():
		var m := factory.machines[i]
		_fx_kinds[i] = -1 if m.type == "qa" else (maxi(0, int(_status(m)["kind"])) if m.type != "warehouse" else -1)
	_fx.update(d, _fx_kinds)


func _update_juice(d: float) -> void:
	for id: String in _scrap_runs.keys():
		_scrap_runs[id] += d
		if _scrap_runs[id] >= SCRAP_RUN:
			_scrap_runs.erase(id)
	for id: String in _pulse.keys():
		_pulse[id] -= d
		if _pulse[id] <= 0.0:
			_pulse.erase(id)
	_bounce = maxf(0.0, _bounce - d)
	var q := factory.qa_queue().size()
	if q > _qa_seen:
		_bounce = 0.3
	_qa_seen = q
	if _was_crew != "" and not factory.crew_busy:  # a crew job just ended
		var m := factory.get_machine(_was_crew)
		if m != null and not m.is_faulted():
			_pulse[m.id] = PULSE_TIME
			_spawn_sparks(machine_rect(m).get_center())
	_was_crew = factory.crew_target if factory.crew_busy else ""
	for s in _sparks:
		s["life"] -= d
		s["p"] += s["v"] * d


func _spawn_sparks(c: Vector2) -> void:
	_sparks.clear()
	for i in SPARK_N:
		var a := float(i) / SPARK_N * TAU
		_sparks.append({"p": c, "v": Vector2(cos(a), sin(a)) * (70.0 + 30.0 * float(i % 3)), "life": 0.5})


## Sim layout units -> screen. Shepard interpolation of the machines' screen spots (exact at each
## machine and at the stairs), so the worker walks between the iso machines.
func layout_to_px(p: Vector2) -> Vector2:
	var num := Vector2.ZERO
	var den := 0.0
	var pts: Array = [[factory.worker.stairs, ground(_iso.stairs_cell)]]
	for m in factory.machines:
		pts.append([m.pos, machine_ground(m) + IsoFloor.WORKER_STOP * _s])
	for e: Array in pts:
		var d2 := p.distance_squared_to(e[0])
		if d2 < 1e-8:
			return e[1]
		num += (e[1] as Vector2) / d2
		den += 1.0 / d2
	return num / den


## Where the stairs/lift are (the sim's stairs position).
func stairs_pos() -> Vector2:
	return ground(_iso.stairs_cell) if factory != null else area.position


func worker_visible() -> bool:
	return factory != null and factory.worker_location() != Worker.Location.OFFICE


## The worker at the sim's floor position (smoothed by alpha), kept inside the floor area.
func worker_pos() -> Vector2:
	return _clamp_in(layout_to_px(factory.worker.floor_pos_at(alpha)), WorkerView.HALF)


func _worker_walking() -> bool:
	return factory.worker.is_walking()


func _clamp_in(p: Vector2, margin: float) -> Vector2:
	return Vector2(clampf(p.x, area.position.x + margin, area.end.x - margin), clampf(p.y, area.position.y + margin, area.end.y - margin))


## The bot's spot, or the scrap-run path (a small robot runs to the bin).
func bot_pos(m: Machine) -> Vector2:
	var p := bot_anchor(m)
	if _scrap_runs.has(m.id):
		var u := float(_scrap_runs[m.id]) / SCRAP_RUN
		var k := 1.0 - absf(2.0 * u - 1.0)
		k = k * k * (3.0 - 2.0 * k)
		p = p.lerp(scrap_rect().get_center(), k)
	return _clamp_in(p, BotView.HALF + 4.0)


## Draws sprite `n` with its anchor on screen point g. False (nothing drawn) when the sprite is missing.
func _spr(n: String, g: Vector2, flip: bool = false, mod: Color = Color.WHITE, scale: float = 1.0) -> bool:
	n = _iso.resolve_sprite(n)
	var t := Sprites.tex(n)
	if t == null:
		return false
	var f := 0.5 * _s * scale
	var sz := t.get_size() * f
	var tl := g - IsoFloor.anchor(n) * f
	if flip:
		draw_texture_rect(t, Rect2(tl, Vector2(-sz.x, sz.y)), false, mod)  # negative width mirrors in place (it does not extend left)
	else:
		draw_texture_rect(t, Rect2(tl, sz), false, mod)
	return true


func _diamond(g: Vector2, k: float = 1.0) -> PackedVector2Array:
	var hw := IsoFloor.HW * _s * k
	var hh := IsoFloor.HH * _s * k
	return PackedVector2Array([g + Vector2(0, -hh), g + Vector2(hw, 0), g + Vector2(0, hh), g + Vector2(-hw, 0)])


func _draw() -> void:
	if factory == null:
		return
	RenderingServer.canvas_item_set_clip(get_canvas_item(), true)  # effects never leave the floor area
	RenderingServer.canvas_item_set_custom_rect(get_canvas_item(), true, area)
	draw_rect(area, UiTheme.BG)
	_bottleneck = FlowReadout.bottleneck(factory)
	_draw_ground()
	var list: Array[Dictionary] = []
	for m in factory.machines:
		list.append({"y": machine_ground(m).y, "k": 0, "m": m})
		if m.bot != null:
			list.append({"y": bot_pos(m).y + 24.0 * _s, "k": 3, "m": m})
	for pr: Dictionary in _iso.props:
		var pg := ground(Vector2(float((pr["g"] as Array)[0]), float((pr["g"] as Array)[1])))
		list.append({"y": pg.y, "k": 1, "p": pr, "g": pg})
	list.append({"y": ground(Vector2(_iso.scrap_cell)).y, "k": 2})
	for it in factory.items_in_transit():
		var pi := _item_pos(it)
		list.append({"y": pi.y + 2.0, "k": 5, "p": pi, "junk": it["junk"]})
	if worker_visible():
		list.append({"y": worker_pos().y + 24.0 * _s, "k": 4})
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["y"]) < float(b["y"]))
	for e in list:
		match int(e["k"]):
			0:
				var m: Machine = e["m"]
				if m.type == "qa":
					_draw_hatch(m)
				else:
					_draw_machine(m)
			1:
				var pn := String((e["p"] as Dictionary)["s"])
				_spr("shadow_machine", e["g"], false, Color(1, 1, 1, 0.6))
				_spr(pn, e["g"], pn == "fence" and int((e["p"] as Dictionary)["g"][0]) % 2 == 1)
			2:
				_draw_scrap()
			3:
				var bm: Machine = e["m"]
				var panic := bm.is_faulted() or bm.misrouted
				BotView.draw(self, bot_pos(bm), bm.bot.color, 1 if panic else 0, _time, 0.0, 0.0, bm.bot.name.to_lower(), CHAR_K * _s)
			4:
				WorkerView.draw(self, worker_pos(), _time, _worker_walking(), factory.crew_busy and not _worker_walking(), CHAR_K * _s)
			5:
				var pp: Vector2 = e["p"]
				var tint := Color(0.55, 0.58, 0.65) if e["junk"] else Color.WHITE
				if not _spr("crate", pp, false, tint, 0.4):
					if e["junk"]:
						draw_rect(Rect2(pp - Vector2(5, 5) * _s, Vector2(10, 10) * _s), UiTheme.TEXT_FAINT)
					else:
						draw_circle(pp, 5.0 * _s, UiTheme.TEXT)
	_draw_fx_top()
	for m in factory.machines:
		_draw_chips(m)
	for b in _bubbles:
		_draw_bubble(b)
	for sp in _sparks:
		if sp["life"] > 0.0:
			draw_circle(sp["p"], 3.0, Color(UiTheme.GOLD, clampf(sp["life"] * 2.0, 0.0, 1.0)))


## Floor tiles, back walls and belt tiles: flat things that never need depth sorting.
func _draw_ground() -> void:
	var ar := area.grow(1.0)
	var gr := _iso.grid
	# Back walls on the NW and NE edges, flush with the floor edge and one wall piece per cell so the
	# seams line up. The window piece (2 cells, over the stairs) replaces the plain pieces on cells 1-2.
	var wall_off := -0.5 - WALL_HALF
	for i in gr.y:
		if i == 1:
			_wall("wall_back", ground(Vector2(wall_off, 1.5)), false, ar)
		elif i != 2:
			_wall("wall_back_plain", ground(Vector2(wall_off, float(i))), false, ar)
	for i in gr.x:
		_wall("wall_back_plain", ground(Vector2(float(i), wall_off)), true, ar)
	for gx in gr.x:
		for gy in gr.y:
			var g := ground(Vector2(gx, gy))
			if not ar.intersects(Rect2(g - Vector2(IsoFloor.HW, IsoFloor.HH) * _s, Vector2(IsoFloor.HW, IsoFloor.HH) * 2.0 * _s)):
				continue  # off-screen; partly visible tiles are drawn (the floor area clips them)
			if not _spr("floor_tile_alt" if (gx + gy) % 2 == 1 else "floor_tile", g):
				draw_colored_polygon(_diamond(g, 0.98), UiTheme.SURFACE_DIM if (gx + gy) % 2 == 0 else UiTheme.BG.lightened(0.04))
	for c: Vector2i in _iso.edges:
		var bs := _iso.belt_sprite(c)
		if not _spr(String(bs["name"]), ground(Vector2(c)), bool(bs["flip"])):
			draw_colored_polygon(_diamond(ground(Vector2(c)), 0.8), COL_BELT)
	_draw_fx_ground()


## Glow under each machine (loudest thing on the floor), then belt motion and the lamp's light pool.
func _draw_fx_ground() -> void:
	for m in factory.machines:
		if m.type != "qa":
			_fx.draw_glow(self, machine_ground(m), _s, int(_status(m)["kind"]), _time)
	if FloorFx.enabled:
		var ph := fposmod(_time * 0.5, 1.0)
		for c: Vector2i in _iso.edges:
			FloorFx.draw_belt_motion(self, ground(Vector2(c)), _iso.edges[c], _s, ph)
	_draw_chevrons()
	_draw_belt_queues()
	var lm := _lamp_machine()
	if lm != null:
		_fx.draw_lamp(self, machine_ground(lm), _s, _time, area)
		_fx.draw_dust(self, machine_ground(lm), _s, _time, area)


## One arrow per belt step, pointing the way the items go. Amber when the belt is backing up, red when full.
func _draw_chevrons() -> void:
	for ch in _chevrons:
		var a := ground(Vector2(ch["a"]))
		var b := ground(Vector2(ch["b"]))
		var d := (b - a).normalized()
		var n := Vector2(-d.y, d.x)
		var c := (a + b) * 0.5
		var col := Color(1, 1, 1, 0.4)
		var to := factory.get_machine(String(ch["to"]))
		if FlowReadout.queued_on(factory, String(ch["from"]), String(ch["to"])) >= 2:
			col = Color(UiTheme.WARN, 0.9)
			if to != null and to.input_cap > 0 and to.input_count >= to.input_cap:
				col = Color(UiTheme.CRIT, 0.9)
		var k := 7.0 * _s
		draw_polyline(PackedVector2Array([c - d * k * 0.6 + n * k * 0.8, c + d * k * 0.6, c - d * k * 0.6 - n * k * 0.8]), col, maxf(2.0, 2.5 * _s))


## Items held back at a sender (receiver full) bunch up on the belt cells just before the receiver.
func _draw_belt_queues() -> void:
	for l: Dictionary in _links:
		var a := factory.get_machine(String(l["from"]))
		var b := factory.get_machine(String(l["to"]))
		if a == null or b == null or b.input_cap <= 0 or b.input_count < b.input_cap or a.output_count <= 0:
			continue
		var pth: Array = l["path"]
		var n := mini(a.output_count, 2 * maxi(pth.size() - 2, 0))
		for i in n:
			var cell: Vector2i = pth[pth.size() - 2 - i / 2]
			var off := Vector2(-9.0, 0) if i % 2 == 0 else Vector2(9.0, 0)
			var p := ground(Vector2(cell)) + off * _s + IsoFloor.belt_top_offset() * _s
			if not _spr("crate", p, false, Color(1.0, 0.85, 0.6), 0.4):
				draw_circle(p, 5.0 * _s, UiTheme.WARN)


## Input-queue pips under a machine: one per slot, filled = waiting items. Amber when backed up, red when full.
func _draw_input_pips(m: Machine) -> void:
	if m.input_cap <= 0 or m.type == "qa":
		return
	var n := mini(m.input_cap, 12)
	var fill := FlowReadout.input_fill(m)
	if fill <= 0.0 and m.id != selected:
		return  # nothing queued: no empty-slot clutter under healthy machines
	var col := UiTheme.CRIT if fill >= 1.0 else (UiTheme.WARN if fill >= FlowReadout.FULL_FILL else UiTheme.TEXT_DIM)
	var g := machine_ground(m) + Vector2(0, 16.0 * _s)
	var step := 11.0 * _s
	var x0 := -step * float(n - 1) * 0.5
	var filled := roundi(fill * n)
	for i in n:
		var pc := g + Vector2(x0 + step * i, 0)
		if i < filled:
			draw_circle(pc, maxf(3.5, 4.0 * _s), col)
		else:
			draw_arc(pc, maxf(3.5, 4.0 * _s), 0.0, TAU, 10, Color(UiTheme.TEXT_FAINT, 0.8), 1.5)


func _lamp_machine() -> Machine:
	for m in factory.machines:
		if m.type == "assembler":
			return m
	return null


## Steam above the machines and the vignette; stays inside `area`.
func _draw_fx_top() -> void:
	if not FloorFx.enabled:
		return
	for i in factory.machines.size():
		_fx_tops[i] = machine_ground(factory.machines[i]) + Vector2(0, -RECT_UP + 10.0) * _s
	_fx.draw_steam(self, _fx_tops, _s)
	_fx.draw_vignette(self, area)


func _wall(n: String, g: Vector2, flip: bool, ar: Rect2) -> void:
	var t := Sprites.tex(n)
	if t == null:
		return
	var f := 0.5 * _s
	var tl := g - IsoFloor.anchor(n) * f
	if ar.intersects(Rect2(tl, t.get_size() * f)):
		_spr(n, g, flip)


## Screen position of an item in transit (along the belt cells, or straight to the scrap bin).
func _item_pos(it: Dictionary) -> Vector2:
	var key := "%s>%s" % [it["from"], it["via"]]
	var ticks: float = _link_ticks[key]
	var t := clampf(float(it["progress"]) + alpha / ticks, 0.0, 1.0)
	var pts := PackedVector2Array()
	if it["to"] == "scrap":
		pts.append(machine_ground(factory.get_machine(String(it["from"]))))
		pts.append(ground(Vector2(_iso.scrap_cell)))
	else:
		for c: Vector2i in _iso.paths.get(key, []):
			pts.append(ground(Vector2(c)))
	if pts.size() < 2:
		return area.get_center()
	return _along(pts, t) + IsoFloor.belt_top_offset() * _s


## Point a fraction t along a polyline (by length).
func _along(pts: PackedVector2Array, t: float) -> Vector2:
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i - 1].distance_to(pts[i])
	var want := total * clampf(t, 0.0, 1.0)
	for i in range(1, pts.size()):
		var seg := pts[i - 1].distance_to(pts[i])
		if want <= seg or i == pts.size() - 1:
			return pts[i - 1].lerp(pts[i], want / maxf(seg, 0.001))
		want -= seg
	return pts[pts.size() - 1]


func _draw_scrap() -> void:
	var sr := scrap_rect()
	var g := ground(Vector2(_iso.scrap_cell))
	_spr("shadow_machine", g, false, Color(1, 1, 1, 0.6))
	if not _spr("scrap_bin", g):
		draw_style_box(UiTheme.box(UiTheme.SURFACE_DIM, UiTheme.LINE, 10.0), sr)
	if factory.scrapped <= 0 and selected != "scrap":
		return  # no permanent labels: the count only appears once something has been scrapped
	var label := "Scrap %d" % factory.scrapped
	var w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, _chip_fs()).x + 14.0
	var cr := Rect2(Vector2(sr.get_center().x - w * 0.5, sr.end.y + 2.0), Vector2(w, 22))
	draw_style_box(UiTheme.box(UiTheme.SURFACE_2, UiTheme.LINE, 8.0), cr)
	_text(label, cr.position + Vector2(7, 16), _chip_fs(), UiTheme.TEXT, w)


## Friendly card name for a machine id.
static func friendly_name(m: Machine) -> String:
	return String(NAMES.get(m.id, m.id))


## Status: {text, kind} with kind 0 = fine, 1 = warn, 2 = crit.
func _status(m: Machine) -> Dictionary:
	if m.state == Machine.State.JAMMED:
		return {"text": "JAMMED", "kind": 2}
	if m.state == Machine.State.OVERHEATED:
		return {"text": "OVERHEAT", "kind": 2}
	if m.state == Machine.State.CLOGGED:
		return {"text": "CLOGGED", "kind": 2}
	if m.misrouted:
		return {"text": "MISROUTED", "kind": 2}
	if m.wrong_recipe:
		return {"text": "RECIPE", "kind": 2}
	if m.overclocked:
		return {"text": "OVERCLOCK", "kind": 1}
	if m.heat >= 70.0:
		return {"text": "HOT", "kind": 1}
	return {"text": "", "kind": 0}


func _draw_machine(m: Machine) -> void:
	var g := machine_ground(m)
	var r := machine_rect(m)
	var kind: int = _status(m)["kind"]
	if m.id == selected:
		var sel := _diamond(g, 1.15)
		sel.append(sel[0])
		draw_polyline(sel, UiTheme.ACCENT, 4.0)
	if m.venting or factory.crew_target == m.id or _pulse.has(m.id):
		var grow := 1.0 + (sin(float(_pulse.get(m.id, 0.0)) / PULSE_TIME * PI) * 0.15 if _pulse.has(m.id) else 0.0)
		var ring := _diamond(g, 1.0 * grow)
		ring.append(ring[0])
		draw_polyline(ring, UiTheme.TEXT, 3.0)
	_spr("shadow_machine", g)
	if m.id == _bottleneck and kind == 0:
		var br := _diamond(g, 1.08)
		br.append(br[0])
		draw_polyline(br, UiTheme.WARN, 3.0)
	var tint := Color.WHITE
	if m.state == Machine.State.STARVED and m.type != "generator":
		tint = Color(0.72, 0.76, 0.86)  # starved: dimmed but still solid (alpha made machines vanish into the floor)
	elif m.state == Machine.State.BLOCKED:
		tint = Color(1.0, 0.9, 0.75)  # blocked: items pile up upstream
	var sprite := _iso.machine_sprite(m.id, m.type)
	if not _spr(sprite, g, false, tint) and not _spr("machine_" + m.type, g, false, tint):
		var sb := UiTheme.card(kind == 1, kind == 2)
		if kind == 2:
			sb.set_border_width_all(3)
		draw_style_box(sb, r)
		_text(friendly_name(m), r.position + Vector2(10, 28), 18, UiTheme.TEXT, r.size.x - 20)


## Heat bar, queue badge, status chip and name chip: the readable layer on top of the sprites.
func _draw_chips(m: Machine) -> void:
	if m.type == "qa":
		return
	var fs := _chip_fs()
	var st := _status(m)
	var kind: int = st["kind"]
	_draw_input_pips(m)
	if kind != 0:
		var sr := status_rect(m)
		UiTheme.draw_pill(self, sr, UiTheme.CRIT if kind == 2 else UiTheme.WARN)
		_text(st["text"], sr.position + Vector2(8, 17), fs, UiTheme.BG, sr.size.x - 10)
	var bd := badge_rect(m)
	if m.id == selected or kind != 0:  # no permanent labels on healthy machines
		draw_style_box(UiTheme.box(UiTheme.SURFACE_2, UiTheme.LINE, 8.0), bd)
		_text(_badge_text(m), bd.position + Vector2(7, 16), fs, UiTheme.TEXT_DIM, bd.size.x - 10)
	if m.type == "warehouse" and m.id == selected:  # the top bar already shows progress
		_text("%d shipped" % factory.shipped, bd.position + Vector2(0, 40), fs, UiTheme.TEXT_DIM, bd.size.x)
	elif kind == 2 and m.bot != null:
		_text("tap to fix", bd.position + Vector2(0, 40), fs, UiTheme.CRIT_TEXT, bd.size.x)
	var qi := factory.crew_queue.find(m.id)
	if qi >= 0:
		var qb := queue_badge_rect(m)
		draw_circle(qb.get_center(), qb.size.x * 0.5, UiTheme.TEXT)
		_text(str(qi + 1), qb.position + Vector2(10, 22), 20, UiTheme.BG, qb.size.x)
	if m.type != "warehouse":
		var bar := heat_rect(m)
		var hf := clampf(m.heat / 100.0, 0.0, 1.0)
		var hc := UiTheme.CRIT if m.is_faulted() else (UiTheme.WARN if hf >= 0.7 else UiTheme.TEXT_FAINT)
		UiTheme.draw_bar(self, bar, hf, hc)
		if factory.crew_busy and factory.crew_target == m.id:
			UiTheme.draw_bar(self, Rect2(bar.position + Vector2(0, -8), bar.size), factory.crew_progress, UiTheme.ACCENT)


## The QA desk is upstairs: on the floor it is the hatch products go up through.
func hatch_rect(m: Machine) -> Rect2:
	var c := machine_ground(m)
	return Rect2(c + Vector2(-64.0, -70.0) * _s, Vector2(128.0, 100.0) * _s)


func _draw_hatch(m: Machine) -> void:
	var g := machine_ground(m)
	var r := hatch_rect(m)
	if _bounce > 0.0:
		g.y += sin(_bounce / 0.3 * PI) * 5.0
		r.position.y += sin(_bounce / 0.3 * PI) * 5.0
	_spr("shadow_machine", g)
	if _spr("desk_hatch", g):
		if m.id != selected:
			return  # label only on the selected hatch
		var lr := Rect2(Vector2(r.get_center().x - 60.0 * _s, r.end.y + 4.0), Vector2(120.0 * _s, 22))
		draw_style_box(UiTheme.box(UiTheme.SURFACE_2, UiTheme.LINE, 8.0), lr)
		_text("UP TO QA DESK", lr.position + Vector2(6, 16), maxi(11, roundi(13.0 * _s)), UiTheme.TEXT_DIM, lr.size.x - 8)
		return
	draw_rect(r, UiTheme.SURFACE_DIM)
	var col := UiTheme.TEXT_FAINT
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		_dashed(corners[i], corners[(i + 1) % 4], col)
	_text("UP TO QA DESK", r.position + Vector2(10, 28), 15, UiTheme.TEXT_DIM, r.size.x - 16)


func _dashed(a: Vector2, b: Vector2, col: Color) -> void:
	var d := a.distance_to(b)
	var dir := (b - a) / maxf(d, 0.001)
	var x := 0.0
	while x < d:
		draw_line(a + dir * x, a + dir * minf(x + 8.0, d), col, 2.0)
		x += 14.0


func _text(s: String, pos: Vector2, size: int, col: Color, width: float) -> void:
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, width, size, col)


func _draw_bubble(b: Dictionary) -> void:
	var m := factory.get_machine(String(b["id"]))
	if m == null:
		return
	var r := machine_rect(m)
	var w := minf(area.size.x * 0.6, 240.0)
	var box := Rect2(r.get_center().x - w * 0.5, r.position.y - 68, w, 38)
	box.position.x = clampf(box.position.x, area.position.x + 2, area.end.x - w - 2)
	box.position.y = maxf(box.position.y, area.position.y + 2)
	draw_style_box(UiTheme.box(UiTheme.SURFACE_2, UiTheme.LINE, 8.0), box)
	_text(String(b["text"]), box.position + Vector2(8, 26), 16, UiTheme.TEXT, w - 16)
