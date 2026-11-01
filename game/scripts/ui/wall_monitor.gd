class_name WallMonitor
extends Control
## Office wall monitor: one traffic light per machine with its bot's name underneath.
## A new RED alarm flashes the light and shows a call-in line from that bot (newest wins).
## Reads the sim via StatusBoard only. Tapping anywhere on it asks to go to the floor.

const FLASH_SECS := 2.0
const QUIET_SECS := 2.0
const COL := {
	StatusBoard.Light.GREEN: Color(0.25, 0.8, 0.35),
	StatusBoard.Light.AMBER: Color(1.0, 0.75, 0.15),
	StatusBoard.Light.RED: Color(0.95, 0.25, 0.2),
}

signal tapped

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


## Light centres, in line order, laid out across the monitor.
func light_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if board == null:
		return out
	var n := board.monitored().size()
	var slot := size.x / float(maxi(1, n))
	var d := minf(slot * 0.55, size.y * 0.32)
	for i in n:
		out.append(Rect2(Vector2(slot * (i + 0.5) - d * 0.5, 18.0), Vector2(d, d)))
	return out


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
		tapped.emit()


func _draw() -> void:
	if board == null:
		return
	Sprites.draw_fit(self, Sprites.tex("monitor"), Rect2(Vector2.ZERO, size))
	var ms := board.monitored()
	var rects := light_rects()
	for i in ms.size():
		var m := ms[i]
		var r := rects[i]
		var light := board.machine_light(m)
		var col: Color = COL[light]
		if m.id == flash_id and flash_left > 0.0 and fmod(_time, 0.3) < 0.15:
			col = Color.WHITE
		draw_circle(r.get_center(), r.size.x * 0.5, col)
		draw_arc(r.get_center(), r.size.x * 0.5, 0.0, TAU, 32, Color(0, 0, 0, 0.5), 3.0)
		var name := m.bot.name if m.bot != null else m.id
		var bc := m.bot.color if m.bot != null else Color(0.85, 0.87, 0.92)
		draw_string(_font, Vector2(r.position.x - 20, r.end.y + 30), name, HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 40, 24, bc)
	if quiet_left > 0.0:
		draw_string(_font, Vector2(16, size.y - 100), "All quiet.", HORIZONTAL_ALIGNMENT_LEFT, size.x - 32, 26, Color(0.6, 0.9, 0.7))
	elif call_text != "":
		draw_string(_font, Vector2(16, size.y - 100), call_text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 32, 26, call_color)
