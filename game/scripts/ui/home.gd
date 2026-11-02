class_name Home
extends Control
## Home screen between careers: commendation balance, bests, Start career, Stats, Perks slot (#86).
## Reads Meta only; emits signals for navigation.

signal start_pressed
signal stats_pressed

var start_btn: Button
var stats_btn: Button
var perks_box: VBoxContainer  # filled by the perks issue (#86)
var _info: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12, 1.0)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	center.add_child(box)
	var title := _label("HUMAN ERROR", 44)
	box.add_child(title)
	_info = _label("", 30)
	box.add_child(_info)
	var perks_title := _label("Perks", 28)
	box.add_child(perks_title)
	perks_box = VBoxContainer.new()
	perks_box.custom_minimum_size = Vector2(440, 60)
	box.add_child(perks_box)
	start_btn = _button("Start career", 40, Vector2(440, 140))
	start_btn.pressed.connect(start_pressed.emit)
	box.add_child(start_btn)
	stats_btn = _button("Stats", 24, Vector2(440, 80))
	stats_btn.pressed.connect(stats_pressed.emit)
	box.add_child(stats_btn)
	visible = false


func setup(m: Meta) -> void:
	_info.text = "Commendations: %d\nBest: %d days\nCareers: %d\nTier %d" % [
		m.balance(), m.stats.best_days, m.stats.careers_finished, m.tier]


func _label(text: String, font: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(440, 0)
	l.add_theme_font_size_override("font_size", font)
	return l


func _button(text: String, font: int, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font)
	return b
