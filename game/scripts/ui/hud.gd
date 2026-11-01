class_name Hud
extends Control
## Top bar, flash text, and full-screen overlays (day banner, review, fired). Built in code.

signal start_pressed
signal continue_pressed
signal offer_pressed(index: int)
signal restart_pressed
signal replay_pressed

var banner: Control
var review: Control
var fired: Control
var _top: Label
var _flash: Label
var _seed: Label
var _banner_label: Label
var _review_label: Label
var _review_box: VBoxContainer
var _fired_label: Label
var _retry_btn: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_top = _label(22, HORIZONTAL_ALIGNMENT_CENTER)
	_top.position = Vector2(0, 8)
	_flash = _label(22, HORIZONTAL_ALIGNMENT_CENTER)
	_flash.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	_seed = _label(12, HORIZONTAL_ALIGNMENT_LEFT)
	_seed.modulate = Color(1, 1, 1, 0.5)
	var bb := _overlay()
	banner = bb[0]
	_banner_label = _big(bb[1])
	_button(bb[1], "Tap to start", start_pressed.emit)
	var rb := _overlay()
	review = rb[0]
	_review_box = rb[1]
	_review_label = _big(_review_box)
	var fb := _overlay()
	fired = fb[0]
	_fired_label = _big(fb[1])
	_retry_btn = _button(fb[1], "One more career", restart_pressed.emit)
	_retry_btn.custom_minimum_size = Vector2(440, 140)
	_retry_btn.add_theme_font_size_override("font_size", 40)
	var rp := _button(fb[1], "Replay this seed", replay_pressed.emit)
	rp.custom_minimum_size = Vector2(440, 80)
	rp.add_theme_font_size_override("font_size", 22)
	resized.connect(_layout)
	_layout()


func _label(size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	add_child(l)
	return l


## Full-screen dim overlay with a centred VBox. Returns [overlay, box].
func _overlay() -> Array:
	var o := ColorRect.new()
	o.color = Color(0, 0, 0, 0.82)
	o.visible = false
	add_child(o)
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	o.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	center.add_child(box)
	return [o, box]


func _big(box: Control) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(440, 0)
	l.add_theme_font_size_override("font_size", 32)
	box.add_child(l)
	return l


func _button(box: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(440, 90)
	b.add_theme_font_size_override("font_size", 28)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.pressed.connect(cb)
	box.add_child(b)
	return b


func _layout() -> void:
	_top.size = Vector2(size.x, 80)
	_flash.size = Vector2(size.x, 40)
	_flash.position = Vector2(0, 84)
	_seed.size = Vector2(size.x * 0.2, 20)
	_seed.position = Vector2(4, size.y - 24)


func update(f: Factory, c: Career, tick_rate: int, shift_ticks: int, best_days: int) -> void:
	var left := maxf(0.0, float(shift_ticks - f.tick) / tick_rate)
	var crew := "Crew: idle"
	if f.crew_busy:
		crew = "Crew: %s %d%%" % [f.crew_target, roundi(f.crew_progress * 100.0)]
	elif f.worker_location() == Worker.Location.TRANSIT:
		crew = "Walking..."
	elif f.worker_location() == Worker.Location.FLOOR:
		crew = "On the floor"

	var marks := ""
	for i in c.config.max_strikes:
		marks += "[X]" if i < c.strikes else "[ ]"
	_top.text = "Day %d · %d:%02d · Score %d / %d · Strikes %s\nComplaints %d (-%d each) · %s · Best %d" % [c.day, int(left) / 60, int(left) % 60, f.score(), f.target, marks, f.complaints, c.config.complaint_penalty, crew, best_days]
	_seed.text = "career %d" % c.seed


func set_flash(text: String) -> void:
	_flash.text = text


func show_banner(day: int, line: String, target: int) -> void:
	_banner_label.text = "FOREMAN\nDay %d · target %d\n\n%s" % [day, target, line]
	_show_only(banner)


func show_review(res: Dictionary, line: String, offers: Array[Dictionary], extra: String = "") -> void:
	_review_label.text = "Day over\nScore %d / %d - %s\nCaught %d · Complaints %d · Wasted %d\nStrikes %d%s\n\n%s" % [res["shipped"], res["target"], "HIT" if res["hit"] else "MISS", res["caught"], res["complaints"], res["wasted"], res["strikes"], _missed_line(res), line]
	if extra != "":
		_review_label.text += "\n" + extra
	if res.get("probation", false):
		_review_label.text = _review_label.text.replace("Strikes %d" % res["strikes"], "Probation: no strike")
	for n in _review_box.get_children():
		if n != _review_label:
			_review_box.remove_child(n)
			n.queue_free()
	if int(res["points"]) > 0 and not offers.is_empty():
		_review_label.text += "\nTraining points: %d - pick one:" % res["points"]
		for i in offers.size():
			var idx := i
			_button(_review_box, String(offers[i]["text"]), func() -> void: offer_pressed.emit(idx))
	_button(_review_box, "Continue", continue_pressed.emit)
	_show_only(review)


func show_fired(days: int, line: String, breakdown: String, teaser: String) -> void:
	_fired_label.text = "FIRED\nDays survived: %d\n\n%s\n\n%s\n%s" % [days, breakdown, teaser, line]
	_show_only(fired)


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
	return "\nMissed: " + ", ".join(parts)
