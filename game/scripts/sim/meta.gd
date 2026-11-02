class_name Meta
extends RefCounted
## Durable meta-progression data (pure, no IO). Persisted by SaveIO as user://save.json.

const VERSION := 1
const COMMENDATIONS_PATH := "res://data/commendations.json"

var version: int = VERSION
var stats: RunStats = RunStats.new()
var commendations: Dictionary = {}  # "balance" (spendable) and "earned" (lifetime), see award()
var unlocked: Array = []  # unlocked perk/unlock ids
var tier: int = 1


func to_dict() -> Dictionary:
	return {
		"version": version, "stats": stats.to_dict(), "commendations": commendations,
		"unlocked": unlocked, "tier": tier,
	}


static func from_dict(d: Dictionary) -> Meta:
	var m := Meta.new()
	m.version = VERSION
	var st: Variant = d.get("stats", {})
	if st is Dictionary:
		m.stats.apply_dict(st as Dictionary)
	var c: Variant = d.get("commendations", {})
	if c is Dictionary:
		m.commendations = (c as Dictionary).duplicate(true)
	var u: Variant = d.get("unlocked", [])
	if u is Array:
		for v: Variant in u:
			m.unlocked.append(str(v))
	m.tier = maxi(1, int(d.get("tier", 1)))
	return m


## Legacy v0: a bare stats.json dictionary.
static func from_legacy_stats(d: Dictionary) -> Meta:
	return from_dict({"stats": d})


func balance() -> int:
	return int(commendations.get("balance", 0))


static func load_commendation_rules(path: String = COMMENDATIONS_PATH) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


## Pure scoring of a career summary {days, clean_shifts, best_streak, lessons, twist_days}.
## Returns {total, lines[]}; does not touch Meta.
static func score(summary: Dictionary, rules: Dictionary) -> Dictionary:
	var lines: Array[String] = []
	var total := 0
	var texts: Dictionary = rules.get("lines", {})
	var every := maxi(1, int(rules.get("streak_every", 3)))
	var parts := [
		["days", int(summary.get("days", 0)), int(rules.get("per_day", 0))],
		["clean", int(summary.get("clean_shifts", 0)), int(rules.get("per_clean_shift", 0))],
		["streak", int(summary.get("best_streak", 0)), 0],
		["lessons", int(summary.get("lessons", 0)), int(rules.get("per_lesson", 0))],
		["twists", int(summary.get("twist_days", 0)), int(rules.get("per_twist_day", 0))],
	]
	for p: Array in parts:
		var n: int = p[1]
		var pts: int = p[2] * n
		if p[0] == "streak":
			pts = int(rules.get("per_streak_milestone", 0)) * (n / every)
		if pts <= 0:
			continue
		total += pts
		lines.append(String(texts.get(p[0], "{n} x: +{pts}")).replace("{n}", str(n)).replace("{pts}", str(pts)))
	return {"total": total, "lines": lines}


## Awards a finished career: adds to the balance and lifetime total. Caller saves.
func award(summary: Dictionary, rules: Dictionary = {}) -> Dictionary:
	var r := score(summary, rules if not rules.is_empty() else load_commendation_rules())
	commendations["balance"] = balance() + int(r["total"])
	commendations["earned"] = int(commendations.get("earned", 0)) + int(r["total"])
	return r
