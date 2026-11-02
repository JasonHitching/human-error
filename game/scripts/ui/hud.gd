class_name Hud
extends Control
## Top bar, flash text, and full-screen overlays (day banner, review, fired). Built in code.

signal start_pressed
signal continue_pressed
signal offer_pressed(index: int)
signal restart_pressed  # fired: Home link
signal again_pressed  # fired: One more career
signal replay_pressed
signal stats_pressed
signal settings_pressed

var banner: Control
var review: Control
var fired: Control
var top_bar: TopBar
var debug_overlay: bool = false
var _flash: Label
var _seed: Label
var _twist: Label
var _banner_label: Label
var _review_box: VBoxContainer
var _fired_box: VBoxContainer
var _retry_btn: Button
var stats_btn: Button  # Stats link on the run-end screen
var stats_overlay: Control
var _stats_box: VBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top_bar = TopBar.new()
	add_child(top_bar)
	top_bar.settings_pressed.connect(settings_pressed.emit)
	_flash = _label(22, HORIZONTAL_ALIGNMENT_CENTER)
	_flash.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	_twist = _label(18, HORIZONTAL_ALIGNMENT_CENTER)
	_twist.add_theme_color_override("font_color", Color(1, 0.7, 0.3))
	_seed = _label(12, HORIZONTAL_ALIGNMENT_LEFT)
	_seed.modulate = Color(1, 1, 1, 0.5)
	_seed.visible = false
	var bb := _overlay()
	banner = bb[0]
	_banner_label = _big(bb[1])
	_button(bb[1], "Tap to start", start_pressed.emit, "primary")
	var rb := _overlay()
	review = rb[0]
	_review_box = rb[1]
	var fb := _overlay()
	fired = fb[0]
	_fired_box = fb[1]
	var sb := _overlay()
	stats_overlay = sb[0]
	_stats_box = sb[1]
	resized.connect(_layout)
	_layout()


func _label(size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	add_child(l)
	return l


## Full-screen overlay with a scrolling column. Returns [overlay, column].
func _overlay() -> Array:
	return UiKit.screen(self, true)


func _big(box: Control) -> Label:
	var l := UiKit.label("", 32)
	box.add_child(l)
	return l


func _button(box: Control, text: String, cb: Callable, kind: String = "secondary") -> Button:
	var b := UiKit.button(box, text, kind, 72.0 if kind == "primary" else 56.0, 30 if kind == "primary" else 26)
	b.pressed.connect(cb)
	return b


func _layout() -> void:
	top_bar.size = Vector2(size.x, TopBar.height())
	var strip := TopBar.height() + 2.0
	_flash.size = Vector2(size.x, 32)
	_flash.position = Vector2(0, strip)
	_twist.size = Vector2(size.x, 32)
	_twist.position = Vector2(0, strip)
	_seed.size = Vector2(size.x * 0.2, 20)
	_seed.position = Vector2(4, size.y - 24)


func update(f: Factory, c: Career, tick_rate: int, shift_ticks: int, _best_days: int) -> void:
	var left := maxf(0.0, float(shift_ticks - f.tick) / tick_rate)
	top_bar.set_state(c.day, int(left), f.score(), f.target, c.strikes, c.config.max_strikes, f.complaints, f.complaint_penalty)
	_seed.visible = debug_overlay
	_seed.text = "career %d" % c.seed
	_twist.visible = _flash.text == ""
	var tw := c.twist()
	_twist.text = "%s %s%s" % [tw.get("icon", ""), tw.get("name", ""), " - POWER OUT" if f.power_out() else ""] if not tw.is_empty() else ""


func set_flash(text: String) -> void:
	_flash.text = text


func show_banner(day: int, line: String, target: int, twist: Dictionary = {}, spec_change: String = "", news: String = "") -> void:
	var tw := ""
	if news != "":
		tw = "\n\n" + news
	if spec_change != "":
		tw += "\n\n" + spec_change
	if not twist.is_empty():
		tw += "\n\nTWIST: %s %s\n%s" % [twist.get("icon", ""), twist.get("name", ""), twist.get("line", "")]
	_banner_label.text = "FOREMAN\nDay %d · target %d\n\n%s%s" % [day, target, line, tw]
	_show_only(banner)


func show_review(res: Dictionary, line: String, offers: Array[Dictionary], extra: String = "") -> void:
	var notes: Array[String] = []
	if String(res.get("spec_change", "")) != "":
		notes.append(String(res["spec_change"]))
	var rk: Dictionary = res.get("rookie", {})
	if not rk.is_empty():
		notes.append("Rookie: %s%s" % [rk["name"], "" if String(rk["replaced"]) == "" else " (replaces %s)" % rk["replaced"]])
	var ls: Array = res.get("lessons", [])
	for i in mini(ls.size(), 2):
		notes.append("%s learned: no more %s" % [ls[i]["bot"], String(ls[i]["mistake"]).replace("_", " ")])
	if ls.size() > 2:
		notes.append("+%d more lessons" % (ls.size() - 2))
	if int(res.get("subtle_scanned", 0)) + int(res.get("subtle_shipped", 0)) > 0:
		notes.append("Hairline faults: caught %d by scanning, shipped %d" % [res.get("subtle_caught", 0), res.get("subtle_shipped", 0)])
	var missed := _missed_line(res)
	if missed != "":
		notes.append(missed.strip_edges())
	ResultCards.review(_review_box, res, line, offers, extra, notes, func(i: int) -> void: offer_pressed.emit(i), continue_pressed.emit)
	_show_only(review)


## info (optional): score, target, best, colors {bot name: Color}, award_total.
func show_fired(days: int, line: String, breakdown: String, teaser: String, awards: String = "", title: String = "FIRED", info: Dictionary = {}) -> void:
	_retry_btn = ResultCards.fired(_fired_box, title, days, line, breakdown, teaser, awards, info, again_pressed.emit, replay_pressed.emit, restart_pressed.emit, stats_pressed.emit)
	stats_btn = _stats_link()
	_show_only(fired)


func _stats_link() -> Button:
	for b in _fired_box.find_children("*", "Button", true, false):
		if (b as Button).text == "Stats":
			return b
	return null


func show_stats(text: String) -> void:
	UiKit.clear(_stats_box)
	var lines := text.split("\n", false)
	_stats_box.add_child(UiKit.label("Stats", 40, UiTheme.TEXT, true))
	var c := UiKit.card(_stats_box, null, 8.0, 14.0)
	for l in lines.slice(1):
		var kv := l.split(": ", true, 1)
		UiKit.row(c, kv[0], kv[1] if kv.size() > 1 else "")
	_button(_stats_box, "Close", hide_stats)
	stats_overlay.visible = true


func hide_stats() -> void:
	stats_overlay.visible = false


func hide_overlays() -> void:
	_show_only(null)


func _show_only(o: Control) -> void:
	for c: Control in [banner, review, fired]:
		c.visible = c == o


## "\nMissed: crack ×2, dent ×1" or "" when nothing was missed.
func _missed_line(res: Dictionary) -> String:
	var m: Dictionary = res.get("missed_by_type", {})
	if m.is_empty():
		return ""
	var parts: Array[String] = []
	for k in m:
		parts.append("%s x%d" % [String(k).replace("_", " "), int(m[k])])
	return "Missed: " + ", ".join(parts)


## All label text under a node, joined by newlines (tests and ui_check).
static func text_of(n: Node) -> String:
	var out: Array[String] = []
	for l in n.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	for b in n.find_children("*", "Button", true, false):
		out.append((b as Button).text)
	return "\n".join(out)
