class_name FloorCamera
extends RefCounted
## Pan/zoom model for the isometric floor (pure maths, no Nodes). Same semantics as a Camera2D:
## `center` is the world point at the middle of the view, `zoom` is world px -> screen px.
## The centre is clamped so the view stays inside `bounds` (factory extent + margin).

const MIN_ZOOM := 0.3
const MAX_ZOOM := 2.0
const START_ZOOM := 1.0  # opening zoom: machines readable, factory extends past the screen
const MARGIN := 80.0
const READABLE_FIT := 0.4  # smallest whole-factory zoom that still reads (small layouts open at it)
const KEY_PAN := 420.0  # screen px per second
const KEY_ZOOM := 1.6  # zoom factor per second

var view := Vector2(390, 700)  # screen size of the floor area
var bounds := Rect2(0, 0, 400, 400)
var center := Vector2(200, 200)
var zoom: float = 1.0
const FOCUS_TIME := 0.45
const FOCUS_ZOOM := 0.9  # focus zooms in to at least this
var moving := false
var _from_c := Vector2.ZERO
var _to_c := Vector2.ZERO
var _from_z: float = 1.0
var _to_z: float = 1.0
var _t: float = 1.0
var _dur: float = FOCUS_TIME


func set_bounds(content: Rect2) -> void:
	bounds = content.grow(MARGIN)
	_clamp()


func set_view(size: Vector2) -> void:
	view = size
	_clamp()


## Zoom that fits the content width/height (the overview; not the starting zoom).
func fit_zoom(content: Rect2) -> float:
	var c := content.grow(MARGIN)  # room for fixed-size badges at the edges
	return clampf(minf(view.x / c.size.x, view.y / c.size.y), MIN_ZOOM, MAX_ZOOM)


## Starting zoom: a readable close-up, never the squashed whole-factory overview.
func start_zoom() -> float:
	return clampf(START_ZOOM, MIN_ZOOM, MAX_ZOOM)


## Opening zoom for a layout: a small factory opens showing all of it (when that is still readable),
## a big one opens at the close-up start zoom.
func opening_zoom(content: Rect2) -> float:
	var fit := fit_zoom(content)
	return minf(fit, start_zoom()) if fit >= READABLE_FIT else start_zoom()


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


## Start a smooth move that ends with world point `target` at the middle of `safe` (view coords).
## Zoom only ever goes in, up to FOCUS_ZOOM, never out. Any user input should call cancel().
func focus_on(target: Vector2, safe: Rect2, dur: float = FOCUS_TIME) -> void:
	_from_c = center
	_from_z = zoom
	_to_z = clampf(maxf(zoom, FOCUS_ZOOM), MIN_ZOOM, MAX_ZOOM)
	zoom = _to_z  # solve the end centre at the end zoom, then restore
	center = target - (safe.get_center() - view * 0.5) / zoom
	_clamp()
	_to_c = center
	zoom = _from_z
	center = _from_c
	_t = 0.0
	_dur = maxf(dur, 0.001)
	moving = true


## Advance a running move by `d` seconds (smoothstep ease).
func step(d: float) -> void:
	if not moving:
		return
	_t = minf(_t + d / _dur, 1.0)
	var k := _t * _t * (3.0 - 2.0 * _t)
	zoom = lerpf(_from_z, _to_z, k)
	center = _from_c.lerp(_to_c, k)
	_clamp()
	if _t >= 1.0:
		moving = false


func cancel() -> void:
	moving = false


func _clamp() -> void:
	var half := view / (2.0 * zoom)
	center.x = bounds.get_center().x if bounds.size.x <= half.x * 2.0 else clampf(center.x, bounds.position.x + half.x, bounds.end.x - half.x)
	center.y = bounds.get_center().y if bounds.size.y <= half.y * 2.0 else clampf(center.y, bounds.position.y + half.y, bounds.end.y - half.y)
