class_name RunEndScreen
extends ResultScreen
## Run end (fired / automated). Layout: scenes/ui/run_end_screen.tscn; this fills text and draws the stamp/bar/avatar.

signal again_pressed
signal replay_pressed
signal home_pressed
signal stats_pressed

const SCENE := preload("res://scenes/ui/run_end_screen.tscn")

@onready var again_btn: Button = %AgainBtn
@onready var replay_btn: Button = %ReplayBtn
@onready var home_btn: Button = %HomeBtn
@onready var stats_btn: Button = %StatsBtn
@onready var _stamp: Control = %Stamp
@onready var _days: Label = %DaysLabel
@onready var _quote_card: PanelContainer = %QuoteCard
@onready var _quote_tag: Label = %QuoteTag
@onready var _quote: Label = %QuoteLabel
@onready var _break_card: PanelContainer = %BreakdownCard
@onready var _miss: Label = %MissLabel
@onready var _score: Label = %ScoreLabel
@onready var _rows: VBoxContainer = %Rows
@onready var _divider: ColorRect = %Divider
@onready var _worst_row: HBoxContainer = %WorstRow
@onready var _worst_tag: Label = %WorstTag
@onready var _avatar: Control = %Avatar
@onready var _worst: Label = %WorstLabel
@onready var _best_card: PanelContainer = %BestCard
@onready var _bar: Control = %Bar
@onready var _teaser: Label = %TeaserLabel
@onready var _pill: PanelContainer = %AwardPill
@onready var _pill_label: Label = %PillLabel
@onready var _award_lines: VBoxContainer = %AwardLines

var _title := "FIRED"
var _bar_frac := 0.0
var _avatar_who := ""
var _avatar_col := UiTheme.TEXT_DIM


static func create() -> RunEndScreen:
	return SCENE.instantiate() as RunEndScreen


func _build() -> void:
	visible = false
	style_label(_days, UiTheme.TEXT, true)
	style_card(_quote_card, UiTheme.box(UiTheme.SURFACE_2, UiTheme.LINE), 12.0)
	style_label(_quote_tag, UiTheme.TEXT_FAINT, true)
	style_label(_quote, UiTheme.TEXT)
	style_card(_break_card)
	style_label(_miss, UiTheme.CRIT_TEXT, true)
	style_label(_score, UiTheme.TEXT_DIM)
	_divider.color = UiTheme.LINE
	style_label(_worst_tag, UiTheme.TEXT_DIM)
	_worst_tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	style_label(_worst, UiTheme.TEXT, true)
	style_card(_best_card)
	style_label(_teaser, UiTheme.TEXT)
	_pill.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.GOLD, Color(0, 0, 0, 0), 20.0))
	_pill_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	style_label(_pill_label, UiTheme.GOLD_TEXT, true)
	UiTheme.style_button(again_btn, "primary", 36)
	UiTheme.style_button(replay_btn, "secondary", 26)
	style_link(home_btn)
	style_link(stats_btn)
	_stamp.custom_minimum_size.y = UiTheme.px(50.0)
	_stamp.draw.connect(func() -> void: _draw_stamp(_stamp, _title, UiTheme.CRIT if _title.begins_with("FIRED") else UiTheme.ACCENT))
	_bar.draw.connect(func() -> void: UiTheme.draw_bar(_bar, Rect2(Vector2.ZERO, _bar.size), _bar_frac, UiTheme.GOLD))
	_avatar.draw.connect(_draw_avatar)
	again_btn.pressed.connect(again_pressed.emit)
	replay_btn.pressed.connect(replay_pressed.emit)
	home_btn.pressed.connect(home_pressed.emit)
	stats_btn.pressed.connect(stats_pressed.emit)


## info (optional): score, target, best, colors {bot: Color}, award_total. breakdown = RunEnd.breakdown lines joined by newlines.
func show_run_end(title: String, days: int, line: String, breakdown: String, teaser: String, awards: String, info: Dictionary) -> void:
	_title = title
	_stamp.queue_redraw()
	_days.text = "You lasted %d days" % days
	_quote.text = line
	var lines := breakdown.split("\n", false)
	_break_card.visible = not lines.is_empty()
	_miss.visible = false
	_score.visible = false
	clear(_rows)
	var worst := ""
	for l in lines:
		if l.begins_with("Missed by"):
			_miss.text = l
			_miss.visible = true
			if info.has("score"):
				_score.text = "%d / %d" % [info["score"], info["target"]]
				_score.visible = true
		elif l.begins_with("Biggest problem: "):
			worst = l.trim_prefix("Biggest problem: ")
		else:
			var kv := l.split(": ", true, 1)
			UiKit.row(_rows, kv[0], kv[1] if kv.size() > 1 else "")
	_divider.visible = worst != ""
	_worst_row.visible = worst != ""
	if worst != "":
		_avatar_who = worst.split(",")[0]
		_avatar_col = (info.get("colors", {}) as Dictionary).get(_avatar_who, UiTheme.TEXT_DIM)
		_worst.text = worst
		_avatar.queue_redraw()
	var best := int(info.get("best", 0))
	_bar_frac = float(days) / float(maxi(best, days))
	_bar.queue_redraw()
	_teaser.text = teaser
	clear(_award_lines)
	_pill.visible = awards != ""
	if awards != "":
		_pill_label.text = "+%d commendations" % int(info.get("award_total", 0))
		var al := awards.split("\n", false)
		for i in range(1, al.size() - 1):
			_award_lines.add_child(UiKit.label(al[i], 20, UiTheme.TEXT_DIM, false, HORIZONTAL_ALIGNMENT_LEFT))
	visible = true


func _draw_avatar() -> void:
	var ctr := _avatar.size * 0.5
	_avatar.draw_circle(ctr, _avatar.size.x * 0.5, _avatar_col)
	var f := UiKit.bold()
	var fs := roundi(_avatar.size.y * 0.55)
	var w := f.get_string_size(_avatar_who.left(1), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_avatar.draw_string(f, Vector2(ctr.x - w * 0.5, ctr.y + fs * 0.35), _avatar_who.left(1), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.BG)


static func _draw_stamp(ci: Control, text: String, col: Color) -> void:
	var f := UiKit.bold()
	var fs := 40
	var sz := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var r := Rect2(-sz.x * 0.5 - UiTheme.px(16.0), -ci.size.y * 0.5, sz.x + UiTheme.px(32.0), ci.size.y)
	ci.draw_set_transform(ci.size * 0.5, -0.07)
	ci.draw_style_box(UiTheme.box(Color(col, 0.08), col, 10.0, 3.0), r)
	ci.draw_string(f, Vector2(-sz.x * 0.5, fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	ci.draw_set_transform(Vector2.ZERO, 0.0)
