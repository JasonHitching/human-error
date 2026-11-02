class_name UiKit
extends RefCounted
## Control builders on top of UiTheme for the menu-style screens (Home, run end, review, stats).

static var _bold: FontVariation


static func bold() -> Font:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = ThemeDB.fallback_font
		_bold.variation_embolden = 0.7
	return _bold


static func label(text: String, size: int, col: Color = UiTheme.TEXT, is_bold: bool = false, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER, wrap: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	if wrap:
		l.custom_minimum_size.x = 120.0  # keeps the first layout pass from wrapping per character
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if is_bold:
		l.add_theme_font_override("font", bold())
	return l


## Rounded card holding a VBox. Returns the VBox; the card is its parent.
static func card(parent: Control, style: StyleBoxFlat = null, sep_mock: float = 6.0, pad_mock: float = 12.0) -> VBoxContainer:
	var p := PanelContainer.new()
	var sb := style if style != null else UiTheme.card()
	sb.set_content_margin_all(UiTheme.px(pad_mock))
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", roundi(UiTheme.px(sep_mock)))
	p.add_child(v)
	return v


static func button(parent: Control, text: String, kind: String, h_mock: float, font: int = 28) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(0, UiTheme.px(h_mock))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_button(b, kind, font)
	parent.add_child(b)
	return b


## Borderless text link button (still >= 44 mock px tall).
static func link(parent: Control, text: String, font: int = 26) -> Button:
	var b := button(parent, text, "secondary", 46.0, font)
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(s, empty)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, UiTheme.TEXT_DIM)
	return b


static func hbox(parent: Control, sep_mock: float = 8.0) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", roundi(UiTheme.px(sep_mock)))
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(h)
	return h


static func vbox(parent: Control, sep_mock: float = 8.0) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", roundi(UiTheme.px(sep_mock)))
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(v)
	return v


## Full-screen overlay: dim backdrop + scrollable column with 16 mock px side padding. Returns [overlay, column].
static func screen(parent: Control, opaque: bool = false) -> Array:
	var o := ColorRect.new()
	o.color = UiTheme.BG if opaque else Color(UiTheme.BG, 0.96)
	o.visible = false
	parent.add_child(o)
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	o.add_child(sc)
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := MarginContainer.new()
	var pad := roundi(UiTheme.px(16.0))
	m.add_theme_constant_override("margin_left", pad)
	m.add_theme_constant_override("margin_right", pad)
	m.add_theme_constant_override("margin_top", pad)
	m.add_theme_constant_override("margin_bottom", pad)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(m)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", roundi(UiTheme.px(8.0)))
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	m.add_child(col)
	# fill the scroll viewport so ALIGNMENT_CENTER centres short content
	sc.resized.connect(func() -> void: m.custom_minimum_size = Vector2(0, sc.size.y))
	return [o, col]


## Bot avatar: colour circle with the initial.
static func avatar(parent: Control, who: String, col: Color, size_mock: float = 26.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2.ONE * UiTheme.px(size_mock)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		var ctr := c.size * 0.5
		c.draw_circle(ctr, c.size.x * 0.5, col)
		var f := bold()
		var fs := roundi(c.size.y * 0.55)
		var w := f.get_string_size(who.left(1), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		c.draw_string(f, Vector2(ctr.x - w * 0.5, ctr.y + fs * 0.35), who.left(1), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("14161B")))
	parent.add_child(c)
	return c


## key (left, dim) and value (right, bold) on one line.
static func row(parent: Control, key: String, value: String, val_col: Color = UiTheme.TEXT) -> void:
	var h := hbox(parent, 4.0)
	var k := label(key, 22, UiTheme.TEXT_DIM, false, HORIZONTAL_ALIGNMENT_LEFT, false)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(k)
	h.add_child(label(value, 22, val_col, true, HORIZONTAL_ALIGNMENT_RIGHT, false))


static func divider(parent: Control) -> void:
	var r := ColorRect.new()
	r.color = UiTheme.LINE
	r.custom_minimum_size = Vector2(0, 1)
	parent.add_child(r)


static func clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()
