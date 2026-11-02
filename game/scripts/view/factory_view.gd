class_name FactoryView
extends Node2D
## Draws the factory. Reads sim state only; never mutates it.

const MACHINE_H := 96.0
const AVATAR_R := 11.0
const BELT := 4.0
const NAMES := {"generator": "Generator", "proc_a": "Press A", "proc_b": "Press B", "proc_c": "Press C", "proc_d": "Press D", "assembler": "Assembler", "assembler_a": "Assembler A", "assembler_b": "Assembler B", "warehouse": "Warehouse"}
const COL_BELT := Color("343A46")

var factory: Factory
var board: StatusBoard  # light ring colours (same language as the office monitor)
var area := Rect2(0, 0, 100, 100)  # screen rect the unit layout maps into
var alpha: float = 0.0  # 0..1 progress between ticks
var _link_ticks: Dictionary = {}  # "from>to" -> ticks
var _tick_rate: int = 10
var _font: Font = ThemeDB.fallback_font
var _bubbles: Array[Dictionary] = []  # {id, text, left}
var _event_idx: int = 0
var _time: float = 0.0
var _machine_w: float = 0.34
var _scrap_runs: Dictionary = {}  # machine id -> seconds into the scrap-bin roll
var _pulse: Dictionary = {}  # machine id -> seconds left of the fix pulse
var _sparks: Array[Dictionary] = []  # fixed pool: {p, v, life}
var _was_crew: String = ""
var _qa_seen: int = 0
var _bounce: float = 0.0
const SCRAP_RUN := 2.4
const PULSE_TIME := 0.3
const SPARK_N := 12


func setup(f: Factory, config: SimConfig) -> void:
	factory = f
	_tick_rate = config.tick_rate
	_machine_w = config.machine_w
	_link_ticks.clear()
	_bubbles.clear()
	_event_idx = 0
	_scrap_runs.clear()
	_pulse.clear()
	_sparks.clear()
	_was_crew = ""
	_qa_seen = 0
	_bounce = 0.0
	for l in config.links:
		_link_ticks["%s>%s" % [l["from"], l["to"]]] = maxf(1.0, float(l["transit_time"]) * config.tick_rate)
	queue_redraw()


## One layout source: every floor rect below derives from `area` (and these pure functions of it).
func machine_h() -> float:
	return MACHINE_H * clampf(area.size.x / 720.0, 0.85, 1.0)


func machine_rect(m: Machine) -> Rect2:
	var w := area.size.x * _machine_w
	var h := machine_h()
	var c := area.position + Vector2(m.pos.x * area.size.x, m.pos.y * area.size.y)
	return Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h))


## Heat bar, inside the machine card (4 px, along the bottom).
func heat_rect(m: Machine) -> Rect2:
	var r := machine_rect(m)
	var k := machine_h() / MACHINE_H
	return Rect2(r.position + Vector2(12, r.size.y - 14.0 * k), Vector2(r.size.x - 24, 4))


## Bot avatar centre inside the card (bottom-left); the avatar is drawn here.
func bot_anchor(m: Machine) -> Vector2:
	var r := machine_rect(m)
	var k := machine_h() / MACHINE_H
	return r.position + Vector2(12.0 + AVATAR_R, 56.0 * k)


## Bot name text box, right of the avatar, inside the card.
func badge_rect(m: Machine) -> Rect2:
	var r := machine_rect(m)
	var k := machine_h() / MACHINE_H
	var w := _font.get_string_size(m.bot.name if m.bot != null else "", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	return Rect2(r.position + Vector2(12.0 + AVATAR_R * 2.0 + 6.0, 46.0 * k), Vector2(minf(w + 4.0, r.size.x * 0.5), 20))


## Queue-position badge (1/2/3) of a queued fix, inside the machine card (bottom right).
func queue_badge_rect(m: Machine) -> Rect2:
	var r := machine_rect(m)
	var k := machine_h() / MACHINE_H
	return Rect2(r.position + Vector2(r.size.x - 40, 44.0 * k), Vector2(28, 28))


func machine_at(p: Vector2) -> Machine:
	for m in factory.machines:
		if m.type != "qa" and machine_rect(m).has_point(p):
			return m
	return null


## Scrap bin rect, bottom right of the play area.
func scrap_rect() -> Rect2:
	return Rect2(area.end - Vector2(84, 96), Vector2(76, 84))


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
	queue_redraw()


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


## Floor layout units (sim) -> screen position in the floor area.
func layout_to_px(p: Vector2) -> Vector2:
	return area.position + Vector2(p.x * area.size.x, p.y * area.size.y)


## Where the stairs/lift are (the sim's stairs position).
func stairs_pos() -> Vector2:
	return layout_to_px(factory.worker.stairs) if factory != null else area.position


func worker_visible() -> bool:
	return factory != null and factory.worker_location() != Worker.Location.OFFICE


## The worker at the sim's floor position (smoothed by alpha), kept inside the floor area.
func worker_pos() -> Vector2:
	return _clamp_in(layout_to_px(factory.worker.floor_pos_at(alpha)), WorkerView.HALF)


func _worker_walking() -> bool:
	return factory.worker.is_walking()


func _clamp_in(p: Vector2, margin: float) -> Vector2:
	return Vector2(clampf(p.x, area.position.x + margin, area.end.x - margin), clampf(p.y, area.position.y + margin, area.end.y - margin))


## The avatar's spot, or the scrap-run path (a small robot runs to the bin).
func bot_pos(m: Machine) -> Vector2:
	var p := bot_anchor(m)
	if _scrap_runs.has(m.id):
		var u := float(_scrap_runs[m.id]) / SCRAP_RUN
		var k := 1.0 - absf(2.0 * u - 1.0)
		k = k * k * (3.0 - 2.0 * k)
		p = p.lerp(scrap_rect().get_center(), k)
	return _clamp_in(p, BotView.HALF + 4.0)


func _draw() -> void:
	if factory == null:
		return
	draw_rect(area, UiTheme.BG)
	_draw_links()
	_draw_scrap()
	for m in factory.machines:
		if m.type == "qa":
			_draw_hatch(m)
		else:
			_draw_machine(m)
	for b in _bubbles:
		_draw_bubble(b)
	for sp in _sparks:
		if sp["life"] > 0.0:
			draw_circle(sp["p"], 3.0, Color(UiTheme.GOLD, clampf(sp["life"] * 2.0, 0.0, 1.0)))
	if worker_visible():
		WorkerView.draw(self, worker_pos(), _time, _worker_walking(), factory.crew_busy and not _worker_walking())


## Right-angle belt between two machines: down from the source, across, down into the target.
func _belt_path(a: Machine, b: Machine) -> PackedVector2Array:
	var ra := _box_of(a)
	var rb := _box_of(b)
	var p0 := Vector2(ra.get_center().x, ra.end.y)
	var p1 := Vector2(rb.get_center().x, rb.position.y)
	var my := roundf((p0.y + p1.y) * 0.5)
	if absf(p0.x - p1.x) < 1.0:
		return PackedVector2Array([p0, p1])
	return PackedVector2Array([p0, Vector2(p0.x, my), Vector2(p1.x, my), p1])


func _box_of(m: Machine) -> Rect2:
	return hatch_rect(m) if m.type == "qa" else machine_rect(m)


func _scrap_path(a: Machine) -> PackedVector2Array:
	var ra := _box_of(a)
	var sr := scrap_rect()
	var gx := sr.get_center().x
	return PackedVector2Array([Vector2(ra.end.x, ra.get_center().y), Vector2(gx, ra.get_center().y), Vector2(gx, sr.position.y)])


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


func _draw_links() -> void:
	var paths := {}
	for key: String in _link_ticks:
		var ids := key.split(">")
		var path := _belt_path(factory.get_machine(ids[0]), factory.get_machine(ids[1]))
		paths[key] = path
		draw_polyline(path, COL_BELT, BELT)
	for it in factory.items_in_transit():
		var ticks: float = _link_ticks["%s>%s" % [it["from"], it["via"]]]
		var t := clampf(float(it["progress"]) + alpha / ticks, 0.0, 1.0)
		var path: PackedVector2Array = _scrap_path(factory.get_machine(String(it["from"]))) if it["to"] == "scrap" else paths["%s>%s" % [it["from"], it["via"]]]
		var p := _along(path, t)
		if it["junk"]:
			draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), UiTheme.TEXT_FAINT)
		else:
			draw_circle(p, 5.0, UiTheme.TEXT)


func _draw_scrap() -> void:
	var sr := scrap_rect()
	draw_style_box(UiTheme.box(UiTheme.SURFACE_DIM, UiTheme.LINE, 10.0), sr)
	_text("Scrap", sr.position + Vector2(10, 26), 15, UiTheme.TEXT_DIM, sr.size.x - 12)
	_text(str(factory.scrapped), sr.position + Vector2(10, 62), 28, UiTheme.TEXT, sr.size.x - 12)


## Friendly card name for a machine id.
static func friendly_name(m: Machine) -> String:
	return String(NAMES.get(m.id, m.id))


## Card status: {text, kind} with kind 0 = fine, 1 = warn, 2 = crit.
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
	var r := machine_rect(m)
	var k := machine_h() / MACHINE_H
	var st := _status(m)
	var kind: int = st["kind"]
	if _pulse.has(m.id):
		r = r.grow(sin(float(_pulse[m.id]) / PULSE_TIME * PI) * 6.0)
	var sb := UiTheme.card(kind == 1, kind == 2)
	if kind == 2:
		sb.set_border_width_all(3)
	if m.venting or factory.crew_target == m.id:
		sb.border_color = UiTheme.TEXT
		sb.set_border_width_all(3)
	draw_style_box(sb, r)
	var sz := clampf(r.size.x / 245.0, 0.72, 1.0)
	_text(friendly_name(m), r.position + Vector2(12, 28.0 * k), roundi(21.0 * sz), UiTheme.TEXT, r.size.x - 24)
	# status: grey dot when fine, filled badge otherwise
	if kind == 0:
		draw_circle(r.position + Vector2(r.size.x - 20, 22.0 * k), 6.0, UiTheme.PIP_LINE)
	else:
		var fs := roundi(14.0 * sz)
		var tw := _font.get_string_size(st["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var bd := Rect2(r.position + Vector2(r.size.x - tw - 26, 8.0 * k), Vector2(tw + 16, 24))
		UiTheme.draw_pill(self, bd, UiTheme.CRIT if kind == 2 else UiTheme.WARN)
		_text(st["text"], bd.position + Vector2(8, 17), fs, UiTheme.BG, tw + 2)
	if m.type == "warehouse":
		_text("%d shipped" % factory.shipped, r.position + Vector2(12, 62.0 * k), 17, UiTheme.TEXT_DIM, r.size.x - 24)
	if m.bot != null:
		var c := bot_anchor(m)
		if _pulse.has(m.id) or r.size != machine_rect(m).size:
			c += r.position - machine_rect(m).position
		draw_circle(c, AVATAR_R, m.bot.color)
		_text(m.bot.name.substr(0, 1).to_upper(), c + Vector2(-5, 6), 16, UiTheme.BG, 14.0)
		var bd := badge_rect(m)
		_text(m.bot.name, bd.position + Vector2(0, 16), 16, UiTheme.TEXT_DIM, bd.size.x)
		if kind == 2:
			_text("tap to fix", bd.position + Vector2(bd.size.x + 8, 16), roundi(14.0 * sz), UiTheme.CRIT_TEXT, r.size.x - bd.end.x + r.position.x - 12)
		if _scrap_runs.has(m.id):
			BotView.draw(self, bot_pos(m), m.bot.color, 1, _time, 0.0, 0.0, m.bot.name.to_lower())
	var qi := factory.crew_queue.find(m.id)
	if qi >= 0:
		var qb := queue_badge_rect(m)
		draw_circle(qb.get_center(), qb.size.x * 0.5, UiTheme.TEXT)
		_text(str(qi + 1), qb.position + Vector2(9, 21), 20, UiTheme.BG, qb.size.x)
	var bar := heat_rect(m)
	var hf := clampf(m.heat / 100.0, 0.0, 1.0)
	var hc := UiTheme.CRIT if m.is_faulted() else (UiTheme.WARN if hf >= 0.7 else UiTheme.TEXT_FAINT)
	UiTheme.draw_bar(self, bar, hf, hc)
	if factory.crew_busy and factory.crew_target == m.id:
		var cb := Rect2(bar.position + Vector2(0, -8), bar.size)
		UiTheme.draw_bar(self, cb, factory.crew_progress, UiTheme.ACCENT)


## The QA desk is upstairs: on the floor it is a dashed hatch in the line that products go up through.
func hatch_rect(m: Machine) -> Rect2:
	var c := area.position + Vector2(m.pos.x * area.size.x, m.pos.y * area.size.y)
	return Rect2(c - Vector2(100, 22), Vector2(200, 44))


func _draw_hatch(m: Machine) -> void:
	var r := hatch_rect(m)
	if _bounce > 0.0:
		r.position.y += sin(_bounce / 0.3 * PI) * 5.0
	draw_rect(r, UiTheme.SURFACE_DIM)
	var col := UiTheme.TEXT_FAINT
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		_dashed(corners[i], corners[(i + 1) % 4], col)
	UiTheme.draw_arrow(self, Vector2(r.position.x + 22, r.get_center().y), 7.0, -1, UiTheme.TEXT_DIM)
	_text("UP TO QA DESK", r.position + Vector2(40, 28), 15, UiTheme.TEXT_DIM, r.size.x - 48)


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
	var box := Rect2(r.get_center().x - w * 0.5, r.position.y - 46, w, 38)
	box.position.x = clampf(box.position.x, area.position.x + 2, area.end.x - w - 2)
	box.position.y = maxf(box.position.y, area.position.y + 2)
	draw_style_box(UiTheme.box(UiTheme.SURFACE_2, UiTheme.LINE, 8.0), box)
	_text(String(b["text"]), box.position + Vector2(8, 26), 16, UiTheme.TEXT, w - 16)
