class_name Worker
extends RefCounted
## Where the QA worker is: at the office desk, on the factory floor, or walking between them.
## Pure sim state; Factory owns one and steps it once per tick.

enum Location { OFFICE, FLOOR, TRANSIT }

var location: Location = Location.OFFICE
var target: Location = Location.OFFICE  # destination while in TRANSIT; else == location
var trip_ticks: int = 1  # ticks per trip
var trips: int = 0  # trips started this shift
var ticks_in: Dictionary = {Location.OFFICE: 0, Location.FLOOR: 0, Location.TRANSIT: 0}

var _left: int = 0  # ticks until arrival


func _init(p_trip_ticks: int = 1) -> void:
	trip_ticks = maxi(0, p_trip_ticks)


## Start walking to dest. Returns true if the worker is now at or heading to dest.
## Turning back mid-trip takes as long as the distance already walked.
func go(dest: Location) -> bool:
	if target == dest:
		return true
	if location == Location.TRANSIT:
		_left = trip_ticks - _left
	else:
		_left = trip_ticks
	trips += 1
	target = dest
	location = Location.TRANSIT
	if _left <= 0:
		location = dest
	return true


## Ticks left until arrival (0 when not in transit).
func ticks_left() -> int:
	return _left if location == Location.TRANSIT else 0


## One tick: count where the worker spent it, then walk.
func step() -> void:
	ticks_in[location] += 1
	if location == Location.TRANSIT:
		_left -= 1
		if _left <= 0:
			_left = 0
			location = target


## Teleport (tests and setup only; not recorded, takes no time).
func place(loc: Location) -> void:
	location = loc
	target = loc
	_left = 0
