class_name TopBar
extends Control
## Play-screen top bar: day + timer, quota bar, strike pips, settings cog.
## Layout lives in scenes/ui/top_bar.tscn; this script only fills in state and draws bar/pips.

signal settings_pressed

const SCENE := preload("res://scenes/ui/top_bar.tscn")

var day: int = 1
var seconds_left: int = 0
var score: int = 0
var target: int = 1
var strikes: int = 0
var max_strikes: int = 2
var complaints: int = 0
var penalty: int = 3

@onready var cog: Button = %Cog
@onready var _day: Label = %DayLabel
@onready var _time: Label = %TimeLabel
@onready var _quota: Label = %QuotaValue
@onready var _bar: Control = %QuotaBar
@onready var _complaints: Label = %ComplaintsLabel
@onready var _pips: Control = %Pips


static func create() -> TopBar:
	return SCENE.instantiate() as TopBar


## Scene default height (mock 62 px).
static func height() -> float:
	return UiTheme.px(62.0)


func _ready() -> void:
	UiTheme.style_button(cog, "icon")
	cog.custom_minimum_size = Vector2.ONE * (UiTheme.min_target() + 4.0)
	cog.pressed.connect(settings_pressed.emit)
	cog.draw.connect(func() -> void: UiTheme.draw_cog(cog, cog.size * 0.5, cog.size.y * 0.27))
	_bar.draw.connect(func() -> void: UiTheme.draw_bar(_bar, Rect2(Vector2.ZERO, _bar.size), float(score) / float(target)))
	_pips.draw.connect(_draw_pips)
	_refresh()


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
	if changed and is_node_ready():
		_refresh()


func _refresh() -> void:
	_day.text = "DAY %d" % day
	_time.text = "%d:%02d" % [seconds_left / 60, seconds_left % 60]
	_quota.text = "%d / %d" % [score, target]
	_complaints.visible = complaints > 0
	_complaints.text = "Complaints %d (-%d)" % [complaints, complaints * penalty]
	var pr := UiTheme.px(6.0)
	_pips.custom_minimum_size.x = float(max_strikes) * (pr * 2.0 + UiTheme.px(5.0))
	_bar.queue_redraw()
	_pips.queue_redraw()


func _draw_pips() -> void:
	var pr := UiTheme.px(6.0)
	for i in max_strikes:
		UiTheme.draw_pip(_pips, Vector2(pr + float(i) * (pr * 2.0 + UiTheme.px(5.0)), _pips.size.y * 0.5), pr, i < strikes)
