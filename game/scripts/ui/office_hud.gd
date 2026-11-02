class_name OfficeHud
extends Control
## Office screen UI (scenes/ui/office_hud.tscn): wall monitor, queue row, spec chip, toast strip and
## action rows are Controls laid out by containers in the scene. This script styles and updates them.
## The product pad is an empty Control; QaDeskView draws the product in its rect.

signal go_down_pressed

var _slot_key: String = ""
var _queue_key: String = ""
var _spec_new: bool = false
var _spec_key: String = ""

@onready var column: VBoxContainer = %Column
@onready var monitor: Control = %Monitor
@onready var wall: WallMonitor = %Wall
@onready var go_down: Button = %GoDownButton
@onready var desk: Control = %Desk
@onready var queue_row: Control = %QueueRow
@onready var slots: HBoxContainer = %Slots
@onready var queue_label: Label = %QueueLabel
@onready var streak_pill: PanelContainer = %StreakPill
@onready var streak_label: Label = %StreakLabel
@onready var spec_chip: PanelContainer = %SpecChip
@onready var spec_label: Label = %SpecLabel
@onready var spec_icon: Control = %SpecIcon
@onready var rule_label: Label = %RuleLabel
@onready var pad: Control = %Pad
@onready var toast: Control = %Toast
@onready var swipes: Control = %Swipes
@onready var hint_panel: PanelContainer = %HintPanel
@onready var hint_label: Label = %HintLabel
@onready var reject_btn: Button = %RejectButton
@onready var scan_btn: Button = %ScanButton
@onready var ship_btn: Button = %ShipButton
@onready var flip_btn: Button = %FlipButton
@onready var lamp_btn: Button = %LampButton


func _ready() -> void:
	UiTheme.style_button(go_down, "secondary", 24)
	UiTheme.add_icon(go_down, func(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void: UiTheme.draw_arrow(ci, c, r, 1, col), 24)
	go_down.pressed.connect(go_down_pressed.emit)
	monitor.add_theme_stylebox_override("panel", UiTheme.card())
	UiTheme.style_button(reject_btn, "danger", 30)
	UiTheme.add_icon(reject_btn, func(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void: UiTheme.draw_x(ci, c, r, col, 5.0), 30)
	UiTheme.style_button(ship_btn, "primary", 30)
	UiTheme.add_icon(ship_btn, func(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void: UiTheme.draw_tick(ci, c, r, col, 5.0), 30)
	UiTheme.style_button(scan_btn, "secondary", 30)
	UiTheme.add_icon(scan_btn, func(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void: UiTheme.draw_magnifier(ci, c, r, col), 30)
	UiTheme.style_button(flip_btn, "secondary", 24)
	UiTheme.style_button(lamp_btn, "secondary", 24)
	streak_pill.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.SURFACE, UiTheme.ACCENT, 14.0, 1.5))
	hint_panel.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.SURFACE_2, UiTheme.LINE, 12.0))
	streak_label.add_theme_color_override("font_color", UiTheme.ACCENT)
	spec_label.add_theme_color_override("font_color", UiTheme.TEXT)
	rule_label.add_theme_color_override("font_color", UiTheme.TEXT)
	hint_label.add_theme_color_override("font_color", UiTheme.TEXT)
	spec_icon.draw.connect(func() -> void:
		var s := minf(spec_icon.size.x, spec_icon.size.y)
		ProductArt.draw(spec_icon, {"defect": "", "decoy": "", "bot": ""}, spec_icon.size * 0.5, Vector2(s, s * 1.1)))
	_style_spec(false)


## A rect of a scene control, in this screen's own space (stays put while the office page slides).
func rect_of(c: Control) -> Rect2:
	return Rect2(c.global_position - global_position, c.size)


## Force the containers to lay out now (they normally sort next frame); parents before children.
func relayout() -> void:
	_sort_tree(self)


func _sort_tree(n: Node) -> void:
	if n is Container:
		n.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for c in n.get_children():
		_sort_tree(c)


## Desk controls (queue, spec, buttons) only show while a shift is playing; overlays cover the rest.
func set_playing(on: bool) -> void:
	if desk.visible == on:
		return
	desk.visible = on
	if on:
		relayout()


## Per-frame state from the desk: queue, streak, spec chip, hint.
func refresh(f: Factory, streak: int, pop: float, spec_new: bool, caption: String, hint: String, base_rule: String) -> void:
	var q := f.qa_queue().size()
	var cap := maxi(1, f.qa_capacity)
	var col := UiTheme.TEXT_DIM
	if q >= cap:
		col = UiTheme.CRIT
	elif float(q) / float(cap) >= 0.75:
		col = UiTheme.WARN
	var text := "Desk queue %d / %d" % [q, cap]
	var shelf_slots: int = f.shelf_slots
	if shelf_slots > 0:
		var n: int = f.qa_shelf().size()
		text += " · shelf %d / %d" % [n, shelf_slots]
		if n >= shelf_slots:
			col = UiTheme.CRIT
		elif n > 0 and col == UiTheme.TEXT_DIM:
			col = UiTheme.WARN
	queue_label.text = text
	queue_label.add_theme_color_override("font_color", col)
	_update_slots(q, cap, col)
	streak_label.text = "Streak %d" % streak
	streak_pill.pivot_offset = streak_pill.size * 0.5
	streak_pill.scale = Vector2(pop, pop)
	if spec_new != _spec_new:
		_spec_new = spec_new
		_style_spec(spec_new)
	spec_label.text = "NEW SPEC" if spec_new else "SPEC"
	rule_label.text = caption if caption != "" else base_rule
	hint_panel.visible = hint != ""
	swipes.visible = hint == ""
	hint_label.text = hint


func _style_spec(new: bool) -> void:
	spec_chip.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.WARN_BG if new else UiTheme.SURFACE, UiTheme.WARN if new else UiTheme.LINE, 14.0, 2.0 if new else 1.0))
	spec_label.add_theme_color_override("font_color", UiTheme.WARN if new else UiTheme.TEXT_DIM)


## Slot pills: one per desk slot, filled for queued items.
func _update_slots(q: int, cap: int, col: Color) -> void:
	var key := "%d/%d/%s" % [q, cap, col.to_html()]
	if key == _slot_key:
		return
	_slot_key = key
	while slots.get_child_count() > cap:
		var extra := slots.get_child(slots.get_child_count() - 1)
		slots.remove_child(extra)
		extra.queue_free()
	while slots.get_child_count() < cap:
		var p := Panel.new()
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.custom_minimum_size = Vector2(0, UiTheme.px(12.0))
		p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slots.add_child(p)
	var on := UiTheme.box(col, Color(0, 0, 0, 0), 6.0)
	var off := UiTheme.box(UiTheme.TRACK, Color(0, 0, 0, 0), 6.0)
	for i in cap:
		(slots.get_child(i) as Panel).add_theme_stylebox_override("panel", on if i < q else off)
