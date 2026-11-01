class_name SimConfig
extends RefCounted

const MACHINES_PATH := "res://data/factory_m0.json"
const BOTS_PATH := "res://data/bots.json"
const BALANCE_PATH := "res://data/balance.json"
const TYPES := ["generator", "processor", "assembler", "qa", "warehouse"]

var tick_rate: int = 10
var shift_seconds: float = 180.0
var target: int = 100
var ramp_start: float = 1.0
var ramp_end: float = 1.0
var repair_seconds: float = 2.0
var vent_seconds: float = 1.0
var vent_min_heat: float = 50.0
var vent_cool_per_sec: float = 40.0
var fix_seconds: float = 1.0
var clear_seconds: float = 1.5
var target_base: int = 40
var target_per_day: int = 8
var day_rate_mult: float = 1.15
var max_strikes: int = 2
var bonus_threshold: float = 1.25
var crew_speed_upgrade: float = 0.85
var offers_per_review: int = 3
var train_factor: float = 0.6
var qa_capacity: int = 8
var shelf_slots: int = 4
var probation_days: int = 1
var decoy_chance: float = 0.2
var inspect_seconds: float = 0.5
var transition_seconds: float = 0.8
var walk_speed: float = 0.0  # floor layout units per second (<= 0: instant)
var stairs := Vector2(0.08, 0.06)  # floor layout position of the stairs
var complaint_penalty: int = 3
var quick_eye_mult: float = 0.8
var bigger_desk_bonus: int = 2
var overclock_speed_mult: float = 1.3
var overclock_heat_mult: float = 3.0
var monitor_amber_heat: float = 60.0
var bot_defs: Array[Dictionary] = []
var repair_mode: String = "tap"  # "tap" or "hold"
var machines: Array[Dictionary] = []
var links: Array[Dictionary] = []
var errors: Array[String] = []


func is_valid() -> bool:
	return errors.is_empty()


static func load_default() -> SimConfig:
	return from_dicts(_read(MACHINES_PATH), _read(BALANCE_PATH), _read(BOTS_PATH))


static func _read(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {"__error": "cannot read or parse %s" % path}


static func from_dicts(factory: Dictionary, balance: Dictionary, bots: Dictionary = {}) -> SimConfig:
	var c := SimConfig.new()
	if bots.is_empty():
		bots = _read(BOTS_PATH)
	for d: Dictionary in [factory, balance, bots]:
		if d.has("__error"):
			c.errors.append(String(d["__error"]))
	if not c.is_valid():
		return c
	c._load_balance(balance)
	c._load_factory(factory)
	c._load_bots(bots)
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
	fix_seconds = _num(b, "fix_seconds", 0.1, 1.0e4) if b.has("fix_seconds") else 1.0
	clear_seconds = _num(b, "clear_seconds", 0.1, 1.0e4) if b.has("clear_seconds") else 1.5
	target_base = int(_opt(b, "target_base", target_base, 0.0, 1.0e9))
	target_per_day = int(_opt(b, "target_per_day", target_per_day, 0.0, 1.0e9))
	day_rate_mult = _opt(b, "day_rate_mult", day_rate_mult, 0.1, 10.0)
	max_strikes = int(_opt(b, "max_strikes", max_strikes, 1.0, 100.0))
	bonus_threshold = _opt(b, "bonus_threshold", bonus_threshold, 1.0, 100.0)
	crew_speed_upgrade = _opt(b, "crew_speed_upgrade", crew_speed_upgrade, 0.1, 1.0)
	offers_per_review = int(_opt(b, "offers_per_review", offers_per_review, 1.0, 20.0))
	qa_capacity = int(_opt(b, "qa_capacity", qa_capacity, 1.0, 100.0))
	shelf_slots = int(_opt(b, "shelf_slots", shelf_slots, 0.0, 50.0))
	probation_days = int(_opt(b, "probation_days", probation_days, 0.0, 100.0))
	decoy_chance = _opt(b, "decoy_chance", decoy_chance, 0.0, 1.0)
	inspect_seconds = _opt(b, "inspect_seconds", inspect_seconds, 0.1, 100.0)
	transition_seconds = _opt(b, "transition_seconds", transition_seconds, 0.0, 100.0)
	walk_speed = _opt(b, "walk_speed", walk_speed, 0.0, 100.0)
	complaint_penalty = int(_opt(b, "complaint_penalty", complaint_penalty, 0.0, 1000.0))
	quick_eye_mult = _opt(b, "quick_eye_mult", quick_eye_mult, 0.1, 1.0)
	bigger_desk_bonus = int(_opt(b, "bigger_desk_bonus", bigger_desk_bonus, 1.0, 100.0))
	monitor_amber_heat = _opt(b, "monitor_amber_heat", monitor_amber_heat, 0.0, 100.0)
	repair_mode = String(b.get("repair_mode", ""))
	if repair_mode != "tap" and repair_mode != "hold":
		errors.append("balance: repair_mode must be \"tap\" or \"hold\"")


func _opt(d: Dictionary, key: String, dflt: Variant, lo: float, hi: float) -> float:
	return _num(d, key, lo, hi) if d.has(key) else float(dflt)


func _num(d: Dictionary, key: String, lo: float, hi: float) -> float:
	var v: Variant = d.get(key)
	if not (v is float or v is int) or float(v) < lo or float(v) > hi:
		errors.append("balance: %s must be a number in [%s, %s]" % [key, lo, hi])
		return lo
	return float(v)


func _load_factory(f: Dictionary) -> void:
	var ids := {}
	var st: Variant = f.get("stairs", [stairs.x, stairs.y])
	if st is Array and (st as Array).size() == 2:
		stairs = Vector2(float(st[0]), float(st[1]))
	else:
		errors.append("factory: stairs needs [x, y]")
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


func _load_bots(b: Dictionary) -> void:
	var bal: Dictionary = b.get("balance", {})
	train_factor = float(bal.get("train_factor", 0.6))
	overclock_speed_mult = float(bal.get("overclock_speed_mult", 1.3))
	overclock_heat_mult = float(bal.get("overclock_heat_mult", 3.0))
	if train_factor < 0.0 or train_factor > 1.0 or overclock_speed_mult < 1.0 or overclock_heat_mult < 1.0:
		errors.append("bots: bad balance values")
	var names := {}
	for e: Variant in b.get("bots", []):
		if not (e is Dictionary):
			errors.append("bots: entry is not an object")
			continue
		var d: Dictionary = e
		var n := String(d.get("name", ""))
		if n == "" or names.has(n):
			errors.append("bots: name missing or duplicate: '%s'" % n)
			continue
		names[n] = true
		var rates: Variant = d.get("rates")
		if not (rates is Dictionary):
			errors.append("bots: '%s' needs rates" % n)
			continue
		for k: String in Bot.MISTAKES:
			var v: Variant = (rates as Dictionary).get(k)
			if not (v is float or v is int) or float(v) < 0.0:
				errors.append("bots: '%s' rate '%s' must be a number >= 0" % [n, k])
		var sl: Variant = d.get("sloppy", 0.0)
		if not (sl is float or sl is int) or float(sl) < 0.0 or float(sl) > 1.0:
			errors.append("bots: '%s' sloppy must be a number in [0, 1]" % n)
		bot_defs.append(d)
	if bot_defs.is_empty():
		errors.append("bots: roster is empty")
