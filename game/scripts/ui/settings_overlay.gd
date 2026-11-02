class_name SettingsOverlay
extends ColorRect
## Settings card behind the top-bar cog: Sound, Haptics, Back to home, Close.

signal sound_toggled
signal haptics_toggled
signal home_pressed

var sound_btn: Button
var haptics_btn: Button
var home_btn: Button
var close_btn: Button


func _ready() -> void:
	color = Color(0, 0, 0, 0.7)
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	var sb := UiTheme.box(UiTheme.SURFACE, UiTheme.LINE, 16.0)
	sb.set_content_margin_all(UiTheme.px(16.0))
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(UiTheme.px(8.0)))
	panel.add_child(box)
	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", UiTheme.TEXT)
	box.add_child(title)
	sound_btn = _btn(box, "secondary", sound_toggled.emit)
	haptics_btn = _btn(box, "secondary", haptics_toggled.emit)
	home_btn = _btn(box, "secondary", home_pressed.emit)
	home_btn.text = "Back to home"
	close_btn = _btn(box, "primary", close)
	close_btn.text = "Close"


func _btn(box: Control, kind: String, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(UiTheme.px(240.0), UiTheme.px(48.0))
	UiTheme.style_button(b, kind, 28)
	b.pressed.connect(cb)
	box.add_child(b)
	return b


func open(sound_on: bool, haptics_on: bool) -> void:
	refresh(sound_on, haptics_on)
	visible = true


func refresh(sound_on: bool, haptics_on: bool) -> void:
	sound_btn.text = "Sound: on" if sound_on else "Sound: off"
	haptics_btn.text = "Haptics: on" if haptics_on else "Haptics: off"


func close() -> void:
	visible = false
