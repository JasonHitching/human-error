class_name Meta
extends RefCounted
## Durable meta-progression data (pure, no IO). Persisted by SaveIO as user://save.json.

const VERSION := 1

var version: int = VERSION
var stats: RunStats = RunStats.new()
var commendations: Dictionary = {}  # id -> count/progress (filled from M5-02)
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
