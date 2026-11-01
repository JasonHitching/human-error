class_name Hud
extends Control
## Top bar, flash text, seed label and end-of-shift overlay. Built in code.

signal restart_pressed
signal replay_pressed

var _top: Label
var _flash: Label
var _seed: Label
var _overlay: Control
var _result: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_top = _label(26, HORIZONTAL_ALIGNMENT_CENTER)
	_top.position = Vector2(0, 10)
	_flash = _label(26, HORIZONTAL_ALIGNMENT_CENTER)
	_flash.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	_seed = _label(14, HORIZONTAL_ALIGNMENT_RIGHT)
	_seed.modulate = Color(1, 1, 1, 0.5)
	_build_overlay()
	resized.connect(_layout)
	_layout()


func _label(size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	add_child(l)
	return l


func _build_overlay() -> void:
	_overlay = ColorRect.new()
	(_overlay as ColorRect).color = Color(0, 0, 0, 0.8)
	_overlay.visible = false
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	center.add_child(box)
	_result = Label.new()
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result.add_theme_font_size_override("font_size", 40)
	box.add_child(_result)
	for spec: Array in [["Restart (new seed)", restart_pressed], ["Replay (same seed)", replay_pressed]]:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(420, 90)
		b.add_theme_font_size_override("font_size", 30)
		b.pressed.connect((spec[1] as Signal).emit)
		box.add_child(b)


func _layout() -> void:
	_top.size = Vector2(size.x, 80)
	_flash.size = Vector2(size.x, 40)
	_flash.position = Vector2(0, size.y - 110)
	_seed.size = Vector2(size.x - 8, 20)
	_seed.position = Vector2(0, size.y - 24)


func update(f: Factory, tick_rate: int, shift_ticks: int, best: int, seed_value: int) -> void:
	var left := maxf(0.0, float(shift_ticks - f.tick) / tick_rate)
	var crew := "Crew: idle"
	if f.crew_busy:
		crew = "Crew: %s %d%%" % [f.crew_target, roundi(f.crew_progress * 100.0)]
	_top.text = "Time %d:%02d   Shipped %d / %d   Best %d\n%s" % [int(left) / 60, int(left) % 60, f.shipped, f.target, best, crew]
	_seed.text = "seed %d" % seed_value


func set_flash(text: String) -> void:
	_flash.text = text


func show_end(shipped: int, target: int, best: int, new_best: bool) -> void:
	_result.text = "Shift over\nShipped %d / %d\nBest %d%s" % [shipped, target, best, "  NEW!" if new_best else ""]
	_overlay.visible = true


func hide_end() -> void:
	_overlay.visible = false
