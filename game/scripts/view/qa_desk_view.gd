class_name QaDeskView
extends Node2D
## The QA desk strip: queue, front product on a pad, BRB sign, streak, flashes. Reads sim state only.

const COL_BODY := ProductArt.COL_BODY

var factory: Factory
var ui: OfficeHud  # scene with the queue row, spec chip, toast and buttons
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


## Scene-laid-out rects (office_hud.tscn), in this view's space.
func queue_rect() -> Rect2:
	return ui.rect_of(ui.queue_row)


func streak_rect() -> Rect2:
	return ui.rect_of(ui.streak_pill)


func spec_rect() -> Rect2:
	return ui.rect_of(ui.spec_chip)


func toast_rect() -> Rect2:
	return ui.rect_of(ui.toast)


## The product pad: a square centred in the scene's Pad control.
func pad_rect() -> Rect2:
	var r := ui.rect_of(ui.pad)
	var s := minf(r.size.x, r.size.y)
	return Rect2(r.get_center() - Vector2(s, s) * 0.5, Vector2(s, s))


func _process(d: float) -> void:
	_time += d
	if feel != null:
		position = feel.shake_offset()
	for fl in _flashes:
		fl["left"] -= d
	_flashes = _flashes.filter(func(fl: Dictionary) -> bool: return fl["left"] > 0.0)
	_slide = maxf(0.0, _slide - d * 4.0)
	if ui != null and factory != null:
		var pop := 1.0 + (feel.pop_t / 0.25 * 0.2 if feel != null else 0.0)
		ui.refresh(factory, feel.streak if feel != null else factory.streak, pop, spec_new, caption, hint, BASE_RULE)
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
	var pad := pad_rect()
	_draw_pad(pad)
	var shake := 0.0
	if not _anim.is_empty() and _anim["kind"] == "reject":
		shake = sin(float(_anim["t"]) * 40.0) * 6.0 * (1.0 - float(_anim["t"]))
	if not q.is_empty() and _anim.is_empty():
		draw_product(q[0], pad.get_center() + Vector2(shake, 0), pad.size)
	_draw_anim(pad)
	_draw_feel(pad, q)
	if brb_visible():
		_draw_brb(pad)
	_draw_flashes(pad)


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


## The defect that is drawn: a subtle one looks fine until scanned.
static func shown_defect(item: Dictionary) -> String:
	if bool(item.get("subtle", false)) and not bool(item.get("scanned", false)):
		return ""
	if bool(item.get("back", false)) and not bool(item.get("flipped", false)):
		return ""
	return String(item.get("defect", ""))


## Draw one product centred at c, fitting in a square of size s. Used for the pad and animations.
func draw_product(item: Dictionary, c: Vector2, s: Vector2) -> void:
	var bot := String(item.get("bot", ""))
	ProductArt.draw(self, item, c, s, _bot_color(bot) if bot != "" else Color.WHITE)


func _text(s: String, pos: Vector2, size: int, col: Color, width: float) -> void:
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, width, size, col)
