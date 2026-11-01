class_name SimConfig
extends RefCounted

const MACHINES_PATH := "res://data/factory_m0.json"
const BALANCE_PATH := "res://data/balance.json"
const TYPES := ["generator", "processor", "assembler", "warehouse"]

var tick_rate: int = 10
var shift_seconds: float = 180.0
var target: int = 100
var ramp_start: float = 1.0
var ramp_end: float = 1.0
var repair_seconds: float = 2.0
var vent_seconds: float = 1.0
var vent_min_heat: float = 50.0
var vent_cool_per_sec: float = 40.0
var repair_mode: String = "tap"  # "tap" or "hold"
var machines: Array[Dictionary] = []
var links: Array[Dictionary] = []
var errors: Array[String] = []


func is_valid() -> bool:
	return errors.is_empty()


static func load_default() -> SimConfig:
	return from_dicts(_read(MACHINES_PATH), _read(BALANCE_PATH))


static func _read(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {"__error": "cannot read or parse %s" % path}


static func from_dicts(factory: Dictionary, balance: Dictionary) -> SimConfig:
	var c := SimConfig.new()
	for d: Dictionary in [factory, balance]:
		if d.has("__error"):
			c.errors.append(String(d["__error"]))
	if not c.is_valid():
		return c
	c._load_balance(balance)
	c._load_factory(factory)
	return c


func _load_balance(b: Dictionary) -> void:
	if not (b.get("tick_rate") is float or b.get("tick_rate") is int) or int(b["tick_rate"]) <= 0:
		errors.append("balance: tick_rate must be a positive number")
	else:
		tick_rate = int(b["tick_rate"])
	if not (b.get("shift_seconds") is float or b.get("shift_seconds") is int) or float(b["shift_seconds"]) <= 0.0:
		errors.append("balance: shift_seconds must be a positive number")
	else:
		shift_seconds = float(b["shift_seconds"])
	target = int(_num(b, "target", 0.0, 1.0e9))
	ramp_start = _num(b, "ramp_start", 0.0, 100.0)
	ramp_end = _num(b, "ramp_end", 0.0, 100.0)
	repair_seconds = _num(b, "repair_seconds", 0.1, 1.0e4)
	vent_seconds = _num(b, "vent_seconds", 0.1, 1.0e4)
	vent_min_heat = _num(b, "vent_min_heat", 0.0, 100.0)
	vent_cool_per_sec = _num(b, "vent_cool_per_sec", 0.0, 1.0e4)
	repair_mode = String(b.get("repair_mode", ""))
	if repair_mode != "tap" and repair_mode != "hold":
		errors.append("balance: repair_mode must be \"tap\" or \"hold\"")


func _num(d: Dictionary, key: String, lo: float, hi: float) -> float:
	var v: Variant = d.get(key)
	if not (v is float or v is int) or float(v) < lo or float(v) > hi:
		errors.append("balance: %s must be a number in [%s, %s]" % [key, lo, hi])
		return lo
	return float(v)


func _load_factory(f: Dictionary) -> void:
	var ids := {}
	for m: Variant in f.get("machines", []):
		if not (m is Dictionary):
			errors.append("factory: machine entry is not an object")
			continue
		var md: Dictionary = m
		var id := String(md.get("id", ""))
		if id == "" or ids.has(id):
			errors.append("factory: machine id missing or duplicate: '%s'" % id)
			continue
		if not TYPES.has(String(md.get("type", ""))):
			errors.append("factory: machine '%s' has unknown type '%s'" % [id, md.get("type")])
		var pos: Variant = md.get("pos")
		if not (pos is Array) or (pos as Array).size() != 2:
			errors.append("factory: machine '%s' needs pos [x, y]" % id)
		if float(md.get("process_time", 0.0)) <= 0.0:
			errors.append("factory: machine '%s' needs process_time > 0" % id)
		ids[id] = true
		machines.append(md)
	if machines.is_empty():
		errors.append("factory: no machines")
	for l: Variant in f.get("links", []):
		if not (l is Dictionary):
			errors.append("factory: link entry is not an object")
			continue
		var ld: Dictionary = l
		if not ids.has(String(ld.get("from", ""))) or not ids.has(String(ld.get("to", ""))):
			errors.append("factory: link %s -> %s references unknown machine" % [ld.get("from"), ld.get("to")])
		elif float(ld.get("transit_time", -1.0)) < 0.0:
			errors.append("factory: link %s -> %s needs transit_time >= 0" % [ld["from"], ld["to"]])
		else:
			links.append(ld)
