class_name ClockIn
extends ResultScreen
## Clock-in screen: Foreman briefing, one line from a bot on today's crew, "Clock in" button. No timer.
## Layout: scenes/ui/clock_in.tscn.

signal clock_in_pressed

const SCENE := preload("res://scenes/ui/clock_in.tscn")

@onready var _title: Label = %TitleLabel
@onready var _foreman_card: PanelContainer = %ForemanCard
@onready var _foreman_tag: Label = %ForemanTag
@onready var body: Label = %BodyLabel
@onready var _bot_card: PanelContainer = %BotCard
@onready var _bot_tag: Label = %BotTag
@onready var _bot_line: Label = %BotLine
@onready var clock_in_btn: Button = %ClockInBtn


static func create() -> ClockIn:
	return SCENE.instantiate() as ClockIn


func _build() -> void:
	visible = false
	style_label(_title, UiTheme.TEXT, true)
	style_card(_foreman_card, UiTheme.box(UiTheme.SURFACE_2, UiTheme.LINE), 12.0)
	style_card(_bot_card, UiTheme.box(UiTheme.SURFACE_DIM, UiTheme.LINE), 12.0)
	style_label(_foreman_tag, UiTheme.TEXT_FAINT, true)
	style_label(body, UiTheme.TEXT)
	style_label(_bot_tag, UiTheme.TEXT_FAINT, true)
	style_label(_bot_line, UiTheme.TEXT)
	UiTheme.style_button(clock_in_btn, "primary", 30)
	clock_in_btn.pressed.connect(clock_in_pressed.emit)


func show_clock_in(text: String, bot: String, bot_line: String) -> void:
	body.text = text
	_bot_card.visible = bot != "" and bot_line != ""
	_bot_tag.text = bot.to_upper()
	_bot_line.text = bot_line
