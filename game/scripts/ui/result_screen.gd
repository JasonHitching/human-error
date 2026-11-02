class_name ResultScreen
extends ColorRect
## Base for full-screen result overlays (run end, day review, night report, stats).
## Layout lives in the .tscn (Scroll > Margin > Col); this only centres short content,
## applies UiTheme styling and exposes small helpers.

@onready var _scroll: ScrollContainer = %Scroll
@onready var _margin: MarginContainer = %Margin
@onready var _col: VBoxContainer = %Col


func _ready() -> void:
	color = UiTheme.BG
	_scroll.resized.connect(func() -> void: _margin.custom_minimum_size = Vector2(0, _scroll.size.y))
	_build()


## Override: style nodes and connect signals.
func _build() -> void:
	pass


## Card style on a PanelContainer; pad in mock px.
static func style_card(p: PanelContainer, style: StyleBoxFlat = null, pad_mock: float = 14.0) -> void:
	var sb := style if style != null else UiTheme.card()
	sb.set_content_margin_all(UiTheme.px(pad_mock))
	p.add_theme_stylebox_override("panel", sb)


static func style_label(l: Label, col: Color, is_bold: bool = false) -> void:
	l.add_theme_color_override("font_color", col)
	if is_bold:
		l.add_theme_font_override("font", UiKit.bold())


static func style_link(b: Button) -> void:
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(s, empty)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, UiTheme.TEXT_DIM)
	b.add_theme_font_size_override("font_size", 26)


func clear(n: Node) -> void:
	UiKit.clear(n)
