class_name Tutorial
extends Control
## Day-1 guided tutorial: a dismissible caption plus a pulse on the target control.
## Steps are data (data/tutorial.json). It only READS the sim through a snapshot dict, so it can't
## change a run. Steps fire once, in order. Finished or skipped = `finished` emitted (Meta.tutorial_done).

signal finished(skipped: bool)

const PATH := "res://data/tutorial.json"
const CAPTION_H := 190.0

var steps: Array = []
var active: bool = false
var index: int = 0
var shown: bool = false  # the current step's caption is up
var fired: Array[String] = []  # step ids in the order they fired
var targets: Dictionary = {}  # target name -> Rect2 (set by main each frame)
var caption_rect: Rect2 = Rect2()
var skip_btn: Button
var _label: Label
var _panel: PanelContainer
var _t: float = 0.0


static func load_steps(path: String = PATH) -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary and (parsed as Dictionary).get("steps") is Array:
		return (parsed as Dictionary)["steps"]
	return []


## Read-only view of the sim for step triggers (public API only).
static func snapshot(f: Factory, offers: bool = false) -> Dictionary:
	var fault := false
	for m: Machine in f.machines:
		if m.state == Machine.State.OVERHEATED or m.state == Machine.State.JAMMED or m.state == Machine.State.CLOGGED:
			fault = true
	return {
		"fault": fault, "crew_busy": f.crew_busy,
		"desk_item": not f.qa_queue().is_empty(), "inspected": not f.last_inspected().is_empty(),
		"offers": offers,
	}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 30
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.gui_input.connect(_on_caption_input)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(box)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 24)
	_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_label)
	skip_btn = Button.new()
	skip_btn.text = "Skip tutorial"
	skip_btn.custom_minimum_size = Vector2(200, 80)
	skip_btn.add_theme_font_size_override("font_size", 22)
	skip_btn.pressed.connect(skip)
	box.add_child(skip_btn)
	visible = false


func start(p_steps: Array = []) -> void:
	steps = p_steps if not p_steps.is_empty() else load_steps()
	index = 0
	shown = false
	fired.clear()
	active = not steps.is_empty()
	_refresh()


func stop() -> void:
	active = false
	shown = false
	_refresh()


func current() -> Dictionary:
	return steps[index] if active and index < steps.size() else {}


## Advance from a snapshot. Fires the current step's caption when its trigger holds, and
## completes it when its done-key holds. Later steps wait for earlier ones.
func observe(snap: Dictionary) -> void:
	if not active:
		return
	var st := current()
	if st.is_empty():
		_finish(false)
		return
	if not shown:
		if snap.get(st.get("trigger", ""), false) == true:
			shown = true
			fired.append(String(st["id"]))
	elif snap.get(st.get("done", "dismiss"), false) == true:
		_advance()
	_refresh()


func dismiss() -> void:
	if active and shown:
		_advance()
		_refresh()


func skip() -> void:
	if active:
		_finish(true)


func _advance() -> void:
	shown = false
	index += 1
	if index >= steps.size():
		_finish(false)


func _finish(skipped: bool) -> void:
	active = false
	shown = false
	_refresh()
	finished.emit(skipped)


func _on_caption_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		dismiss()


func target_rect() -> Rect2:
	var st := current()
	return targets.get(String(st.get("target", "")), Rect2()) if not st.is_empty() else Rect2()


func _refresh() -> void:
	visible = active and shown
	if _label != null and visible:
		_label.text = String(current().get("text", ""))
		_layout()
	queue_redraw()


func _layout() -> void:
	var w := minf(size.x - 40.0, 680.0)
	caption_rect = Rect2((size.x - w) * 0.5, 120.0, w, CAPTION_H)
	_panel.position = caption_rect.position
	_panel.size = caption_rect.size


func _process(delta: float) -> void:
	if visible:
		_t += delta
		_layout()
		queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var r := target_rect()
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	var a := 0.45 + 0.4 * sin(_t * 5.0)
	draw_rect(r.grow(4.0), Color(1.0, 0.85, 0.2, a), false, 6.0)
