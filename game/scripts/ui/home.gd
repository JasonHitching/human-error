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

const HOW_TO := "Swipe right: ship good ones. Swipe left: reject defects.\nBots call for help. Go down to fix, come back up to inspect."
const PERKS_SHOWN := 4

var start_btn: Button
var stats_btn: Button
var daily_btn: Button
var tutorial_btn: Button  # "How to play"
var perks_btn: Button  # "All perks"
var cog: Button
var tier_box: HBoxContainer  # one button per unlocked tier (hidden at tier 1)
var perks_box: GridContainer  # the 4 shown perk cards
var perks_overlay: Control
var how_overlay: Control
var replay_btn: Button
var _col: VBoxContainer
var _tiles: HBoxContainer
var _all_grid: GridContainer
var _daily_pill: Dictionary = {"text": "Play", "gold": true}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scr := UiKit.screen(self, true)
	(scr[0] as Control).visible = true
	_col = scr[1]
	_col.alignment = BoxContainer.ALIGNMENT_BEGIN
	_col.add_theme_constant_override("separation", roundi(UiTheme.px(6.0)))
	_build_header()
	_tiles = UiKit.hbox(_col, 8.0)
	tier_box = UiKit.hbox(_col, 8.0)
	start_btn = UiKit.button(_col, "Start career", "primary", 66.0, 34)
	start_btn.custom_minimum_size.x = 240.0
	start_btn.pressed.connect(start_pressed.emit)
	daily_btn = UiKit.button(_col, "Daily", "secondary", 50.0, 24)
	daily_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	for st in ["normal", "hover", "pressed", "focus"]:
		(daily_btn.get_theme_stylebox(st) as StyleBoxFlat).content_margin_left = UiTheme.px(14.0)
	daily_btn.pressed.connect(daily_pressed.emit)
	daily_btn.draw.connect(_draw_daily_pill)
	_col.add_child(UiKit.label("Perks", 26, UiTheme.TEXT, true, HORIZONTAL_ALIGNMENT_LEFT, false))
	perks_box = _grid(_col)
	var foot := UiKit.hbox(_col, 8.0)
	perks_btn = UiKit.button(foot, "All perks", "secondary", 46.0, 22)
	perks_btn.pressed.connect(func() -> void: perks_overlay.visible = true)
	stats_btn = UiKit.button(foot, "Stats", "secondary", 46.0, 22)
	stats_btn.pressed.connect(stats_pressed.emit)
	tutorial_btn = UiKit.button(foot, "How to play", "secondary", 46.0, 22)
	tutorial_btn.pressed.connect(func() -> void: how_overlay.visible = true)
	_build_perks_overlay()
	_build_how_overlay()
	visible = false


func _build_header() -> void:
	var top := UiKit.hbox(_col, 0.0)
	var pad := Control.new()  # balances the cog so the title stays centred
	pad.custom_minimum_size.x = UiTheme.min_target() + 4.0
	top.add_child(pad)
	var title := UiKit.label("HUMAN ERROR", 52, UiTheme.TEXT, true, HORIZONTAL_ALIGNMENT_CENTER, false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	cog = Button.new()
	cog.focus_mode = Control.FOCUS_NONE
	cog.custom_minimum_size = Vector2.ONE * (UiTheme.min_target() + 4.0)
	cog.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiTheme.style_button(cog, "icon")
	cog.pressed.connect(settings_pressed.emit)
	cog.draw.connect(func() -> void: UiTheme.draw_cog(cog, cog.size * 0.5, cog.size.y * 0.27))
	top.add_child(cog)
	var hat := Control.new()
	hat.custom_minimum_size = Vector2(0, UiTheme.px(14.0))
	hat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hat.draw.connect(func() -> void:
		var c := Vector2(hat.size.x * 0.5, hat.size.y)
		var r := UiTheme.px(12.0)
		var pts := PackedVector2Array()
		var base := c.y - UiTheme.px(3.0)
		for i in 13:
			var t := float(i) / 12.0
			pts.append(Vector2(c.x - r + r * 2.0 * t, base - sin(PI * t) * r * 0.9))
		hat.draw_colored_polygon(pts, UiTheme.GOLD)
		hat.draw_rect(Rect2(c + Vector2(-r * 1.5, -UiTheme.px(3.0)), Vector2(r * 3.0, UiTheme.px(3.0))), UiTheme.GOLD))
	_col.add_child(hat)
	_col.add_child(UiKit.label("Your coworkers are AI. They're terrible.", 20, UiTheme.TEXT_DIM))


func _grid(parent: Control) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_theme_constant_override("h_separation", roundi(UiTheme.px(8.0)))
	g.add_theme_constant_override("v_separation", roundi(UiTheme.px(8.0)))
	parent.add_child(g)
	return g


func _build_perks_overlay() -> void:
	var s := UiKit.screen(self, true)
	perks_overlay = s[0]
	perks_overlay.z_index = 5
	(s[1] as Control).add_child(UiKit.label("All perks", 40, UiTheme.TEXT, true))
	_all_grid = _grid(s[1])
	UiKit.button(s[1], "Close", "secondary", 56.0, 28).pressed.connect(func() -> void: perks_overlay.visible = false)


func _build_how_overlay() -> void:
	var s := UiKit.screen(self, true)
	how_overlay = s[0]
	how_overlay.z_index = 5
	var col: VBoxContainer = s[1]
	col.add_child(UiKit.label("How to play", 40, UiTheme.TEXT, true))
	var c := UiKit.card(col, null, 8.0, 16.0)
	c.add_child(UiKit.label(HOW_TO, 26, UiTheme.TEXT, false, HORIZONTAL_ALIGNMENT_LEFT))
	replay_btn = UiKit.button(col, "Replay tutorial", "secondary", 56.0, 26)
	replay_btn.pressed.connect(func() -> void:
		how_overlay.visible = false
		tutorial_pressed.emit())
	UiKit.button(col, "Close", "secondary", 56.0, 28).pressed.connect(func() -> void: how_overlay.visible = false)


func setup(m: Meta, today: String = "", quota: int = 0) -> void:
	_clear(_tiles)
	_tile("Best", str(m.best_for(m.picked_tier)), UiTheme.TEXT)
	_tile("Careers", str(m.stats.careers_finished), UiTheme.TEXT)
	_tile("Commendations", str(m.balance()), UiTheme.GOLD)
	start_btn.text = "Start career\nTier %d%s" % [m.picked_tier, " · day-1 quota %d" % quota if quota > 0 else ""]
	_daily(m, today)
	_clear(tier_box)
	tier_box.visible = m.tier > 1
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
