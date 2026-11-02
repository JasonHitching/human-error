class_name MachineInfo
extends PanelContainer
## Screen-space info panel for the selected machine (bottom of the floor area). Stays fixed while the world moves.

var _label := Label.new()


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UiTheme.box(UiTheme.SURFACE, UiTheme.LINE, 12.0, 1.0))
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", UiTheme.TEXT)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


## Place inside the floor area `fr` (screen coords): a strip FactoryView.PANEL_H tall at its bottom.
func place(fr: Rect2) -> void:
	size = Vector2(fr.size.x - 16.0, FactoryView.PANEL_H - 8.0)
	position = Vector2(fr.position.x + 8.0, fr.end.y - FactoryView.PANEL_H)


static func describe(m: Machine) -> String:
	var state := Machine.State.keys()[m.state] as String
	var s := "%s - %s, heat %d" % [FactoryView.friendly_name(m), state.capitalize(), roundi(m.heat)]
	if m.bot != null:
		s += "\nBot: " + m.bot.name
	return s


func show_machine(m: Machine) -> void:
	visible = m != null
	if m != null:
		_label.text = describe(m)
