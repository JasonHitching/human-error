class_name Dialogue
extends RefCounted
## Foreman and bot lines (data/dialogue.json). Picks use a caller-supplied seeded RNG.

const PATH := "res://data/dialogue.json"

var data: Dictionary = {}


func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		data = parsed


## Lines for a bot's clock-in ([] if none).
func bot_lines(bot: String) -> Array:
	var all: Dictionary = data.get("bot_clock_in", {})
	return all.get(bot, [])


func foreman_lines(kind: String, key: String = "") -> Array:
	var v: Variant = data.get(kind, [])
	if v is Dictionary:
		return (v as Dictionary).get(key, [])
	return v as Array


static func pick(lines: Array, rng: RandomNumberGenerator) -> String:
	return "" if lines.is_empty() else String(lines[rng.randi_range(0, lines.size() - 1)])
