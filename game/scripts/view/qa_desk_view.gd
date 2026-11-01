class_name QaDeskView
extends Node2D
## The QA desk strip: queue, front product on a pad, BRB sign, streak, flashes. Reads sim state only.

const COL_BG := Color(0.14, 0.15, 0.19)
const COL_BODY := Color(0.3, 0.65, 0.85)
const COL_PAINT := Color(0.9, 0.3, 0.7)
const COL_LABEL := Color(0.97, 0.92, 0.75)

var factory: Factory
var rect := Rect2(0, 0, 100, 100)  # strip rect in screen space
var hint: String = ""
var caption: String = ""  # spec card caption (day 1 only), lines split by " · "
var _font: Font = ThemeDB.fallback_font
var _time: float = 0.0
var _last_q: int = 0
var _slide: float = 0.0
var _flashes: Array[Dictionary] = []  # {text, color, left}
var _anim: Dictionary = {}  # {item, kind: "ship"|"reject", t}


func setup(f: Factory) -> void:
	factory = f
	_last_q = 0
	_slide = 0.0
	_flashes.clear()
	_anim = {}


func flash(text: String, col: Color, secs: float = 1.2) -> void:
	_flashes.append({"text": text, "color": col, "left": secs, "total": secs})
	if _flashes.size() > 3:
		_flashes.pop_front()


## Start the ship/reject animation for the item that was at the front before inspect().
func play_inspect(item: Dictionary, shipped: bool) -> void:
	_anim = {"item": item, "kind": "ship" if shipped else "reject", "t": 0.0}


## True while the BRB sign is up (worker is on the floor or walking).
func brb_visible() -> bool:
	return factory != null and not factory.worker_at_desk()


func pad_rect() -> Rect2:
	var top := rect.position.y + 70.0
	var h := maxf(120.0, rect.size.y - 70.0 - 110.0)
	var s := minf(h, rect.size.x * 0.5)
	return Rect2(rect.position.x + rect.size.x * 0.5 - s * 0.5, top + (h - s) * 0.5, s, s)


## Spec card: right of the pad, above the ship/reject buttons (pad rows end 110px above strip bottom).
func spec_rect() -> Rect2:
	var pad := pad_rect()
	var w := clampf(rect.end.x - pad.end.x - 20.0, 60.0, 170.0)
	return Rect2(pad.end.x + 10.0, pad.position.y, w, minf(pad.size.y, w * 0.75 + 100.0))


func _draw_spec() -> void:
	var r := spec_rect()
	draw_rect(r, Color(0.2, 0.22, 0.28))
	draw_rect(r, Color(0.5, 0.55, 0.65), false, 2.0)
	_text("SPEC", r.position + Vector2(8, 22), 18, Color(0.8, 0.85, 1.0), r.size.x - 16)
	draw_product({"defect": "", "decoy": "", "bot": ""}, r.position + Vector2(r.size.x * 0.5, 30.0 + r.size.x * 0.4), Vector2(r.size.x - 8.0, r.size.x - 8.0))
	if caption != "":
		var y := r.position.y + 36.0 + r.size.x * 0.75
		for line in caption.split(" · "):
			_text(line, Vector2(r.position.x + 8, y), 16, Color.WHITE, r.size.x - 16)
			y += 20.0


func _process(d: float) -> void:
	_time += d
	for fl in _flashes:
		fl["left"] -= d
	_flashes = _flashes.filter(func(fl: Dictionary) -> bool: return fl["left"] > 0.0)
	_slide = maxf(0.0, _slide - d * 4.0)
	if not _anim.is_empty():
		_anim["t"] += d / 0.35
		if _anim["t"] >= 1.0:
			_anim = {}
	queue_redraw()


func _bot_color(name: String) -> Color:
	for m in factory.machines:
		if m.bot != null and m.bot.name == name:
			return m.bot.color
	return Color(0.6, 0.6, 0.6)


func _draw() -> void:
	if factory == null:
		return
	draw_rect(rect, COL_BG)
	Sprites.draw_fit(self, Sprites.tex("bg_office"), rect)
	draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color(0.4, 0.42, 0.5), 3.0)
	var q := factory.qa_queue()
	if q.size() > _last_q:
		_slide = 1.0
	_last_q = q.size()
	_draw_queue(q)
	var pad := pad_rect()
	_draw_pad(pad)
	_draw_spec()
	var shake := 0.0
	if not _anim.is_empty() and _anim["kind"] == "reject":
		shake = sin(float(_anim["t"]) * 40.0) * 6.0 * (1.0 - float(_anim["t"]))
	if not q.is_empty() and _anim.is_empty():
		draw_product(q[0], pad.get_center() + Vector2(shake, 0), pad.size * 0.8)
	_draw_anim(pad)
	if brb_visible():
		_draw_brb(pad)
	_text("Streak %d" % factory.streak, rect.position + Vector2(rect.size.x - 150, 62), 24, Color(1.0, 0.85, 0.3), 140.0)
	_draw_flashes(pad)
	if hint != "":
		_draw_hint()


func _draw_queue(q: Array) -> void:
	var cap := maxi(1, factory.qa_capacity)
	var frac := float(q.size()) / float(cap)
	var col := Color(0.7, 0.72, 0.78)
	if q.size() >= cap:
		col = Color(0.95, 0.25, 0.2)
	elif frac >= 0.75:
		col = Color(1.0, 0.6, 0.15)
	var bw := minf(34.0, (rect.size.x - 200.0) / float(cap) - 4.0)
	for i in q.size():
		var x := rect.position.x + 12.0 + float(i) * (bw + 4.0)
		if i == q.size() - 1:
			x -= _slide * 60.0
		draw_rect(Rect2(x, rect.position.y + 14.0, bw, 30.0), col)
	_text("%d/%d" % [q.size(), cap], rect.position + Vector2(rect.size.x - 150, 38), 28, col, 140.0)


func _draw_pad(pad: Rect2) -> void:
	var c := pad.get_center()
	draw_rect(Rect2(pad.position + Vector2(0, pad.size.y * 0.78), Vector2(pad.size.x, pad.size.y * 0.16)), Color(0.28, 0.3, 0.36))
	# lamp: head + soft cone of light on the pad
	var head := Vector2(c.x + pad.size.x * 0.55, pad.position.y - 2.0)
	draw_colored_polygon(PackedVector2Array([head, Vector2(c.x - pad.size.x * 0.35, pad.position.y + pad.size.y * 0.8), Vector2(c.x + pad.size.x * 0.35, pad.position.y + pad.size.y * 0.8)]), Color(1, 0.95, 0.6, 0.07))
	draw_circle(head, 9.0, Color(1.0, 0.9, 0.5))
	draw_line(head, head + Vector2(24, -20), Color(0.5, 0.5, 0.55), 4.0)


func _draw_brb(pad: Rect2) -> void:
	draw_rect(pad, Color(0, 0, 0, 0.5))
	var r := Rect2(pad.get_center() - Vector2(90, 34), Vector2(180, 68))
	draw_rect(r, Color(0.95, 0.75, 0.2))
	draw_rect(r, Color(0.2, 0.15, 0.0), false, 4.0)
	_text("BRB", r.position + Vector2(36, 50), 46, Color(0.2, 0.15, 0.0), 140.0)


func _draw_anim(pad: Rect2) -> void:
	if _anim.is_empty():
		return
	var t: float = _anim["t"]
	var c := pad.get_center()
	if _anim["kind"] == "ship":
		draw_product(_anim["item"], c + Vector2(t * (rect.size.x * 0.6), 0), pad.size * 0.8)
		_text("✔", c + Vector2(-20, 20), 70, Color(0.3, 1.0, 0.4, 1.0 - t), 60.0)
	else:
		var bin := Vector2(rect.position.x + 50, rect.end.y - 120)
		draw_product(_anim["item"], c.lerp(bin, t) + Vector2(0, t * t * 40.0), pad.size * 0.8 * (1.0 - 0.5 * t))
		if not Sprites.draw_named(self, "reject_bin", Rect2(bin + Vector2(-34, 30), Vector2(68, 50)).grow(8.0)):
			draw_rect(Rect2(bin + Vector2(-34, 30), Vector2(68, 50)), Color(0.3, 0.2, 0.2))


func _draw_flashes(pad: Rect2) -> void:
	var y := pad.position.y + 30.0
	for fl in _flashes:
		var a := clampf(float(fl["left"]) / 0.4, 0.0, 1.0)
		var col: Color = fl["color"]
		col.a = a
		_text(String(fl["text"]), Vector2(rect.position.x + 16, y), 30, col, rect.size.x - 32)
		y += 38.0


func _draw_hint() -> void:
	var r := Rect2(rect.position + Vector2(10, rect.size.y * 0.3), Vector2(rect.size.x - 20, 90))
	draw_rect(r, Color(0, 0, 0, 0.8))
	var y := r.position.y + 34.0
	for line in hint.split("\n"):
		_text(line, Vector2(r.position.x + 10, y), 22, Color.WHITE, r.size.x - 20)
		y += 30.0


## Draw one product centred at c, fitting in a square of size s. Used for the pad and animations.
func draw_product(item: Dictionary, c: Vector2, s: Vector2) -> void:
	var w := s.x * 0.9
	var h := s.y * 0.75
	var body := Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h))
	var defect := String(item.get("defect", ""))
	var decoy := String(item.get("decoy", ""))
	if _draw_product_sprites(defect, decoy, c, s):
		return
	var col := COL_PAINT if defect == "wrong_paint" else COL_BODY
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(w * 0.1))
	draw_style_box(sb, body)
	# label stripe (top normally; bottom + arrow when flipped)
	var lh := h * 0.18
	var ly := body.end.y - lh - h * 0.06 if defect == "flipped_label" else body.position.y + h * 0.06
	draw_rect(Rect2(body.position.x + w * 0.1, ly, w * 0.8, lh), COL_LABEL)
	if defect == "flipped_label":
		var ac := Vector2(body.end.x - w * 0.18, ly + lh * 0.5)
		draw_line(ac + Vector2(0, -lh), ac + Vector2(0, lh), Color.BLACK, 3.0)
		draw_colored_polygon(PackedVector2Array([ac + Vector2(-8, -lh + 6), ac + Vector2(8, -lh + 6), ac + Vector2(0, -lh - 6)]), Color.BLACK)
	# six bolts
	var bolt_r := w * 0.055
	for i in 6:
		var bp := Vector2(body.position.x + w * (0.25 + 0.25 * (i % 3)), body.position.y + h * (0.48 if i < 3 else 0.78))
		if defect == "missing_bolt" and i == 4:
			draw_circle(bp, bolt_r, Color(0.05, 0.05, 0.08))
		else:
			draw_circle(bp, bolt_r, Color(0.78, 0.8, 0.85))
			draw_circle(bp + Vector2(-bolt_r * 0.25, -bolt_r * 0.25), bolt_r * 0.35, Color.WHITE)
	if defect == "crack":
		var p0 := body.position + Vector2(w * 0.55, h * 0.02)
		var pts := PackedVector2Array([p0, p0 + Vector2(-w * 0.12, h * 0.2), p0 + Vector2(w * 0.08, h * 0.38), p0 + Vector2(-w * 0.1, h * 0.6), p0 + Vector2(w * 0.06, h * 0.96)])
		draw_polyline(pts, Color(0.05, 0.05, 0.08), 4.0)
	elif defect == "dent":
		var e := Vector2(body.end.x, body.position.y + h * 0.5)
		draw_colored_polygon(PackedVector2Array([e + Vector2(2, -h * 0.28), e + Vector2(-w * 0.2, 0), e + Vector2(2, h * 0.28)]), COL_BG)
	match decoy:
		"scuff":
			draw_line(body.position + Vector2(w * 0.62, h * 0.7), body.position + Vector2(w * 0.8, h * 0.62), Color(1, 1, 1, 0.55), 3.0)
		"sticker_blue":
			draw_circle(body.position + Vector2(w * 0.85, h * 0.4), w * 0.05, Color(0.2, 0.3, 1.0))
		"sticker_green":
			draw_circle(body.position + Vector2(w * 0.85, h * 0.4), w * 0.05, Color(0.2, 0.85, 0.3))
	# flair: tiny mark in the responsible bot's colour
	var bot := String(item.get("bot", ""))
	if bot != "":
		draw_circle(body.position + Vector2(w * 0.08, h * 0.92), w * 0.04, _bot_color(bot))


## Sprite path for a product. True if a sprite product was drawn (code drawing skipped).
func _draw_product_sprites(defect: String, decoy: String, c: Vector2, s: Vector2) -> bool:
	var full := Sprites.tex("product_full")
	var base := Sprites.tex("product")
	if full == null and base == null:
		return false
	var w := s.x * 0.9
	var r := Rect2(c - Vector2(w, w * 0.75) * 0.5, Vector2(w, w * 0.75))
	if full != null:
		Sprites.draw_fit(self, full, r)
	else:
		Sprites.draw_fit(self, base, r)
		var body := Rect2(r.position.x + r.size.x * 0.1, r.position.y + r.size.y * 0.06, r.size.x * 0.8, r.size.y * 0.18)
		if defect == "flipped_label":
			body.position.y = r.end.y - body.size.y - r.size.y * 0.06
		draw_rect(body, COL_LABEL)
		for i in 6:
			var bp := Vector2(r.position.x + r.size.x * (0.25 + 0.25 * (i % 3)), r.position.y + r.size.y * (0.48 if i < 3 else 0.78))
			if not (defect == "missing_bolt" and i == 4):
				draw_circle(bp, r.size.x * 0.055, Color(0.78, 0.8, 0.85))
	if defect != "":
		Sprites.draw_named(self, "defect_" + defect, r)
	if decoy != "":
		Sprites.draw_named(self, "decoy_" + decoy, r)
	return true


func _text(s: String, pos: Vector2, size: int, col: Color, width: float) -> void:
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, width, size, col)
