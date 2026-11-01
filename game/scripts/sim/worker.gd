class_name Worker
extends RefCounted
## Where the QA worker is: at the office desk, on the factory floor, or on the stairs between them.
## On the floor the worker has a position (layout units) and walks at walk_speed.
## Pure sim state; Factory owns one and steps it once per tick.

enum Location { OFFICE, FLOOR, TRANSIT }

var location: Location = Location.OFFICE
var target: Location = Location.OFFICE  # destination; on FLOOR, OFFICE means walking to the stairs to leave
var trip_ticks: int = 1  # ticks per stairs trip
var trips: int = 0  # stairs trips started this shift
var ticks_in: Dictionary = {Location.OFFICE: 0, Location.FLOOR: 0, Location.TRANSIT: 0}
var walk_ticks: int = 0  # ticks spent walking on the floor this shift
var stairs := Vector2.ZERO
var floor_pos := Vector2.ZERO  # layout units; at the stairs when not on the floor
var speed: float = 0.0  # layout units per tick (<= 0: walking is instant)

var _left: int = 0  # ticks until arrival (stairs trip)
var _walk_from := Vector2.ZERO
var _walk_to := Vector2.ZERO
var _walk_total: int = 0
var _walk_done: int = 0


func _init(p_trip_ticks: int = 1, p_stairs: Vector2 = Vector2.ZERO, p_speed_per_tick: float = 0.0) -> void:
	trip_ticks = maxi(0, p_trip_ticks)
	stairs = p_stairs
	floor_pos = p_stairs
	speed = p_speed_per_tick


## Head to dest. Returns true if the worker is now at or heading to dest.
## Leaving the floor walks to the stairs first; turning back on the stairs takes as long as the distance climbed.
func go(dest: Location) -> bool:
	if target == dest:
		return true
	target = dest
	if location == Location.TRANSIT:
		_left = trip_ticks - _left
		trips += 1
		if _left <= 0:
			_arrive()
	elif location == Location.FLOOR:
		if dest == Location.FLOOR:  # changed mind on the way to the stairs: stop here
			_walk_total = _walk_done
			_walk_from = floor_pos
			return true
		walk_to(stairs)  # trip starts at the stairs
		if not is_walking():
			_start_trip()
	else:
		_start_trip()  # office -> floor
	return true


## Walk on the floor to p (layout units). Ignored off the floor.
func walk_to(p: Vector2) -> void:
	if location != Location.FLOOR:
		return
	_walk_from = floor_pos
	_walk_to = p
	_walk_done = 0
	_walk_total = walk_ticks_to(p)
	if _walk_total == 0:
		floor_pos = p


## Ticks a walk from the current position to p takes: ceil(distance / speed).
func walk_ticks_to(p: Vector2) -> int:
	var d := floor_pos.distance_to(p)
	if speed <= 0.0 or d <= 0.0:
		return 0
	return maxi(1, ceili(d / speed - 1e-6))


func is_walking() -> bool:
	return location == Location.FLOOR and _walk_done < _walk_total


## Floor position alpha (0..1) of a tick ahead, for smooth drawing.
func floor_pos_at(alpha: float) -> Vector2:
	if not is_walking():
		return floor_pos
	return _walk_from.lerp(_walk_to, minf(1.0, (float(_walk_done) + alpha) / float(_walk_total)))


## Ticks left until the stairs trip ends (0 when not in transit).
func ticks_left() -> int:
	return _left if location == Location.TRANSIT else 0


## One tick: count where the worker spent it, then move.
func step() -> void:
	ticks_in[location] += 1
	if location == Location.TRANSIT:
		_left -= 1
		if _left <= 0:
			_arrive()
	elif is_walking():
		walk_ticks += 1
		_walk_done += 1
		floor_pos = _walk_from.lerp(_walk_to, float(_walk_done) / float(_walk_total))
		if _walk_done >= _walk_total and target == Location.OFFICE:
			_start_trip()


## Teleport (tests and setup only; not recorded, takes no time).
func place(loc: Location) -> void:
	location = loc
	target = loc
	_left = 0
	_walk_total = 0
	_walk_done = 0
	floor_pos = stairs


func _start_trip() -> void:
	_walk_total = 0
	_walk_done = 0
	floor_pos = stairs
	trips += 1
	_left = trip_ticks
	location = Location.TRANSIT
	if _left <= 0:
		_arrive()


func _arrive() -> void:
	_left = 0
	location = target
	floor_pos = stairs
