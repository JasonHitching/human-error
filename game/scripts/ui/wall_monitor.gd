class_name WallMonitor
extends Control
## Office wall monitor card: "FACTORY FLOOR" header, one bot chip per machine (avatar, name, status),
## and a call-in line under the chips. A new RED alarm flashes the chip and shows that bot's call-in.
## Reads the sim via StatusBoard only. Tapping the card (or the Go down button) asks to go to the floor.

const FLASH_SECS := 2.0
const QUIET_SECS := 2.0
const COL := {  # still read by the floor view's machine lights (UI-3 restyles that)
	StatusBoard.Light.GREEN: Color(0.25, 0.8, 0.35),
	StatusBoard.Light.AMBER: Color(1.0, 0.75, 0.15),
	StatusBoard.Light.RED: Color(0.95, 0.25, 0.2),
}
const T_NAME := 24
const T_SMALL := 20

signal tapped
signal light_tapped(machine_id: String)  # only with radio: a tap on a light

var radio: bool = false

var board: StatusBoard
var call_text: String = ""
var call_color: Color = Color.WHITE
var flash_id: String = ""
var flash_left: float = 0.0
var quiet_left: float = 0.0  # "All quiet." cue time left (a calm window just began)
var _count: int = 0
var _font: Font = ThemeDB.fallback_font
var _time: float = 0.0


func setup(b: StatusBoard) -> void:
	board = b
	call_text = ""
	flash_id = ""
	flash_left = 0.0
	quiet_left = 0.0
	_count = 0
	queue_redraw()


## Card height (office layout uses it for the monitor rect).
static func card_height() -> float:
	return UiTheme.px(140.0)


func header_rect() -> Rect2:
	var pad := UiTheme.px(8.0)
	return Rect2(pad, pad, size.x - pad * 2.0, UiTheme.px(44.0))


func call_rect() -> Rect2:
	var pad := UiTheme.px(8.0)
	var y := header_rect().end.y + UiTheme.px(6.0) + UiTheme.px(52.0) + UiTheme.px(4.0)
	return Rect2(pad + 4.0, y, size.x - pad * 2.0 - 8.0, UiTheme.px(18.0))


## Chip rects, in line order, across the card (name kept for the checks: one rect per monitored machine).
func light_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if board == null:
		return out
	var n := board.monitored().size()
	var pad := UiTheme.px(8.0)
	var gap := UiTheme.px(6.0)
	var w := (size.x - pad * 2.0 - gap * float(maxi(0, n - 1))) / float(maxi(1, n))
	var y := header_rect().end.y + gap
	for i in n:
		out.append(Rect2(pad + float(i) * (w + gap), y, w, UiTheme.px(52.0)))
	return out


## Status line for a machine chip: [text, UiTheme colour, severity 0 ok / 1 warn / 2 crit].
func status_of(m: Machine) -> Array:
	match board.machine_light(m):
		StatusBoard.Light.RED:
			var t := "JAMMED"
			if m.state == Machine.State.OVERHEATED:
				t = "OVERHEAT"
			elif m.state == Machine.State.CLOGGED:
				t = "CLOGGED"
			elif m.misrouted:
				t = "MISROUTED"
			elif m.wrong_recipe:
				t = "BAD RECIPE"
			return [t, UiTheme.CRIT_TEXT, 2]
		StatusBoard.Light.AMBER:
			if m.state == Machine.State.BLOCKED:
				return ["BLOCKED", UiTheme.WARN, 1]
			if m.overclocked and m.heat < board.amber_heat:
				return ["FAST", UiTheme.WARN, 1]
			return ["HOT %d%%" % roundi(m.heat), UiTheme.WARN, 1]
	return ["OK", UiTheme.TEXT_FAINT, 0]


## Poll the board for new RED alarms; call once per frame (or after sim steps).
func poll() -> void:
	if board == null:
		return
	var alarms := board.new_alarms()
	var calm := board.calm_began()
	if alarms.is_empty() and calm:
		quiet_left = QUIET_SECS
		call_text = ""
	if not alarms.is_empty():
		var m: Machine = alarms.back()
		flash_id = m.id
		flash_left = FLASH_SECS
		if m.bot != null and not m.bot.call_in.is_empty():
			call_text = "%s: \"%s\"" % [m.bot.name, m.bot.call_in[_count % m.bot.call_in.size()]]
			call_color = m.bot.color
		else:
			call_text = "%s needs you!" % m.id
			call_color = Color.WHITE
		_count += 1
		quiet_left = 0.0


func _process(d: float) -> void:
	_time += d
	if flash_left > 0.0:
		flash_left = maxf(0.0, flash_left - d)
	quiet_left = maxf(0.0, quiet_left - d)
	if is_visible_in_tree():
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if radio and board != null:
			var ms := board.monitored()
			var rects := light_rects()
			for i in ms.size():
				if rects[i].grow(rects[i].size.x * 0.4).has_point((event as InputEventMouseButton).position):
					light_tapped.emit(ms[i].id)
					return
		tapped.emit()


func _draw() -> void:
	if board == null:
		return
	draw_string(_font, Vector2(header_rect().position.x + 4.0, header_rect().get_center().y + 8.0), "FACTORY FLOOR", HORIZONTAL_ALIGNMENT_LEFT, -1, T_SMALL, UiTheme.TEXT_DIM)
	var ms := board.monitored()
	var rects := light_rects()
	for i in ms.size():
		_draw_chip(ms[i], rects[i])
	var cr := call_rect()
	if quiet_left > 0.0:
		draw_string(_font, cr.position + Vector2(0, cr.size.y - 6.0), "All quiet.", HORIZONTAL_ALIGNMENT_LEFT, cr.size.x, T_SMALL, UiTheme.TEXT_DIM)
	elif call_text != "":
		draw_string(_font, cr.position + Vector2(0, cr.size.y - 6.0), call_text, HORIZONTAL_ALIGNMENT_LEFT, cr.size.x, T_SMALL, call_color)


func _draw_chip(m: Machine, r: Rect2) -> void:
	var st := status_of(m)
	var sev: int = st[2]
	var border := UiTheme.LINE
	var bg := UiTheme.SURFACE_2
	var bw := 1.0
	if sev == 2:
		bg = UiTheme.CRIT_BG
		border = UiTheme.CRIT
		bw = 2.0
	elif sev == 1:
		bg = UiTheme.WARN_BG
		border = UiTheme.WARN
		bw = 2.0
	if m.id == flash_id and flash_left > 0.0 and fmod(_time, 0.3) < 0.15:
		border = Color.WHITE
	draw_style_box(UiTheme.box(bg, border, 12.0, bw), r)
	var name := m.bot.name if m.bot != null else m.id
	var bc := m.bot.color if m.bot != null else UiTheme.TEXT_DIM
	var d := minf(UiTheme.px(34.0), r.size.y * 0.42)
	var wide := r.size.x >= 150.0
	var ac: Vector2
	var tx: float
	var tw: float
	if wide:
		d = UiTheme.px(28.0)
		ac = Vector2(r.position.x + UiTheme.px(6.0) + d * 0.5, r.get_center().y)
		tx = ac.x + d * 0.5 + UiTheme.px(5.0)
		tw = r.end.x - tx - 2.0
	else:
		ac = Vector2(r.get_center().x, r.position.y + UiTheme.px(5.0) + d * 0.5)
		tx = r.position.x + 2.0
		tw = r.size.x - 4.0
	draw_circle(ac, d * 0.5, bc)
	draw_string(_font, ac + Vector2(-d * 0.5, 8.0), name.substr(0, 1).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, d, T_NAME, UiTheme.ACCENT_TEXT)
	var align := HORIZONTAL_ALIGNMENT_LEFT if wide else HORIZONTAL_ALIGNMENT_CENTER
	var ny := r.get_center().y - 2.0 if wide else r.position.y + d + UiTheme.px(5.0) + 22.0
	draw_string(_font, Vector2(tx, ny), name, align, tw, T_NAME if wide else T_SMALL, UiTheme.TEXT)
	draw_string(_font, Vector2(tx, ny + 22.0), String(st[0]), align, tw, T_SMALL, st[1])
