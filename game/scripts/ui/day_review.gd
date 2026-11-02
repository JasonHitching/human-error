class_name DayReview
extends ResultScreen
## Day review: hit/miss card, Foreman, extras, training offers, Continue.
## Layout: scenes/ui/day_review.tscn; stat rows, notes and offer buttons are data-driven.

signal offer_chosen(index: int)
signal continue_pressed

const SCENE := preload("res://scenes/ui/day_review.tscn")

@onready var _title: Label = %TitleLabel
@onready var _result: Label = %ResultLabel
@onready var _score_card: PanelContainer = %ScoreCard
@onready var _score: Label = %ScoreLabel
@onready var _score_sub: Label = %ScoreSub
@onready var _rows: VBoxContainer = %Rows
@onready var _notes: VBoxContainer = %Notes
@onready var _quote_card: PanelContainer = %QuoteCard
@onready var _quote_tag: Label = %QuoteTag
@onready var _quote: Label = %QuoteLabel
@onready var _extra_card: PanelContainer = %ExtraCard
@onready var _extra: Label = %ExtraLabel
@onready var _pick: Label = %PickLabel
@onready var _offers: VBoxContainer = %Offers
@onready var continue_btn: Button = %ContinueBtn


static func create() -> DayReview:
	return SCENE.instantiate() as DayReview


func _build() -> void:
	visible = false
	style_label(_title, UiTheme.TEXT, true)
	style_label(_score_sub, UiTheme.TEXT_DIM)
	style_card(_quote_card, UiTheme.box(UiTheme.SURFACE_2, UiTheme.LINE), 12.0)
	style_card(_extra_card, UiTheme.box(UiTheme.SURFACE_DIM, UiTheme.LINE), 12.0)
	style_label(_quote_tag, UiTheme.TEXT_FAINT, true)
	style_label(_quote, UiTheme.TEXT)
	style_label(_extra, UiTheme.TEXT_DIM)
	style_label(_pick, UiTheme.TEXT, true)
	_result.autowrap_mode = TextServer.AUTOWRAP_OFF
	continue_btn.pressed.connect(continue_pressed.emit)


func show_review(res: Dictionary, line: String, offers: Array[Dictionary], extra: String, notes: Array[String]) -> void:
	var hit := bool(res["hit"])
	var tint := UiTheme.ACCENT if hit else UiTheme.WARN
	_result.text = "HIT" if hit else "MISS"
	style_label(_result, tint, true)
	style_card(_score_card, UiTheme.card(not hit))
	_score.text = "%d / %d" % [res["shipped"], res["target"]]
	style_label(_score, tint, true)
	clear(_rows)
	clear(_notes)
	UiKit.row(_rows, "Caught", str(res["caught"]))
	UiKit.row(_rows, "Complaints", str(res["complaints"]), UiTheme.CRIT_TEXT if int(res["complaints"]) > 0 else UiTheme.TEXT)
	UiKit.row(_rows, "Wasted", str(res["wasted"]))
	if bool(res.get("probation", false)):
		UiKit.row(_rows, "Probation", "no strike")
	else:
		UiKit.row(_rows, "Strikes", str(res["strikes"]), UiTheme.CRIT_TEXT if int(res["strikes"]) > 0 else UiTheme.TEXT)
	for n in notes:
		_notes.add_child(UiKit.label(n, 20, UiTheme.TEXT_DIM, false, HORIZONTAL_ALIGNMENT_LEFT))
	_quote.text = line
	_extra_card.visible = extra != ""
	_extra.text = extra
	var picking := int(res["points"]) > 0 and not offers.is_empty()
	_pick.visible = picking
	_pick.text = "Training points: %d. Pick one" % res["points"]
	clear(_offers)
	if picking:
		for i in offers.size():
			var parts := String(offers[i]["text"]).split(": ", true, 1)
			var b := UiKit.button(_offers, "%s\n%s" % [parts[0], parts[1]] if parts.size() > 1 else parts[0], "secondary", 56.0, 24)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			for st in ["normal", "hover", "pressed", "focus", "disabled"]:
				(b.get_theme_stylebox(st) as StyleBoxFlat).content_margin_left = UiTheme.px(14.0)
			b.name = "offer_%d" % i
			b.pressed.connect(offer_chosen.emit.bind(i))
	UiTheme.style_button(continue_btn, "secondary" if picking else "primary", 34)
	visible = true
