class_name BotView
extends RefCounted
## Code-drawn wheeled robot: body box, head, one wheel, mood eye. Cosmetic only.

const HALF := 20.0  # drawn extent from the centre, for bounds checks


## Draw a bot centred at pos. bot_name (lower-cased) selects an optional sprite. mood: 0 normal, 1 panic. squash: 0..1 (mistake), roll: -1..1 lean.
static func draw(ci: CanvasItem, pos: Vector2, col: Color, mood: int, t: float, squash: float, roll: float, bot_name: String = "") -> void:
	var tilt := squash * 0.35 + roll * 0.08
	var sc := Vector2(1.0 + squash * 0.25, 1.0 - squash * 0.25)
	ci.draw_set_transform(pos, tilt, sc)
	var names: Array[String] = ["bot_" + bot_name + "_panic", "bot_" + bot_name] if mood == 1 else ["bot_" + bot_name]
	if bot_name != "" and Sprites.draw_fit(ci, Sprites.first(names), Rect2(-HALF * 1.2, -HALF * 1.2, HALF * 2.4, HALF * 2.4)):
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var dark := col.darkened(0.4)
	ci.draw_circle(Vector2(0, 12), 8.0, Color(0.12, 0.12, 0.14))  # wheel
	ci.draw_circle(Vector2(0, 12), 3.0, Color(0.6, 0.6, 0.65))
	ci.draw_rect(Rect2(-12, -6, 24, 16), col)  # body
	ci.draw_rect(Rect2(-12, -6, 24, 16), dark, false, 2.0)
	ci.draw_rect(Rect2(-9, -18, 18, 12), col.lightened(0.15))  # head
	ci.draw_rect(Rect2(-9, -18, 18, 12), dark, false, 2.0)
	ci.draw_line(Vector2(0, -18), Vector2(0, -23), dark, 2.0)  # antenna
	if mood == 1:
		var shake := sin(t * 40.0) * 1.2
		ci.draw_circle(Vector2(shake, -12), 5.0, Color.WHITE)
		ci.draw_circle(Vector2(shake, -12), 2.5, Color(0.9, 0.1, 0.1))
	else:
		ci.draw_circle(Vector2(0, -12), 3.0, Color(0.2, 0.9, 0.5))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
