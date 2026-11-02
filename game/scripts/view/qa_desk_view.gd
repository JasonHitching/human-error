class_name QaDeskView
extends Node2D
## The QA desk strip: queue, front product on a pad, BRB sign, streak, flashes. Reads sim state only.

const COL_BG := Color(0.14, 0.15, 0.19)
const COL_BODY := Color(0.3, 0.65, 0.85)
const COL_PAINT := Color(0.9, 0.3, 0.7)
const COL_LABEL := Color(0.97, 0.92, 0.75)

var factory: Factory
var feel: Feel
var rect := Rect2(0, 0, 100, 100)  # strip rect in screen space
var hint: String = ""
var spec_new: bool = false  # the Foreman changed the spec today: highlight the card
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


const BASE_RULE := "6 bolts · label on top · blue body"
const T_LG := 30
const T_MD := 24
const T_SM := 20


static func _side() -> float:
	return UiTheme.px(10.0)


## Queue row at the top of the desk: slot pills, "Desk queue" text, streak pill on the right.
func queue_rect() -> Rect2:
	return Rect2(rect.position.x + _side(), rect.position.y + 4.0, rect.size.x - _side() * 2.0, UiTheme.px(42.0))


func streak_rect() -> Rect2:
	var q := queue_rect()
	var w := UiTheme.px(88.0)
	return Rect2(q.end.x - w, q.position.y + UiTheme.px(4.0), w, UiTheme.px(28.0))


## Spec chip above the product.
func spec_rect() -> Rect2:
	var q := queue_rect()
	return Rect2(q.position.x, q.end.y + 8.0, q.size.x, UiTheme.px(36.0))


## Action rows (laid out from the bottom of the desk): main = Reject | Scan | Ship, small = Flip | X-ray.
func main_row() -> Array[Rect2]:
	var h := UiTheme.px(60.0)
	var gap := UiTheme.px(8.0)
	var w := rect.size.x - _side() * 2.0 - gap * 2.0
	var u := w / 2.7
	var y := rect.end.y - _side() - h
	var x := rect.position.x + _side()
	return [Rect2(x, y, u, h), Rect2(x + u + gap, y, u * 0.7, h), Rect2(x + u * 1.7 + gap * 2.0, y, u, h)]


func small_row() -> Array[Rect2]:
	var h := UiTheme.px(44.0)
	var gap := UiTheme.px(8.0)
	var w := (rect.size.x - _side() * 2.0 - gap) * 0.5
	var y := main_row()[0].position.y - gap - h
	var x := rect.position.x + _side()
	return [Rect2(x, y, w, h), Rect2(x + w + gap, y, w, h)]


## Free strip under the product: faint swipe labels, or the one-time hint toast.
func toast_rect() -> Rect2:
	var y := small_row()[0].position.y - 8.0 - UiTheme.px(34.0)
	return Rect2(rect.position.x + _side(), y, rect.size.x - _side() * 2.0, UiTheme.px(34.0))


## The product pad: a square centred between the spec chip and the toast strip.
func pad_rect() -> Rect2:
	var top := spec_rect().end.y + 8.0
	var h := maxf(40.0, toast_rect().position.y - 8.0 - top)
	var s := minf(h, rect.size.x - _side() * 2.0)
	return Rect2(rect.position.x + rect.size.x * 0.5 - s * 0.5, top + (h - s) * 0.5, s, s)


func _draw_spec() -> void:
	var r := spec_rect()
	var border := UiTheme.WARN if spec_new else UiTheme.LINE
	draw_style_box(UiTheme.box(UiTheme.WARN_BG if spec_new else UiTheme.SURFACE, border, 14.0, 2.0 if spec_new else 1.0), r)
	var label := "NEW SPEC" if spec_new else "SPEC"
	var lw := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, T_SM).x
	var x := r.position.x + UiTheme.px(10.0)
	_text(label, Vector2(x, r.get_center().y + 7.0), T_SM, UiTheme.WARN if spec_new else UiTheme.TEXT_DIM, lw + 4.0)
	x += lw + UiTheme.px(8.0)
	var ms := r.size.y - 12.0
	draw_product({"defect": "", "decoy": "", "bot": ""}, Vector2(x + ms * 0.5, r.get_center().y), Vector2(ms, ms * 1.1))
	x += ms + UiTheme.px(8.0)
	var rule := caption if caption != "" else BASE_RULE
	var avail := r.end.x - x - UiTheme.px(8.0)
	var fs := T_MD
	while fs > 14 and _font.get_string_size(rule, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > avail:
		fs -= 1
	_text(rule, Vector2(x, r.get_center().y + fs * 0.35), fs, UiTheme.TEXT, avail)


func _process(d: float) -> void:
	_time += d
	if feel != null:
		position = feel.shake_offset()
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
	draw_rect(rect, UiTheme.BG)
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
		draw_product(q[0], pad.get_center() + Vector2(shake, 0), pad.size)
	_draw_anim(pad)
	_draw_feel(pad, q)
	if brb_visible():
		_draw_brb(pad)
	_draw_streak()
	_draw_flashes(pad)
	if hint != "":
		_draw_hint()
	else:
		_draw_swipe_labels()


func _draw_streak() -> void:
	var r := streak_rect()
	var pop := 1.0 + (feel.pop_t / 0.25 * 0.2 if feel != null else 0.0)
	draw_set_transform(r.get_center(), 0.0, Vector2(pop, pop))
	var local := Rect2(-r.size * 0.5, r.size)
	draw_style_box(UiTheme.box(UiTheme.SURFACE, UiTheme.ACCENT, r.size.y * 0.5 / UiTheme.DESIGN_W * UiTheme.MOCK_W, 1.5), local)
	_text("Streak %d" % (feel.streak if feel != null else factory.streak), Vector2(-r.size.x * 0.5 + 12.0, 7.0), T_SM, UiTheme.ACCENT, r.size.x - 20.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_queue(q: Array) -> void:
	var cap := maxi(1, factory.qa_capacity)
	var frac := float(q.size()) / float(cap)
	var col := UiTheme.TEXT_DIM
	if q.size() >= cap:
		col = UiTheme.CRIT
	elif frac >= 0.75:
		col = UiTheme.WARN
	var qr := queue_rect()
	var sr := streak_rect()
	var avail := sr.position.x - qr.position.x - UiTheme.px(8.0)
	var gap := 4.0
	var bw := minf(UiTheme.px(18.0), (avail - gap * float(cap - 1)) / float(cap))
	var ph := UiTheme.px(12.0)
	for i in cap:
		var pr := Rect2(qr.position.x + float(i) * (bw + gap), qr.position.y + 2.0, bw, ph)
		draw_style_box(UiTheme.box(col if i < q.size() else UiTheme.TRACK, Color(0, 0, 0, 0), ph * 0.5 / UiTheme.DESIGN_W * UiTheme.MOCK_W), pr)
	var text := "Desk queue %d / %d" % [q.size(), cap]
	var slots: int = factory.shelf_slots
	if slots > 0:
		var n: int = factory.qa_shelf().size()
		text += " · shelf %d / %d" % [n, slots]
		if n >= slots:
			col = UiTheme.CRIT
		elif n > 0 and col == UiTheme.TEXT_DIM:
			col = UiTheme.WARN
	_text(text, Vector2(qr.position.x, qr.position.y + ph + 4.0 + 20.0), T_SM, col, avail)


func _draw_pad(pad: Rect2) -> void:
	draw_style_box(UiTheme.box(UiTheme.SURFACE_DIM, UiTheme.LINE, 16.0), pad)


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
		draw_product(_anim["item"], c + Vector2(t * (rect.size.x * 0.6), 0), pad.size * (1.0 - 0.15 * maxf(0.0, 1.0 - t * 6.0)))
		var ck := Color(0.3, 1.0, 0.4, 1.0 - t)
		draw_line(c + Vector2(-26, 0), c + Vector2(-8, 20), ck, 8.0)
		draw_line(c + Vector2(-8, 20), c + Vector2(28, -24), ck, 8.0)
	else:
		var bin := Vector2(rect.position.x + 50, rect.end.y - 120)
		draw_product(_anim["item"], c.lerp(bin, t) + Vector2(0, t * t * 40.0), pad.size * (1.0 - 0.5 * t))
		if not Sprites.draw_named(self, "reject_bin", Rect2(bin + Vector2(-34, 30), Vector2(68, 50)).grow(8.0)):
			draw_rect(Rect2(bin + Vector2(-34, 30), Vector2(68, 50)), Color(0.3, 0.2, 0.2))


func _draw_feel(pad: Rect2, q: Array) -> void:
	if feel == null:
		return
	var c := pad.get_center()
	if feel.flash_t > 0.0:
		var col := feel.flash_color
		col.a = clampf(feel.flash_t / 0.35, 0.0, 1.0) * 0.45
		draw_rect(pad, col)
	if feel.gold_t > 0.0 and not q.is_empty():
		var g := Color(1.0, 0.82, 0.2, clampf(feel.gold_t / 0.9, 0.0, 1.0))
		draw_rect(Rect2(c - pad.size * 0.45, pad.size * 0.9), g, false, 5.0)
	if feel.stamp_t > 0.0:
		var k := feel.stamp_t / 0.3
		var ink := Color(0.2, 0.8, 0.35, k) if feel.stamp_ship else Color(0.9, 0.2, 0.2, k)
		var r := pad.size.x * (0.18 + 0.12 * k)
		draw_arc(c, r, 0.0, TAU, 32, ink, 5.0)
		_text("SHIP" if feel.stamp_ship else "REJECT", c + Vector2(-r * 0.7, 8.0), 22, ink, r * 1.4)
	if feel.caught_t > 0.0:
		var pk := 1.0 + feel.caught_t / 0.7 * 0.4
		draw_set_transform(pad.position + Vector2(pad.size.x * 0.5 - 60.0, -6.0), 0.0, Vector2(pk, pk))
		_text("CAUGHT", Vector2.ZERO, 34, Color(1.0, 0.9, 0.3, clampf(feel.caught_t / 0.3, 0.0, 1.0)), 140.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_flashes(pad: Rect2) -> void:
	var y := pad.position.y + 30.0
	for fl in _flashes:
		var a := clampf(float(fl["left"]) / 0.4, 0.0, 1.0)
		var col: Color = fl["color"]
		col.a = a
		_text(String(fl["text"]), Vector2(rect.position.x + 16, y), 30, col, rect.size.x - 32)
		y += 38.0


func _draw_hint() -> void:
	var r := toast_rect()
	draw_style_box(UiTheme.box(UiTheme.SURFACE_2, UiTheme.LINE, 12.0), r)
	var lines := hint.split("\n")
	var y := r.position.y + r.size.y * 0.5 - float(lines.size() - 1) * 13.0 + 6.0
	for line in lines:
		_text(line, Vector2(r.position.x + 12.0, y), T_SM, UiTheme.TEXT, r.size.x - 24.0)
		y += 26.0


func _draw_swipe_labels() -> void:
	var r := toast_rect()
	var y := r.get_center().y + 7.0
	_text("Swipe left: reject", Vector2(r.position.x + 4.0, y), T_SM, UiTheme.TEXT_FAINT, r.size.x * 0.5)
	var w := _font.get_string_size("Swipe right: ship", HORIZONTAL_ALIGNMENT_LEFT, -1, T_SM).x
	_text("Swipe right: ship", Vector2(r.end.x - w - 4.0, y), T_SM, UiTheme.TEXT_FAINT, w + 4.0)


## The defect that is drawn: a subtle one looks fine until scanned.
static func shown_defect(item: Dictionary) -> String:
	if bool(item.get("subtle", false)) and not bool(item.get("scanned", false)):
		return ""
	if bool(item.get("back", false)) and not bool(item.get("flipped", false)):
		return ""
	return String(item.get("defect", ""))


## Draw one product centred at c, fitting in a square of size s. Used for the pad and animations.
func draw_product(item: Dictionary, c: Vector2, s: Vector2) -> void:
	var w := s.x * 0.9
	var h := s.y * 0.75
	var body := Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h))
	var defect := shown_defect(item)
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
