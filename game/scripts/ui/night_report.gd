class_name NightReport
extends Control
## Foreman's night-shift report overlay: 3-5 lines, commendations earned, Collect / Skip.
## Both buttons close it and bank the commendations (nothing is lost by skipping).

signal collected

var collect_btn: Button
var skip_btn: Button
var _text: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.09, 0.96)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	center.add_child(box)
	var title := Label.new()
	title.text = "NIGHT SHIFT REPORT"
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_text = Label.new()
	_text.add_theme_font_size_override("font_size", 24)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(440, 0)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_text)
	collect_btn = _button("Collect", 36, Vector2(440, 120))
	collect_btn.pressed.connect(_done)
	box.add_child(collect_btn)
	skip_btn = _button("Skip", 22, Vector2(200, 80))
	skip_btn.pressed.connect(_done)
	box.add_child(skip_btn)
	visible = false


func _button(t: String, size_px: int, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_size_override("font_size", size_px)
	b.custom_minimum_size = min_size
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return b


func show_report(report: Dictionary) -> void:
	var lines: Array[String] = []
	for l: Variant in report.get("lines", []):
		lines.append(str(l))
	lines.append("")
	lines.append("Commendations earned: +%d" % int(report.get("commendations", 0)))
	_text.text = "\n".join(lines)
	visible = true


func _done() -> void:
	visible = false
	collected.emit()
