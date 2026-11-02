class_name ScreenSwitch
extends Control
## Two stacked screens: the QA office (top) and the factory floor (below it).
## Which one shows, and the vertical slide between them, follow the sim's worker location;
## the slide lasts the worker's trip (transition_seconds). Buttons call the sim's public API.

const BACK_H := 100.0

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
var floor_label: Label
var offset: float = 0.0  # 0 = office on screen, 1 = floor on screen


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	office_page = _page(UiTheme.BG)
	floor_page = _page(UiTheme.BG)
	monitor = Panel.new()
	monitor.mouse_filter = Control.MOUSE_FILTER_STOP
	monitor.add_theme_stylebox_override("panel", UiTheme.card())
	office_page.add_child(monitor)
	wall = WallMonitor.new()
	wall.tapped.connect(go_floor)
	wall.light_tapped.connect(radio_tap)
	monitor.add_child(wall)
	factory_btn = _button(monitor, "Go down", go_floor)
	factory_btn.add_theme_font_size_override("font_size", 24)
	UiTheme.style_button(factory_btn, "secondary", 24)
	UiTheme.add_icon(factory_btn, func(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void: UiTheme.draw_arrow(ci, c, r, 1, col), 24)
	back_btn = _button(floor_page, "Back to desk", go_office)
	UiTheme.style_button(back_btn, "secondary", 28)
	UiTheme.add_icon(back_btn, func(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void: UiTheme.draw_arrow(ci, c, r, -1, col), 28)
	worst_btn = _button(floor_page, "Fix worst first", func() -> void: worst_first())
	UiTheme.style_button(worst_btn, "primary", 28)
	UiTheme.add_icon(worst_btn, func(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void: UiTheme.draw_wrench(ci, c, r, col), 28)
	floor_label = Label.new()
	floor_label.text = "FACTORY FLOOR"
	floor_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floor_label.add_theme_font_size_override("font_size", 22)
	floor_label.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	floor_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	floor_page.add_child(floor_label)
	queue_label = Label.new()
	queue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	queue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	queue_label.add_theme_font_size_override("font_size", 20)
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
	return Rect2(UiTheme.px(10.0), hud_top, size.x - UiTheme.px(20.0), WallMonitor.card_height())


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
	factory_btn.size = Vector2(UiTheme.px(110.0), UiTheme.px(44.0))
	factory_btn.position = Vector2(m.size.x - factory_btn.size.x - UiTheme.px(8.0), UiTheme.px(8.0))
	var gap := 12.0
	var bw := size.x - 24.0 - gap  # bottom grid 1 : 1.2
	back_btn.size = Vector2(bw / 2.2, BACK_H)
	back_btn.position = Vector2(12.0, size.y - BACK_H - 12.0)
	worst_btn.size = Vector2(bw * 1.2 / 2.2, BACK_H)
	worst_btn.position = Vector2(size.x - worst_btn.size.x - 12.0, size.y - BACK_H - 12.0)
	floor_label.size = Vector2(300, 34)
	floor_label.position = Vector2(UiTheme.px(16.0), hud_top - 4.0)
	queue_label.size = Vector2(250, 34)
	queue_label.position = Vector2(size.x - 250 - UiTheme.px(16.0), hud_top - 4.0)
	_place()


func go_floor() -> void:
	if active and factory != null:
		factory.go_to_floor()


## Tap on a monitor light with the radio: clear that jam from the desk, else head to the floor.
func radio_tap(machine_id: String) -> void:
	if active and factory != null and factory.radio_fix(machine_id) != Factory.RadioResult.FIXED:
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
	var full := q >= cap
	var warn := float(q) / float(cap) >= 0.75
	queue_label.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.CRIT_BG if full else (UiTheme.WARN_BG if warn else UiTheme.SURFACE), UiTheme.CRIT if full else (UiTheme.WARN if warn else UiTheme.LINE), 22.0, 1.0))
	queue_label.add_theme_color_override("font_color", UiTheme.CRIT_TEXT if full else (UiTheme.WARN if warn else UiTheme.TEXT))
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
