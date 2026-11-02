class_name ProductArt
extends RefCounted
## Draws the QA product (body, label, bolts, defects) onto any CanvasItem: the desk pad and the spec chip icon.

const COL_BG := Color(0.14, 0.15, 0.19)
const COL_BODY := Color(0.3, 0.65, 0.85)
const COL_PAINT := Color(0.9, 0.3, 0.7)
const COL_LABEL := Color(0.97, 0.92, 0.75)


## Draw one product centred at c, fitting in a square of size s. Used for the pad and animations.
static func draw(ci: CanvasItem, item: Dictionary, c: Vector2, s: Vector2, bot_col: Color = Color.WHITE) -> void:
	var w := s.x * 0.9
	var h := s.y * 0.75
	var body := Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h))
	var defect := QaDeskView.shown_defect(item)
	var decoy := String(item.get("decoy", ""))
	if _sprites(ci, defect, decoy, c, s):
		return
	var col := COL_PAINT if defect == "wrong_paint" else COL_BODY
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(w * 0.1))
	ci.draw_style_box(sb, body)
	# label stripe (top normally; bottom + arrow when flipped)
	var lh := h * 0.18
	var ly := body.end.y - lh - h * 0.06 if defect == "flipped_label" else body.position.y + h * 0.06
	ci.draw_rect(Rect2(body.position.x + w * 0.1, ly, w * 0.8, lh), COL_LABEL)
	if defect == "flipped_label":
		var ac := Vector2(body.end.x - w * 0.18, ly + lh * 0.5)
		ci.draw_line(ac + Vector2(0, -lh), ac + Vector2(0, lh), Color.BLACK, 3.0)
		ci.draw_colored_polygon(PackedVector2Array([ac + Vector2(-8, -lh + 6), ac + Vector2(8, -lh + 6), ac + Vector2(0, -lh - 6)]), Color.BLACK)
	# six bolts
	var bolt_r := w * 0.055
	for i in 6:
		var bp := Vector2(body.position.x + w * (0.25 + 0.25 * (i % 3)), body.position.y + h * (0.48 if i < 3 else 0.78))
		if defect == "missing_bolt" and i == 4:
			ci.draw_circle(bp, bolt_r, Color(0.05, 0.05, 0.08))
		else:
			ci.draw_circle(bp, bolt_r, Color(0.78, 0.8, 0.85))
			ci.draw_circle(bp + Vector2(-bolt_r * 0.25, -bolt_r * 0.25), bolt_r * 0.35, Color.WHITE)
	if defect == "crack":
		var p0 := body.position + Vector2(w * 0.55, h * 0.02)
		var pts := PackedVector2Array([p0, p0 + Vector2(-w * 0.12, h * 0.2), p0 + Vector2(w * 0.08, h * 0.38), p0 + Vector2(-w * 0.1, h * 0.6), p0 + Vector2(w * 0.06, h * 0.96)])
		ci.draw_polyline(pts, Color(0.05, 0.05, 0.08), 4.0)
	elif defect == "dent":
		var e := Vector2(body.end.x, body.position.y + h * 0.5)
		ci.draw_colored_polygon(PackedVector2Array([e + Vector2(2, -h * 0.28), e + Vector2(-w * 0.2, 0), e + Vector2(2, h * 0.28)]), COL_BG)
	match decoy:
		"scuff":
			ci.draw_line(body.position + Vector2(w * 0.62, h * 0.7), body.position + Vector2(w * 0.8, h * 0.62), Color(1, 1, 1, 0.55), 3.0)
		"sticker_blue":
			ci.draw_circle(body.position + Vector2(w * 0.85, h * 0.4), w * 0.05, Color(0.2, 0.3, 1.0))
		"sticker_green":
			ci.draw_circle(body.position + Vector2(w * 0.85, h * 0.4), w * 0.05, Color(0.2, 0.85, 0.3))
	# flair: tiny mark in the responsible bot's colour
	var bot := String(item.get("bot", ""))
	if bot != "":
		ci.draw_circle(body.position + Vector2(w * 0.08, h * 0.92), w * 0.04, bot_col)


## Sprite path for a product. True if a sprite product was drawn (code drawing skipped).
static func _sprites(ci: CanvasItem, defect: String, decoy: String, c: Vector2, s: Vector2) -> bool:
	var full := Sprites.tex("product_full")
	var base := Sprites.tex("product")
	if full == null and base == null:
		return false
	var w := s.x * 0.9
	var r := Rect2(c - Vector2(w, w * 0.75) * 0.5, Vector2(w, w * 0.75))
	if full != null:
		Sprites.draw_fit(ci, full, r)
	else:
		Sprites.draw_fit(ci, base, r)
		var body := Rect2(r.position.x + r.size.x * 0.1, r.position.y + r.size.y * 0.06, r.size.x * 0.8, r.size.y * 0.18)
		if defect == "flipped_label":
			body.position.y = r.end.y - body.size.y - r.size.y * 0.06
		ci.draw_rect(body, COL_LABEL)
		for i in 6:
			var bp := Vector2(r.position.x + r.size.x * (0.25 + 0.25 * (i % 3)), r.position.y + r.size.y * (0.48 if i < 3 else 0.78))
			if not (defect == "missing_bolt" and i == 4):
				ci.draw_circle(bp, r.size.x * 0.055, Color(0.78, 0.8, 0.85))
	if defect != "":
		Sprites.draw_named(ci, "defect_" + defect, r)
	if decoy != "":
		Sprites.draw_named(ci, "decoy_" + decoy, r)
	return true
