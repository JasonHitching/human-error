class_name NightReport
extends ResultScreen
## Foreman's night-shift report overlay: 3-5 lines, commendations earned, Collect / Skip.
## Both buttons close it and bank the commendations (nothing is lost by skipping).
## Layout: scenes/ui/night_report.tscn.

signal collected

const SCENE := preload("res://scenes/ui/night_report.tscn")

@onready var collect_btn: Button = %CollectBtn
@onready var skip_btn: Button = %SkipBtn
@onready var _title: Label = %TitleLabel
@onready var _text: Label = %BodyLabel


static func create() -> NightReport:
	return SCENE.instantiate() as NightReport


func _build() -> void:
	color = Color(UiTheme.BG, 0.96)
	_style_title()
	UiTheme.style_button(collect_btn, "primary", 36)
	UiTheme.style_button(skip_btn, "secondary", 22)
	collect_btn.pressed.connect(_done)
	skip_btn.pressed.connect(_done)
	visible = false


func _style_title() -> void:
	style_label(_title, UiTheme.TEXT, true)
	style_label(_text, UiTheme.TEXT)


func show_report(report: Dictionary) -> void:
	var lines: Array[String] = []
	for l: Variant in report.get("lines", []):
		lines.append(str(l))
	lines.append("")
	lines.append("Commendations earned: +%d" % int(report.get("commendations", 0)))
	_text.text = "\n".join(lines)
	visible = true


func _done() -> void:
	visible = false
	collected.emit()
