class_name Home
extends Control
## Home screen between careers (docs/UI_STYLE.md): bests, Start career, Daily, perks, footer links.
## Reads Meta only; emits signals for navigation.

signal start_pressed
signal stats_pressed
signal daily_pressed
signal tutorial_pressed
signal settings_pressed
signal perk_bought(id: String)
signal tier_picked(tier: int)

const SCENE := preload("res://scenes/ui/home.tscn")
const PERKS_SHOWN := 4

# Layout lives in scenes/ui/home.tscn; this script fills in state and wires signals.
@onready var start_btn: Button = %StartBtn
@onready var stats_btn: Button = %StatsBtn
@onready var daily_btn: Button = %DailyBtn
@onready var tutorial_btn: Button = %TutorialBtn  # "How to play"
@onready var perks_btn: Button = %PerksBtn  # "All perks"
@onready var cog: Button = %Cog
@onready var tier_box: HBoxContainer = %TierBox  # one button per unlocked tier (hidden at tier 1)
@onready var perks_box: GridContainer = %PerksBox  # the 4 shown perk cards
@onready var perks_overlay: Control = %PerksOverlay
@onready var how_overlay: Control = %HowOverlay
@onready var replay_btn: Button = %ReplayBtn
@onready var _tiles: HBoxContainer = %Tiles
@onready var _all_grid: GridContainer = %AllGrid
@onready var _hat: Control = %Hat
var _daily_pill: Dictionary = {"text": "Play", "gold": true}


static func create() -> Home:
	return SCENE.instantiate() as Home


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	%Title.add_theme_font_override("font", UiKit.bold())
	%PerksTitle.add_theme_font_override("font", UiKit.bold())
	UiTheme.style_button(cog, "icon")
	cog.pressed.connect(settings_pressed.emit)
	cog.draw.connect(func() -> void: UiTheme.draw_cog(cog, cog.size * 0.5, cog.size.y * 0.27))
	_hat.draw.connect(_draw_hat)
	UiTheme.style_button(start_btn, "primary", 34)
	start_btn.pressed.connect(start_pressed.emit)
	UiTheme.style_button(daily_btn, "secondary", 24)
	for st in ["normal", "hover", "pressed", "focus"]:
		(daily_btn.get_theme_stylebox(st) as StyleBoxFlat).content_margin_left = UiTheme.px(14.0)
	daily_btn.pressed.connect(daily_pressed.emit)
	daily_btn.draw.connect(_draw_daily_pill)
	for b: Button in [perks_btn, stats_btn, tutorial_btn]:
		UiTheme.style_button(b, "secondary", 22)
	perks_btn.pressed.connect(func() -> void: perks_overlay.visible = true)
	stats_btn.pressed.connect(stats_pressed.emit)
	tutorial_btn.pressed.connect(func() -> void: how_overlay.visible = true)
	for b: Button in [%PerksClose, %HowClose]:
		UiTheme.style_button(b, "secondary", 28)
		b.pressed.connect(func() -> void: _close_overlays())
	UiTheme.style_button(replay_btn, "secondary", 26)
	replay_btn.pressed.connect(func() -> void:
		how_overlay.visible = false
		tutorial_pressed.emit())
	visible = false


func _close_overlays() -> void:
	perks_overlay.visible = false
	how_overlay.visible = false


func _draw_hat() -> void:
	var c := Vector2(_hat.size.x * 0.5, _hat.size.y)
	var r := UiTheme.px(12.0)
	var pts := PackedVector2Array()
	var base := c.y - UiTheme.px(3.0)
	for i in 13:
		var t := float(i) / 12.0
		pts.append(Vector2(c.x - r + r * 2.0 * t, base - sin(PI * t) * r * 0.9))
	_hat.draw_colored_polygon(pts, UiTheme.GOLD)
	_hat.draw_rect(Rect2(c + Vector2(-r * 1.5, -UiTheme.px(3.0)), Vector2(r * 3.0, UiTheme.px(3.0))), UiTheme.GOLD)


## Hides the controls of switched-off systems (features come from the mode, see Meta.features).
func _apply_features(m: Meta) -> void:
	var perks := m.feature("perks")
	%PerksTitle.visible = perks
	perks_box.visible = perks
	perks_btn.visible = perks
	daily_btn.visible = m.feature("daily")


func setup(m: Meta, today: String = "", quota: int = 0) -> void:
	_apply_features(m)
	_clear(_tiles)
	_tile("Best", str(m.best_for(m.picked_tier)), UiTheme.TEXT)
	_tile("Careers", str(m.stats.careers_finished), UiTheme.TEXT)
	if m.feature("commendations"):
		_tile("Commendations", str(m.balance()), UiTheme.GOLD)
	var quota_txt := " · day-1 quota %d" % quota if quota > 0 else ""
	start_btn.text = "Start career\nTier %d%s" % [m.picked_tier, quota_txt] if m.feature("tiers") else "Start career" + ("\nDay-1 quota %d" % quota if quota > 0 else "")
	_daily(m, today)
	_clear(tier_box)
	tier_box.visible = m.tier > 1 and m.feature("tiers")
	for t in range(1, m.tier + 1):
		var tb := UiKit.button(tier_box, "Tier %d · best %d" % [t, m.best_for(t)], "secondary", 46.0, 20)
		tb.name = "tier_%d" % t
		if t == m.picked_tier:
			tb.disabled = true
			var sb := UiTheme.box(UiTheme.SURFACE, UiTheme.ACCENT, 20.0, 2.0)
			tb.add_theme_stylebox_override("disabled", sb)
			tb.add_theme_color_override("font_disabled_color", UiTheme.ACCENT)
		tb.pressed.connect(tier_picked.emit.bind(t))
	_clear(perks_box)
	_clear(_all_grid)
	var perks := _ordered_perks(m)
	for i in perks.size():
		if i < PERKS_SHOWN:
			_perk_card(perks_box, m, perks[i], "perk_")
		_perk_card(_all_grid, m, perks[i], "allperk_")


func _daily(m: Meta, today: String) -> void:
	if today == "":
		daily_btn.text = "Daily shift"
		return
	var played := m.daily_played(today)
	var sub := ("Best %d days" % m.daily_best_for(today)) if played else "New seed every day"
	if m.daily_streak > 0:
		sub += " · streak %d" % m.daily_streak
	daily_btn.text = "Daily shift · %s\n%s" % [today, sub]
	_daily_pill = {"text": "Done" if played else "Play", "gold": not played}


func _draw_daily_pill() -> void:
	var f := daily_btn.get_theme_font("font")
	var fs := 22
	var w := f.get_string_size(_daily_pill["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + UiTheme.px(28.0)
	var h := UiTheme.px(30.0)
	var r := Rect2(daily_btn.size.x - w - UiTheme.px(12.0), (daily_btn.size.y - h) * 0.5, w, h)
	var gold: bool = _daily_pill["gold"]
	UiTheme.draw_pill(daily_btn, r, UiTheme.GOLD if gold else UiTheme.TRACK)
	daily_btn.draw_string(f, Vector2(r.position.x + UiTheme.px(14.0), r.position.y + h * 0.5 + fs * 0.35), _daily_pill["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.GOLD_TEXT if gold else UiTheme.TEXT_DIM)


## Affordable unowned first, then other unowned by cost, then owned.
func _ordered_perks(m: Meta) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Variant in Meta.load_perks().get("perks", []):
		out.append(p as Dictionary)
	var rank := func(d: Dictionary) -> int:
		if m.owns(String(d["id"])):
			return 2
		return 0 if m.balance() >= int(d["cost"]) else 1
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ra: int = rank.call(a)
		var rb: int = rank.call(b)
		return ra < rb or (ra == rb and int(a["cost"]) < int(b["cost"])))
	return out


func _perk_card(grid: GridContainer, m: Meta, d: Dictionary, prefix: String) -> void:
	var id := String(d["id"])
	var owned := m.owns(id)
	var afford := m.balance() >= int(d["cost"])
	var v := UiKit.card(grid, UiTheme.card() if (owned or afford) else UiTheme.box(UiTheme.SURFACE_DIM, UiTheme.LINE), 6.0, 10.0)
	v.get_parent().custom_minimum_size.x = 1.0
	var dim := UiTheme.TEXT if afford and not owned else UiTheme.TEXT_DIM
	v.add_child(UiKit.label(String(d["name"]), 24, dim, true, HORIZONTAL_ALIGNMENT_LEFT, false))
	var desc := UiKit.label(String(d["desc"]).split(". ")[0].trim_suffix("."), 18, UiTheme.TEXT_FAINT, false, HORIZONTAL_ALIGNMENT_LEFT)
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc.max_lines_visible = 2
	desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(desc)
	var b := UiKit.button(v, "Owned" if owned else (("Buy · %d" if afford else "Locked · %d") % int(d["cost"])), "gold" if afford and not owned else "secondary", 44.0, 22)
	b.name = prefix + id
	b.disabled = owned or not afford
	b.pressed.connect(perk_bought.emit.bind(id))


func _tile(label: String, value: String, col: Color) -> void:
	var v := UiKit.card(_tiles, null, 0.0, 4.0)
	v.get_parent().custom_minimum_size.x = 1.0
	v.add_child(UiKit.label(value, 32, col, true, HORIZONTAL_ALIGNMENT_CENTER, false))
	v.add_child(UiKit.label(label, 18, UiTheme.TEXT_DIM, false, HORIZONTAL_ALIGNMENT_CENTER, false))


func _clear(n: Control) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()
