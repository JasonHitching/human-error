class_name FloorCamera
extends RefCounted
## Pan/zoom model for the isometric floor (pure maths, no Nodes). Same semantics as a Camera2D:
## `center` is the world point at the middle of the view, `zoom` is world px -> screen px.
## The centre is clamped so the view stays inside `bounds` (factory extent + margin).

const MIN_ZOOM := 0.5
const MAX_ZOOM := 2.0
const MARGIN := 80.0
const KEY_PAN := 420.0  # screen px per second
const KEY_ZOOM := 1.6  # zoom factor per second

var view := Vector2(390, 700)  # screen size of the floor area
var bounds := Rect2(0, 0, 400, 400)
var center := Vector2(200, 200)
var zoom: float = 1.0


func set_bounds(content: Rect2) -> void:
	bounds = content.grow(MARGIN)
	_clamp()


func set_view(size: Vector2) -> void:
	view = size
	_clamp()


## Zoom that fits the content width/height (used only as the starting zoom).
func fit_zoom(content: Rect2) -> float:
	return clampf(minf(view.x / content.size.x, view.y / content.size.y), MIN_ZOOM, MAX_ZOOM)


func reset(content: Rect2, z: float) -> void:
	set_bounds(content)
	zoom = clampf(z, MIN_ZOOM, MAX_ZOOM)
	center = content.get_center()
	_clamp()


func pan_screen(delta: Vector2) -> void:
	center -= delta / zoom
	_clamp()


## Zoom by `factor`, keeping the world point under screen point `at` (relative to the view origin) fixed.
func zoom_at(factor: float, at: Vector2) -> void:
	var before := screen_to_world(at)
	zoom = clampf(zoom * factor, MIN_ZOOM, MAX_ZOOM)
	center += before - screen_to_world(at)
	_clamp()


func world_to_screen(p: Vector2) -> Vector2:
	return (p - center) * zoom + view * 0.5


func screen_to_world(p: Vector2) -> Vector2:
	return (p - view * 0.5) / zoom + center


func _clamp() -> void:
	var half := view / (2.0 * zoom)
	center.x = bounds.get_center().x if bounds.size.x <= half.x * 2.0 else clampf(center.x, bounds.position.x + half.x, bounds.end.x - half.x)
	center.y = bounds.get_center().y if bounds.size.y <= half.y * 2.0 else clampf(center.y, bounds.position.y + half.y, bounds.end.y - half.y)
