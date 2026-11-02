class_name TopBar
extends Control
## Play-screen top bar: day + timer, quota bar, strike pips, settings cog. Drawn in code.

signal settings_pressed

const H_MOCK := 62.0

var cog: Button
var day: int = 1
var seconds_left: int = 0
var score: int = 0
var target: int = 1
var strikes: int = 0
var max_strikes: int = 2
var complaints: int = 0
var penalty: int = 3


static func height() -> float:
	return UiTheme.px(H_MOCK)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	cog = Button.new()
	cog.focus_mode = Control.FOCUS_NONE
	UiTheme.style_button(cog, "icon")
	cog.pressed.connect(settings_pressed.emit)
	add_child(cog)
	cog.draw.connect(func() -> void: UiTheme.draw_cog(cog, cog.size * 0.5, cog.size.y * 0.27))
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	var s := UiTheme.min_target() + 4.0
	cog.size = Vector2(s, s)
	cog.position = Vector2(size.x - s - UiTheme.px(8.0), (height() - s) * 0.5)


func set_state(d: int, left: int, sc: int, tgt: int, st: int, max_st: int, comp: int, pen: int) -> void:
	var changed := d != day or left != seconds_left or sc != score or tgt != target or st != strikes or comp != complaints
	day = d
	seconds_left = left
	score = sc
	target = maxi(1, tgt)
	strikes = st
	max_strikes = max_st
	complaints = comp
	penalty = pen
	if changed:
		queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var pad := UiTheme.px(16.0)
	var h := height()
	draw_rect(Rect2(0, 0, size.x, h), UiTheme.BG)
	draw_string(font, Vector2(pad, h * 0.34), "DAY %d" % day, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UiTheme.TEXT_DIM)
	draw_string(font, Vector2(pad, h * 0.84), "%d:%02d" % [seconds_left / 60, seconds_left % 60], HORIZONTAL_ALIGNMENT_LEFT, -1, 44, UiTheme.TEXT)
	var qx := UiTheme.px(110.0)
	var qw := size.x - qx - UiTheme.px(52.0) - cog.size.x
	draw_string(font, Vector2(qx, h * 0.34), "Quota", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UiTheme.TEXT_DIM)
	var txt := "%d / %d" % [score, target]
	draw_string(font, Vector2(qx, h * 0.34), txt, HORIZONTAL_ALIGNMENT_RIGHT, qw, 20, UiTheme.TEXT)
	UiTheme.draw_bar(self, Rect2(qx, h * 0.46, qw, UiTheme.px(8.0)), float(score) / float(target))
	if complaints > 0:
		draw_string(font, Vector2(qx, h * 0.46 + UiTheme.px(8.0) + 22.0), "Complaints %d (-%d)" % [complaints, complaints * penalty], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UiTheme.CRIT_TEXT)
	var pr := UiTheme.px(6.0)
	var px0 := cog.position.x - UiTheme.px(10.0) - pr
	for i in max_strikes:
		UiTheme.draw_pip(self, Vector2(px0 - float(max_strikes - 1 - i) * (pr * 2.0 + UiTheme.px(5.0)), h * 0.5), pr, i < strikes)
