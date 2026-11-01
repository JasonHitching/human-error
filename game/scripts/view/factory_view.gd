class_name FactoryView
extends Node2D
## Draws the factory. Reads sim state only; never mutates it.

const MACHINE_H := 96.0
const COL_BG := Color(0.1, 0.11, 0.14)

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
var _scrap_runs: Dictionary = {}  # machine id -> seconds into the scrap-bin roll
var _pulse: Dictionary = {}  # machine id -> seconds left of the fix pulse
var _sparks: Array[Dictionary] = []  # fixed pool: {p, v, life}
var _was_crew: String = ""
var _qa_seen: int = 0
var _bounce: float = 0.0
const SCRAP_RUN := 2.4
const PULSE_TIME := 0.4
const SPARK_N := 12


func setup(f: Factory, config: SimConfig) -> void:
	factory = f
	_tick_rate = config.tick_rate
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


## Cosmetic bot position for a machine's bot, always inside the floor area.
func bot_pos(m: Machine) -> Vector2:
	var r := machine_rect(m)
	var p := r.position + Vector2(24, r.size.y + 26)
	if _scrap_runs.has(m.id):
		var u := float(_scrap_runs[m.id]) / SCRAP_RUN
		var k := 1.0 - absf(2.0 * u - 1.0)
		k = k * k * (3.0 - 2.0 * k)
		p = p.lerp(scrap_rect().get_center(), k)
	elif m.state == Machine.State.WORKING:
		p.x += sin(_time * 3.0 + float(m.id.hash() % 7)) * 10.0
	else:
		p.y += sin(_time * 2.0 + float(m.id.hash() % 7)) * 2.0
	return _clamp_in(p, BotView.HALF + 4.0)


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
	Sprites.draw_fit(self, Sprites.tex("bg_floor"), area)
	_draw_links()
	var sr := scrap_rect()
	if not Sprites.draw_named(self, "scrap_bin", sr):
		draw_rect(sr, Color(0.25, 0.18, 0.18))
		draw_rect(sr, Color(0.5, 0.35, 0.35), false, 2.0)
	_text("SCRAP", sr.position + Vector2(-2, -6), 13, Color(0.7, 0.6, 0.6), 60.0)
	for m in factory.machines:
		if m.type == "qa":
			_draw_hatch(m)
		else:
			_draw_machine(m)
	for b in _bubbles:
		_draw_bubble(b)
	for sp in _sparks:
		if sp["life"] > 0.0:
			draw_circle(sp["p"], 3.0, Color(1.0, 0.9, 0.3, clampf(sp["life"] * 2.0, 0.0, 1.0)))
	if worker_visible():
		WorkerView.draw(self, worker_pos(), _time, _worker_walking(), factory.crew_busy and not _worker_walking())


func _draw_links() -> void:
	var pts := {}
	for m in factory.machines:
		pts[m.id] = hatch_rect(m).get_center() if m.type == "qa" else machine_rect(m).get_center()
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
	if _pulse.has(m.id):
		r = r.grow(sin(float(_pulse[m.id]) / PULSE_TIME * PI) * 6.0)
	var mt := Sprites.first(["machine_%s_%s" % [m.type, m.state_name().to_lower()], "machine_" + m.type] as Array[String])
	if mt != null:
		Sprites.draw_fit(self, mt, r)
	else:
		draw_style_box(sb, r)
	if board != null and StatusBoard.is_monitored(m):
		var lc: Color = WallMonitor.COL[board.machine_light(m)]
		draw_arc(r.position + Vector2(r.size.x - 20, 20), 11.0, 0.0, TAU, 24, lc, 5.0)
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
		var c := bot_pos(m)
		var mood := 1 if (board != null and StatusBoard.is_monitored(m) and board.machine_light(m) == StatusBoard.Light.RED) else 0
		var hit := 0.0
		for b in _bubbles:
			if b["id"] == m.id:
				hit = clampf(float(b["left"]) / 2.0, 0.0, 1.0)
		BotView.draw(self, c, m.bot.color, mood, _time, hit, sin(_time * 3.0) if m.state == Machine.State.WORKING else 0.0, m.bot.name.to_lower())
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


## The QA desk is upstairs: on the floor it is a hatch in the line that products go up through.
func hatch_rect(m: Machine) -> Rect2:
	var c := area.position + Vector2(m.pos.x * area.size.x, m.pos.y * area.size.y)
	return Rect2(c - Vector2(70, 26), Vector2(140, 52))


func _draw_hatch(m: Machine) -> void:
	var r := hatch_rect(m)
	if _bounce > 0.0:
		r.position.y += sin(_bounce / 0.3 * PI) * 5.0
	if not Sprites.draw_named(self, "desk_hatch", r):
		draw_rect(r, Color(0.05, 0.05, 0.07))
		for i in 5:
			var x := r.position.x + 14.0 + float(i) * 28.0
			draw_line(Vector2(x, r.position.y + 4), Vector2(x - 12, r.end.y - 4), Color(0.9, 0.75, 0.2, 0.7), 4.0)
		draw_rect(r, Color(0.9, 0.75, 0.2), false, 3.0)
	_text("▲ QA DESK", r.position + Vector2(r.size.x + 8, 34), 18, Color(0.85, 0.87, 0.92), 120.0)


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
