class_name FactoryView
extends Node2D
## Draws the factory. Reads sim state only; never mutates it.

const MACHINE_H := 96.0
const COL_BG := Color(0.1, 0.11, 0.14)

var factory: Factory
var area := Rect2(0, 0, 100, 100)  # screen rect the unit layout maps into
var desk_anchor := Vector2.ZERO  # strip's left edge; the qa_desk machine is drawn there instead
var alpha: float = 0.0  # 0..1 progress between ticks
var _link_ticks: Dictionary = {}  # "from>to" -> ticks
var _tick_rate: int = 10
var _font: Font = ThemeDB.fallback_font
var _bubbles: Array[Dictionary] = []  # {id, text, left}
var _event_idx: int = 0
var _time: float = 0.0


func setup(f: Factory, config: SimConfig) -> void:
	factory = f
	_tick_rate = config.tick_rate
	_link_ticks.clear()
	_bubbles.clear()
	_event_idx = 0
	for l in config.links:
		_link_ticks["%s>%s" % [l["from"], l["to"]]] = maxf(1.0, float(l["transit_time"]) * config.tick_rate)
	queue_redraw()


func machine_rect(m: Machine) -> Rect2:
	var w := area.size.x * 0.34
	var c := area.position + Vector2(m.pos.x * area.size.x, m.pos.y * area.size.y)
	return Rect2(c - Vector2(w, MACHINE_H) * 0.5, Vector2(w, MACHINE_H))


func machine_at(p: Vector2) -> Machine:
	for m in factory.machines:
		if m.type != "qa" and machine_rect(m).has_point(p):
			return m
	return null


## Scrap bin rect at the right edge of the play area.
func scrap_rect() -> Rect2:
	return Rect2(area.position + Vector2(area.size.x - 44, area.size.y * 0.5 - 40), Vector2(40, 80))


## Show a speech bubble for each mistake event. Line pick is by event index (deterministic).
func push_events(events: Array[Dictionary]) -> void:
	for e in events:
		if e.get("type") != "mistake":
			continue
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
	queue_redraw()


func _state_color(m: Machine) -> Color:
	match m.state:
		Machine.State.JAMMED: return Color(0.95, 0.25, 0.2)
		Machine.State.OVERHEATED: return Color(1.0, 0.55, 0.1)
		Machine.State.WORKING: return Color(0.2, 0.65, 0.3)
		Machine.State.CLOGGED: return Color(0.55, 0.35, 0.65)
		Machine.State.STARVED, Machine.State.BLOCKED: return Color(0.33, 0.38, 0.47)
	return Color(0.4, 0.4, 0.42)


func _draw() -> void:
	if factory == null:
		return
	draw_rect(area, COL_BG)
	_draw_links()
	var sr := scrap_rect()
	draw_rect(sr, Color(0.25, 0.18, 0.18))
	draw_rect(sr, Color(0.5, 0.35, 0.35), false, 2.0)
	_text("SCRAP", sr.position + Vector2(-2, -6), 13, Color(0.7, 0.6, 0.6), 60.0)
	for m in factory.machines:
		if m.type != "qa":
			_draw_machine(m)
	for b in _bubbles:
		_draw_bubble(b)


func _draw_links() -> void:
	var pts := {}
	for m in factory.machines:
		pts[m.id] = desk_anchor if m.type == "qa" else machine_rect(m).get_center()
	for key: String in _link_ticks:
		var ids := key.split(">")
		draw_line(pts[ids[0]], pts[ids[1]], Color(0.35, 0.37, 0.42), 3.0)
	for it in factory.items_in_transit():
		var ticks: float = _link_ticks["%s>%s" % [it["from"], it["via"]]]
		var t := clampf(float(it["progress"]) + alpha / ticks, 0.0, 1.0)
		var dest: Vector2 = scrap_rect().get_center() if it["to"] == "scrap" else pts[it["via"]]
		var p: Vector2 = (pts[it["from"]] as Vector2).lerp(dest, t)
		if it["junk"]:
			draw_rect(Rect2(p - Vector2(6, 6), Vector2(12, 12)), Color(0.55, 0.55, 0.58))
		else:
			draw_circle(p, 6.0, Color(1.0, 0.85, 0.3))


func _draw_machine(m: Machine) -> void:
	var r := machine_rect(m)
	var col := _state_color(m)
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(12)
	if m.venting or factory.crew_target == m.id:
		sb.border_color = Color.WHITE
		sb.set_border_width_all(4)
	draw_style_box(sb, r)
	_text(m.id, r.position + Vector2(8, 24), 20, Color.WHITE, r.size.x - 16)
	var pulse := 0.5 + 0.5 * sin(_time * 8.0)
	if m.is_faulted():
		var txt := "JAMMED" if m.state == Machine.State.JAMMED else "OVERHEAT"
		_text(txt, r.position + Vector2(8, 52), 24, Color.WHITE, r.size.x - 16)
	elif m.state == Machine.State.CLOGGED:
		_text("CLOGGED", r.position + Vector2(8, 52), 24, Color.WHITE, r.size.x - 16)
	elif m.overclocked:
		_text("OVERCLOCK", r.position + Vector2(8, 52), 22, Color(1.0, 0.55, 0.1).lerp(Color.WHITE, pulse * 0.6), r.size.x - 16)
	elif m.misrouted:
		_text("MISROUTED", r.position + Vector2(8, 52), 22, Color(1.0, 0.4, 0.4), r.size.x - 16)
	elif m.wrong_recipe:
		_text("WRONG RECIPE", r.position + Vector2(8, 52), 20, Color(0.9, 0.5, 1.0), r.size.x - 16)
	elif m.state == Machine.State.STARVED or m.state == Machine.State.BLOCKED:
		_text(m.state_name().to_lower(), r.position + Vector2(8, 50), 16, Color(0.8, 0.85, 0.95), r.size.x - 16)
	if m.type == "qa":
		_text("queue %d/%d" % [factory.qa_queue().size(), factory.qa_capacity], r.position + Vector2(8, 52), 22, Color.WHITE, r.size.x - 16)
	if m.bot != null:
		var c := r.position + Vector2(18, r.size.y + 18)
		draw_circle(c, 14.0, m.bot.color)
		_text(m.bot.name.substr(0, 1), c + Vector2(-6, 7), 20, Color.BLACK, 20.0)
		_text(m.bot.name, c + Vector2(24, 6), 16, Color(0.85, 0.87, 0.92), r.size.x - 40)
	# heat bar
	var bar := Rect2(r.position + Vector2(8, r.size.y - 18), Vector2(r.size.x - 16, 8))
	draw_rect(bar, Color(0, 0, 0, 0.45))
	var hf := clampf(m.heat / 100.0, 0.0, 1.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * hf, bar.size.y)), Color(1.0, 0.8, 0.2).lerp(Color(1, 0.15, 0.1), hf))
	# crew progress bar
	if factory.crew_busy and factory.crew_target == m.id:
		var cb := Rect2(r.position + Vector2(8, r.size.y - 32), Vector2(r.size.x - 16, 8))
		draw_rect(cb, Color(0, 0, 0, 0.45))
		draw_rect(Rect2(cb.position, Vector2(cb.size.x * factory.crew_progress, cb.size.y)), Color.WHITE)


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
	draw_rect(box, Color(1, 1, 1, 0.95))
	_text(String(b["text"]), box.position + Vector2(8, 26), 16, Color.BLACK, w - 16)
