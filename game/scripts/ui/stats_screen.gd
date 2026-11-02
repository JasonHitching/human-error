class_name StatsScreen
extends ResultScreen
## Run stats overlay. Layout: scenes/ui/stats_screen.tscn; rows are filled from RunStats.summary().

signal closed

const SCENE := preload("res://scenes/ui/stats_screen.tscn")

@onready var _title: Label = %TitleLabel
@onready var _card: PanelContainer = %Card
@onready var _rows: VBoxContainer = %Rows
@onready var close_btn: Button = %CloseBtn


static func create() -> StatsScreen:
	return SCENE.instantiate() as StatsScreen


func _build() -> void:
	style_label(_title, UiTheme.TEXT, true)
	style_card(_card)
	UiTheme.style_button(close_btn, "secondary", 26)
	close_btn.pressed.connect(close)
	visible = false


## text: RunStats.summary() (first line is the heading).
func show_stats(text: String) -> void:
	clear(_rows)
	for l in text.split("\n", false).slice(1):
		var kv := l.split(": ", true, 1)
		UiKit.row(_rows, kv[0], kv[1] if kv.size() > 1 else "")
	visible = true


func close() -> void:
	visible = false
	closed.emit()
