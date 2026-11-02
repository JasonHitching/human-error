class_name ResultCards
extends RefCounted
## Builds the day-review and run-end (fired) screen contents into a column (docs/UI_STYLE.md).


static func _quote(col: Control, line: String) -> void:
	var c := UiKit.card(col, UiTheme.box(UiTheme.SURFACE_2, UiTheme.LINE), 4.0, 12.0)
	c.add_child(UiKit.label("FOREMAN", 18, UiTheme.TEXT_FAINT, true, HORIZONTAL_ALIGNMENT_LEFT))
	c.add_child(UiKit.label(line, 24, UiTheme.TEXT, false, HORIZONTAL_ALIGNMENT_LEFT))


## Day review: hit/miss card, Foreman, extras, then training offers (cards) and Continue.
static func review(col: Control, res: Dictionary, line: String, offers: Array[Dictionary], extra: String, notes: Array[String], on_offer: Callable, on_continue: Callable) -> void:
	UiKit.clear(col)
	var hit := bool(res["hit"])
	var tint := UiTheme.ACCENT if hit else UiTheme.WARN
	var head := UiKit.hbox(col, 8.0)
	var t := UiKit.label("Day over", 40, UiTheme.TEXT, true, HORIZONTAL_ALIGNMENT_LEFT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UiKit.label("HIT" if hit else "MISS", 30, tint, true, HORIZONTAL_ALIGNMENT_RIGHT, false))
	var c := UiKit.card(col, UiTheme.card(not hit), 4.0, 14.0)
	c.add_child(UiKit.label("%d / %d" % [res["shipped"], res["target"]], 56, tint, true))
	c.add_child(UiKit.label("score / quota", 18, UiTheme.TEXT_DIM))
	UiKit.divider(c)
	UiKit.row(c, "Caught", str(res["caught"]))
	UiKit.row(c, "Complaints", str(res["complaints"]), UiTheme.CRIT_TEXT if int(res["complaints"]) > 0 else UiTheme.TEXT)
	UiKit.row(c, "Wasted", str(res["wasted"]))
	if bool(res.get("probation", false)):
		UiKit.row(c, "Probation", "no strike")
	else:
		UiKit.row(c, "Strikes", str(res["strikes"]), UiTheme.CRIT_TEXT if int(res["strikes"]) > 0 else UiTheme.TEXT)
	for n in notes:
		c.add_child(UiKit.label(n, 20, UiTheme.TEXT_DIM, false, HORIZONTAL_ALIGNMENT_LEFT))
	_quote(col, line)
	if extra != "":
		var e := UiKit.card(col, UiTheme.box(UiTheme.SURFACE_DIM, UiTheme.LINE), 4.0, 12.0)
		e.add_child(UiKit.label(extra, 20, UiTheme.TEXT_DIM, false, HORIZONTAL_ALIGNMENT_LEFT))
	var picking := int(res["points"]) > 0 and not offers.is_empty()
	if picking:
		col.add_child(UiKit.label("Training points: %d. Pick one" % res["points"], 26, UiTheme.TEXT, true, HORIZONTAL_ALIGNMENT_LEFT))
		for i in offers.size():
			var parts := String(offers[i]["text"]).split(": ", true, 1)
			var b := UiKit.button(col, "%s\n%s" % [parts[0], parts[1]] if parts.size() > 1 else parts[0], "secondary", 56.0, 24)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			for st in ["normal", "hover", "pressed", "focus", "disabled"]:
				(b.get_theme_stylebox(st) as StyleBoxFlat).content_margin_left = UiTheme.px(14.0)
			b.name = "offer_%d" % i
			b.pressed.connect(on_offer.bind(i))
	UiKit.button(col, "Continue", "secondary" if picking else "primary", 66.0, 34).pressed.connect(on_continue)


## Run end. info: score, target, best, colors {bot: Color}, award_total. breakdown is RunEnd.breakdown joined by newlines.
static func fired(col: Control, title: String, days: int, line: String, breakdown: String, teaser: String, awards: String, info: Dictionary, on_again: Callable, on_replay: Callable, on_home: Callable, on_stats: Callable) -> Button:
	UiKit.clear(col)
	var win := not title.begins_with("FIRED")
	var stamp := Control.new()
	stamp.custom_minimum_size = Vector2(0, UiTheme.px(50.0))
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.draw.connect(func() -> void: _draw_stamp(stamp, title, UiTheme.ACCENT if win else UiTheme.CRIT))
	col.add_child(stamp)
	col.add_child(UiKit.label("You lasted %d days" % days, 36, UiTheme.TEXT, true))
	_quote(col, line)
	var lines := breakdown.split("\n", false)
	if not lines.is_empty():
		var c := UiKit.card(col, null, 4.0, 14.0)
		var rows: Array[String] = []
		var worst := ""
		for l in lines:
			if l.begins_with("Missed by"):
				c.add_child(UiKit.label(l, 40, UiTheme.CRIT_TEXT, true, HORIZONTAL_ALIGNMENT_LEFT))
				if info.has("score"):
					c.add_child(UiKit.label("%d / %d" % [info["score"], info["target"]], 20, UiTheme.TEXT_DIM, false, HORIZONTAL_ALIGNMENT_LEFT))
			elif l.begins_with("Biggest problem: "):
				worst = l.trim_prefix("Biggest problem: ")
			else:
				rows.append(l)
		for r in rows:
			var kv := r.split(": ", true, 1)
			UiKit.row(c, kv[0], kv[1] if kv.size() > 1 else "")
		if worst != "":
			UiKit.divider(c)
			var who := worst.split(",")[0]
			var h := UiKit.hbox(c, 8.0)
			h.add_child(UiKit.label("Biggest problem", 20, UiTheme.TEXT_DIM, false, HORIZONTAL_ALIGNMENT_LEFT, false))
			var cols: Dictionary = info.get("colors", {})
			UiKit.avatar(h, who, cols.get(who, UiTheme.TEXT_DIM), 24.0)
			var wl := UiKit.label(worst, 22, UiTheme.TEXT, true, HORIZONTAL_ALIGNMENT_LEFT)
			wl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(wl)
	var best := int(info.get("best", 0))
	var bc := UiKit.card(col, null, 6.0, 14.0)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, UiTheme.px(8.0))
	bar.draw.connect(func() -> void: UiTheme.draw_bar(bar, Rect2(Vector2.ZERO, bar.size), float(days) / float(maxi(best, days)), UiTheme.GOLD))
	bc.add_child(bar)
	bc.add_child(UiKit.label(teaser, 22, UiTheme.TEXT, false, HORIZONTAL_ALIGNMENT_LEFT))
	if awards != "":
		var al := awards.split("\n", false)
		var total := int(info.get("award_total", 0))
		var pill := PanelContainer.new()
		pill.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.GOLD, Color(0, 0, 0, 0), 20.0))
		pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var pl := UiKit.label("+%d commendations" % total, 24, UiTheme.GOLD_TEXT, true)
		pl.autowrap_mode = TextServer.AUTOWRAP_OFF
		pill.add_child(pl)
		bc.add_child(pill)
		for i in range(1, al.size() - 1):
			bc.add_child(UiKit.label(al[i], 20, UiTheme.TEXT_DIM, false, HORIZONTAL_ALIGNMENT_LEFT))
	var again := UiKit.button(col, "One more career", "primary", 78.0, 36)
	again.pressed.connect(on_again)
	UiKit.button(col, "Replay this seed", "secondary", 48.0, 26).pressed.connect(on_replay)
	var links := UiKit.hbox(col, 8.0)
	UiKit.link(links, "Home").pressed.connect(on_home)
	UiKit.link(links, "Stats").pressed.connect(on_stats)
	return again


static func _draw_stamp(ci: Control, text: String, col: Color) -> void:
	var f := UiKit.bold()
	var fs := 40
	var sz := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var r := Rect2(-sz.x * 0.5 - UiTheme.px(16.0), -ci.size.y * 0.5, sz.x + UiTheme.px(32.0), ci.size.y)
	ci.draw_set_transform(ci.size * 0.5, -0.07)
	ci.draw_style_box(UiTheme.box(Color(col, 0.08), col, 10.0, 3.0), r)
	ci.draw_string(f, Vector2(-sz.x * 0.5, fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	ci.draw_set_transform(Vector2.ZERO, 0.0)
