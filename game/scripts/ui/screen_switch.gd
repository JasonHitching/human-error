class_name ScreenSwitch
extends Control
## Two stacked screens: the QA office (top) and the factory floor (below it).
## Which one shows, and the vertical slide between them, follow the sim's worker location;
## the slide lasts the worker's trip (transition_seconds). Buttons call the sim's public API.

const MONITOR_FRAC := 0.25  # wall-monitor panel height, as a fraction of the screen
const BACK_H := 100.0
const COL_WARN := Color(1.0, 0.6, 0.15)
const COL_FULL := Color(0.95, 0.25, 0.2)

signal refused(why: String)

var factory: Factory
var active: bool = false  # navigation allowed (shift is playing)
var hud_top: float = 110.0
var office_page: ColorRect  # page holding the desk; slides up when going to the floor
var floor_page: ColorRect  # page holding the factory view; slides up from below
var monitor: Panel  # wall-monitor panel
var wall: WallMonitor  # lights + call-ins, inside the panel
var factory_btn: Button
var back_btn: Button
var worst_btn: Button
var queue_label: Label
var offset: float = 0.0  # 0 = office on screen, 1 = floor on screen


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	office_page = _page(Color(0.14, 0.15, 0.19))
	floor_page = _page(Color(0.1, 0.11, 0.14))
	monitor = Panel.new()
	monitor.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.1)
	sb.border_color = Color(0.45, 0.47, 0.55)
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(10)
	monitor.add_theme_stylebox_override("panel", sb)
	office_page.add_child(monitor)
	wall = WallMonitor.new()
	wall.tapped.connect(go_floor)
	monitor.add_child(wall)
	factory_btn = _button(monitor, "Factory", go_floor)
	back_btn = _button(floor_page, "Back to desk", go_office)
	worst_btn = _button(floor_page, "Worst first", func() -> void: worst_first())
	queue_label = Label.new()
	queue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	queue_label.add_theme_font_size_override("font_size", 26)
	floor_page.add_child(queue_label)
	resized.connect(layout)
	layout()


func _page(col: Color) -> ColorRect:
	var p := ColorRect.new()
	p.color = col
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	return p


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 30)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


## Office: wall-monitor panel at the top (below the HUD).
func monitor_rect() -> Rect2:
	return Rect2(8, hud_top, size.x - 16, size.y * MONITOR_FRAC)


## Office: the desk fills the rest of the screen.
func desk_rect() -> Rect2:
	var top := monitor_rect().end.y + 8.0
	return Rect2(0, top, size.x, size.y - top)


## Floor: the factory view, between the HUD and the back button.
func floor_rect() -> Rect2:
	return Rect2(0, hud_top, size.x, size.y - hud_top - BACK_H - 24.0)


func layout() -> void:
	if office_page == null:
		return
	office_page.size = size
	floor_page.size = size
	var m := monitor_rect()
	monitor.position = m.position
	monitor.size = m.size
	wall.position = Vector2.ZERO
	wall.size = m.size
	factory_btn.size = Vector2(minf(280.0, m.size.x * 0.5), 84)
	factory_btn.position = Vector2(m.size.x - factory_btn.size.x - 16, m.size.y - 84 - 16)
	back_btn.size = Vector2(size.x * 0.44, BACK_H)
	back_btn.position = Vector2(12.0, size.y - BACK_H - 12.0)
	worst_btn.size = Vector2(size.x * 0.44, BACK_H)
	worst_btn.position = Vector2(size.x - worst_btn.size.x - 12.0, size.y - BACK_H - 12.0)
	queue_label.size = Vector2(300, 36)
	queue_label.position = Vector2(size.x - 312, hud_top + 6.0)
	_place()


func go_floor() -> void:
	if active and factory != null:
		factory.go_to_floor()


func worst_first() -> void:
	if active and factory != null:
		factory.request_worst()


func go_office() -> void:
	if active and factory != null and not factory.go_to_office():
		refused.emit("Crew busy - finish the fix first")


## Follow the sim: slide offset from worker location + trip progress (alpha = 0..1 between ticks).
func sync(alpha: float) -> void:
	if factory == null:
		return
	var w := factory.worker
	match factory.worker_location():
		Worker.Location.OFFICE: offset = 0.0
		Worker.Location.FLOOR: offset = 1.0
		_:
			var trip := float(maxi(1, w.trip_ticks))
			var done := clampf((trip - float(w.ticks_left()) + alpha) / trip, 0.0, 1.0)
			offset = done if w.target == Worker.Location.FLOOR else 1.0 - done
	var q := factory.qa_queue().size()
	var cap := maxi(1, factory.qa_capacity)
	queue_label.text = "Desk queue %d/%d" % [q, cap]
	var col := Color(0.85, 0.87, 0.92)
	if q >= cap:
		col = COL_FULL
	elif float(q) / float(cap) >= 0.75:
		col = COL_WARN
	if q >= cap:  # full desk queue: the meter pulses red
		col = col.lerp(Color.WHITE, 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.01))
	queue_label.add_theme_color_override("font_color", col)
	_place()


## Add a view to a page underneath that page's buttons and labels.
func add_view(page: Control, view: Node) -> void:
	page.add_child(view)
	page.move_child(view, 0)


func _place() -> void:
	var e := -(cos(PI * offset) - 1.0) * 0.5  # sine ease-in-out
	office_page.position = Vector2(0, -e * size.y)
	floor_page.position = Vector2(0, (1.0 - e) * size.y)
	office_page.visible = e < 1.0
	floor_page.visible = e > 0.0
