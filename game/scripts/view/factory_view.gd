class_name FactoryView
extends Node2D
## Draws the factory. Reads sim state only; never mutates it.

const MACHINE_H := 96.0
const COL_BG := Color(0.1, 0.11, 0.14)

var factory: Factory
var area := Rect2(0, 0, 100, 100)  # screen rect the unit layout maps into
var alpha: float = 0.0  # 0..1 progress between ticks
var _link_ticks: Dictionary = {}  # "from>to" -> ticks
var _tick_rate: int = 10
var _font: Font = ThemeDB.fallback_font


func setup(f: Factory, config: SimConfig) -> void:
	factory = f
	_tick_rate = config.tick_rate
	_link_ticks.clear()
	for l in config.links:
		_link_ticks["%s>%s" % [l["from"], l["to"]]] = maxf(1.0, float(l["transit_time"]) * config.tick_rate)
	queue_redraw()


func machine_rect(m: Machine) -> Rect2:
	var w := area.size.x * 0.34
	var c := area.position + Vector2(m.pos.x * area.size.x, m.pos.y * area.size.y)
	return Rect2(c - Vector2(w, MACHINE_H) * 0.5, Vector2(w, MACHINE_H))


func machine_at(p: Vector2) -> Machine:
	for m in factory.machines:
		if machine_rect(m).has_point(p):
			return m
	return null


func _process(_d: float) -> void:
	queue_redraw()


func _state_color(m: Machine) -> Color:
	match m.state:
		Machine.State.JAMMED: return Color(0.95, 0.25, 0.2)
		Machine.State.OVERHEATED: return Color(1.0, 0.55, 0.1)
		Machine.State.WORKING: return Color(0.2, 0.65, 0.3)
		Machine.State.STARVED, Machine.State.BLOCKED: return Color(0.33, 0.38, 0.47)
	return Color(0.4, 0.4, 0.42)


func _draw() -> void:
	if factory == null:
		return
	draw_rect(area, COL_BG)
	_draw_links()
	for m in factory.machines:
		_draw_machine(m)


func _draw_links() -> void:
	var pts := {}
	for m in factory.machines:
		pts[m.id] = machine_rect(m).get_center()
	for key: String in _link_ticks:
		var ids := key.split(">")
		draw_line(pts[ids[0]], pts[ids[1]], Color(0.35, 0.37, 0.42), 3.0)
	for it in factory.items_in_transit():
		var ticks: float = _link_ticks["%s>%s" % [it["from"], it["to"]]]
		var t := clampf(float(it["progress"]) + alpha / ticks, 0.0, 1.0)
		var p: Vector2 = (pts[it["from"]] as Vector2).lerp(pts[it["to"]], t)
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
	if m.is_faulted():
		var txt := "JAMMED" if m.state == Machine.State.JAMMED else "OVERHEAT"
		_text(txt, r.position + Vector2(8, 52), 24, Color.WHITE, r.size.x - 16)
	elif m.state == Machine.State.STARVED or m.state == Machine.State.BLOCKED:
		_text(m.state_name().to_lower(), r.position + Vector2(8, 50), 16, Color(0.8, 0.85, 0.95), r.size.x - 16)
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
