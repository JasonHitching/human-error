class_name BotView
extends RefCounted
## Code-drawn wheeled robot: body box, head, one wheel, mood eye. Cosmetic only.
## Draws with explicitly transformed points: never uses draw_set_transform, whose
## state leaked into everything drawn afterwards on the web renderer (#61 follow-up).

const HALF := 20.0  # drawn extent from the centre, for bounds checks


## Draw a bot centred at pos. bot_name (lower-cased) selects an optional sprite. mood: 0 normal, 1 panic. squash: 0..1 (mistake), roll: -1..1 lean.
static func draw(ci: CanvasItem, pos: Vector2, col: Color, mood: int, t: float, squash: float, roll: float, bot_name: String = "") -> void:
	var tilt := squash * 0.35 + roll * 0.08
	var sc := Vector2(1.0 + squash * 0.25, 1.0 - squash * 0.25)
	var xf := Transform2D(tilt, sc, 0.0, pos)
	# Build the list with append(): assigning an inline if/else of untyped arrays to an
	# Array[String] is a runtime error in the exported build and aborted this whole function.
	var names: Array[String] = []
	if mood == 1:
		names.append("bot_" + bot_name + "_panic")
	names.append("bot_" + bot_name)
	if bot_name != "":
		# Sprites are drawn upright (no tilt) so no canvas transform is needed.
		var s := HALF * 2.4 * sc
		if Sprites.draw_fit(ci, Sprites.first(names), Rect2(pos - s * 0.5, s)):
			return
	var dark := col.darkened(0.4)
	var k := (sc.x + sc.y) * 0.5
	ci.draw_circle(xf * Vector2(0, 12), 8.0 * k, Color(0.12, 0.12, 0.14))  # wheel
	ci.draw_circle(xf * Vector2(0, 12), 3.0 * k, Color(0.6, 0.6, 0.65))
	_box(ci, xf, Rect2(-12, -6, 24, 16), col, dark)  # body
	_box(ci, xf, Rect2(-9, -18, 18, 12), col.lightened(0.15), dark)  # head
	ci.draw_line(xf * Vector2(0, -18), xf * Vector2(0, -23), dark, 2.0)  # antenna
	if mood == 1:
		ci.draw_circle(xf * Vector2(0, -12), 5.0 * k, Color.WHITE)
		ci.draw_circle(xf * Vector2(0, -12), 2.5 * k, Color(0.9, 0.1, 0.1))
	else:
		ci.draw_circle(xf * Vector2(0, -12), 3.0 * k, Color(0.2, 0.9, 0.5))


static func _box(ci: CanvasItem, xf: Transform2D, r: Rect2, fill: Color, outline: Color) -> void:
	var pts := PackedVector2Array([xf * r.position, xf * Vector2(r.end.x, r.position.y), xf * r.end, xf * Vector2(r.position.x, r.end.y)])
	ci.draw_colored_polygon(pts, fill)
	var loop := pts.duplicate()
	loop.append(pts[0])
	ci.draw_polyline(loop, outline, 2.0)
