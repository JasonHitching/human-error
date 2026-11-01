class_name Twists
extends RefCounted
## Shift twists: one per day from twist_start_day, picked with a seeded RNG, never the same twice running.

const PATH := "res://data/twists.json"

var defs: Array[Dictionary] = []
var _seed: int = 0
var _start_day: int = 3
var _cache: Dictionary = {}  # day -> twist id


func _init(p_seed: int, start_day: int) -> void:
	_seed = p_seed
	_start_day = start_day
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		for t: Variant in (parsed as Dictionary).get("twists", []):
			if t is Dictionary:
				defs.append(t)


## The twist for a day ({} on days before the start day). Deterministic per seed and day.
func for_day(day: int) -> Dictionary:
	var id := _id_for(day)
	return get_def(id)


func get_def(id: String) -> Dictionary:
	for t in defs:
		if t["id"] == id:
			return t
	return {}


func _id_for(day: int) -> String:
	if day < _start_day or defs.is_empty():
		return ""
	if _cache.has(day):
		return _cache[day]
	var prev := _id_for(day - 1)
	var r := RandomNumberGenerator.new()
	r.seed = _seed * 104729 + day * 7919
	var pool: Array[String] = []
	for t in defs:
		if t["id"] != prev:
			pool.append(String(t["id"]))
	var id := pool[r.randi_range(0, pool.size() - 1)]
	_cache[day] = id
	return id
