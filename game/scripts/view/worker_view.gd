class_name WorkerView
extends RefCounted
## Code-drawn QA worker: the only character with legs. Cosmetic only.

const HALF := 22.0  # drawn extent from the centre, for bounds checks


## Draw the worker centred at pos. walking: 2-frame leg swing. working: wrench wiggle.
static func draw(ci: CanvasItem, pos: Vector2, t: float, walking: bool, working: bool) -> void:
	var skin := Color(0.95, 0.78, 0.6)
	var swing := 0.0
	if walking:
		swing = 6.0 if int(t * 8.0) % 2 == 0 else -6.0
	ci.draw_line(pos + Vector2(-4, 6), pos + Vector2(-4 + swing, 20), Color(0.2, 0.25, 0.5), 4.0)  # legs
	ci.draw_line(pos + Vector2(4, 6), pos + Vector2(4 - swing, 20), Color(0.2, 0.25, 0.5), 4.0)
	ci.draw_rect(Rect2(pos + Vector2(-8, -8), Vector2(16, 16)), Color(0.9, 0.5, 0.1))  # body
	var hand := pos + Vector2(14, 2)
	if working:
		hand += Vector2(sin(t * 18.0) * 4.0, cos(t * 18.0) * 4.0 - 4.0)
	ci.draw_line(pos + Vector2(8, -4), hand, skin, 3.0)  # arm
	if working:
		ci.draw_line(hand, hand + Vector2(6, -8), Color(0.7, 0.72, 0.78), 3.0)  # wrench
	ci.draw_circle(pos + Vector2(0, -15), 7.0, skin)  # head
	ci.draw_rect(Rect2(pos + Vector2(-8, -24), Vector2(16, 7)), Color(1.0, 0.9, 0.1))  # hard hat
	ci.draw_rect(Rect2(pos + Vector2(-10, -18), Vector2(20, 2)), Color(1.0, 0.9, 0.1))
