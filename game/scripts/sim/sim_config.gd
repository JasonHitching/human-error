class_name SimConfig
extends RefCounted

const MACHINES_PATH := "res://data/factory_m0.json"
const BALANCE_PATH := "res://data/balance.json"
const TYPES := ["generator", "processor", "assembler", "warehouse"]

var tick_rate: int = 10
var shift_seconds: float = 180.0
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
