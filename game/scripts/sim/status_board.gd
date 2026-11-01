class_name StatusBoard
extends RefCounted
## Wall-monitor logic: a traffic light per machine, and alarms for machines that just turned RED.
## Pure sim: reads machines only, never writes them.

enum Light { GREEN, AMBER, RED }

var amber_heat: float = 60.0
var _red: Dictionary = {}  # machine id -> was RED at the last new_alarms() call
var _machines: Array[Machine] = []


func _init(machines: Array[Machine], p_amber_heat: float = 60.0) -> void:
	_machines = machines
	amber_heat = p_amber_heat


## Machines shown on the monitor (not the QA desk or warehouse).
static func is_monitored(m: Machine) -> bool:
	return m.type != "qa" and m.type != "warehouse"


func monitored() -> Array[Machine]:
	var out: Array[Machine] = []
	for m in _machines:
		if is_monitored(m):
			out.append(m)
	return out


## RED = a tap can fix it; AMBER = warning; GREEN = fine.
func machine_light(m: Machine) -> Light:
	if m.is_faulted() or m.state == Machine.State.CLOGGED or m.misrouted or m.wrong_recipe:
		return Light.RED
	if m.heat >= amber_heat or m.overclocked or m.state == Machine.State.BLOCKED:
		return Light.AMBER
	return Light.GREEN


## Machines that turned RED since the last call (each alarm is reported once per RED spell).
func new_alarms() -> Array[Machine]:
	var out: Array[Machine] = []
	for m in monitored():
		var red := machine_light(m) == Light.RED
		if red and not _red.get(m.id, false):
			out.append(m)
		_red[m.id] = red
	return out
