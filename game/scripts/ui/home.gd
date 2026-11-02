class_name Home
extends Control
## Home screen between careers: commendation balance, bests, Start career, Stats, Perks slot (#86).
## Reads Meta only; emits signals for navigation.

signal start_pressed
signal stats_pressed
signal daily_pressed
signal tutorial_pressed
signal perk_bought(id: String)
signal tier_picked(tier: int)

var start_btn: Button
var stats_btn: Button
var daily_btn: Button
var tutorial_btn: Button
var tier_box: HBoxContainer  # one button per unlocked tier
var perks_box: VBoxContainer  # one row per perk: name, desc, buy button
var _info: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12, 1.0)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)
	var title := _label("HUMAN ERROR", 44)
	box.add_child(title)
	_info = _label("", 30)
	box.add_child(_info)
	tier_box = HBoxContainer.new()
	tier_box.alignment = BoxContainer.ALIGNMENT_CENTER
	tier_box.add_theme_constant_override("separation", 10)
	box.add_child(tier_box)
	var perks_title := _label("Perks", 28)
	box.add_child(perks_title)
	perks_box = VBoxContainer.new()
	perks_box.custom_minimum_size = Vector2(440, 60)
	perks_box.add_theme_constant_override("separation", 8)
	box.add_child(perks_box)
	start_btn = _button("Start career", 40, Vector2(440, 110))
	start_btn.pressed.connect(start_pressed.emit)
	box.add_child(start_btn)
	daily_btn = _button("Daily", 28, Vector2(440, 80))
	daily_btn.pressed.connect(daily_pressed.emit)
	box.add_child(daily_btn)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	stats_btn = _button("Stats", 24, Vector2(214, 80))
	stats_btn.pressed.connect(stats_pressed.emit)
	row.add_child(stats_btn)
	tutorial_btn = _button("Replay tutorial", 22, Vector2(214, 80))
	tutorial_btn.pressed.connect(tutorial_pressed.emit)
	row.add_child(tutorial_btn)
	visible = false


func setup(m: Meta, today: String = "") -> void:
	_info.text = "Commendations: %d\nBest: %d days (tier %d)\nCareers: %d" % [
		m.balance(), m.best_for(m.picked_tier), m.picked_tier, m.stats.careers_finished]
	if today != "":
		var best := m.daily_best_for(today)
		daily_btn.text = "Daily %s\n%s" % [today, ("best %d days (played today)" % best) if m.daily_played(today) else "not played today"]
		if m.daily_streak > 0:
			daily_btn.text += " | streak %d" % m.daily_streak
	for c in tier_box.get_children():
		tier_box.remove_child(c)
		c.queue_free()
	for t in range(1, m.tier + 1):
		var tb := _button("Tier %d\nbest %d" % [t, m.best_for(t)], 22, Vector2(140, 80))
		tb.name = "tier_%d" % t
		tb.disabled = t == m.picked_tier
		tb.pressed.connect(tier_picked.emit.bind(t))
		tier_box.add_child(tb)
	for c in perks_box.get_children():
		perks_box.remove_child(c)
		c.queue_free()
	for p: Variant in Meta.load_perks().get("perks", []):
		var d := p as Dictionary
		var id := String(d["id"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var txt := _label("%s\n%s" % [d["name"], d["desc"]], 18)
		txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		txt.custom_minimum_size = Vector2(300, 0)
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(txt)
		var owned := m.owns(id)
		var b := _button("OWNED" if owned else "Buy %d" % int(d["cost"]), 22, Vector2(130, 80))
		b.name = "perk_" + id
		var afford := m.balance() >= int(d["cost"])
		b.disabled = owned or not afford
		if not owned and not afford:
			b.modulate = Color(1, 1, 1, 0.45)
		b.pressed.connect(perk_bought.emit.bind(id))
		row.add_child(b)
		perks_box.add_child(row)


func _label(text: String, font: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(440, 0)
	l.add_theme_font_size_override("font_size", font)
	return l


func _button(text: String, font: int, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font)
	return b
