class_name Meta
extends RefCounted
## Durable meta-progression data (pure, no IO). Persisted by SaveIO as user://save.json.

const VERSION := 1
const COMMENDATIONS_PATH := "res://data/commendations.json"
const PERKS_PATH := "res://data/perks.json"

var version: int = VERSION
var stats: RunStats = RunStats.new()
var commendations: Dictionary = {}  # "balance" (spendable) and "earned" (lifetime), see award()
var unlocked: Array = []  # unlocked perk/unlock ids
var tier: int = 1  # highest unlocked factory tier
var picked_tier: int = 1  # tier the next career starts in
var tier_best: Dictionary = {}  # "1" -> best days in that tier
var owned_perks: Array = []  # perk ids bought with commendations
var automations: int = 0  # careers ended by being automated (the win)
var last_seen_unix: int = 0  # last time the app was seen running (night shift clock; never moves backwards)
var pending_night: Dictionary = {}  # {commendations, mess_level, lines[], collected}; {} = none


func to_dict() -> Dictionary:
	return {
		"version": version, "stats": stats.to_dict(), "commendations": commendations,
		"unlocked": unlocked, "tier": tier, "picked_tier": picked_tier, "tier_best": tier_best, "owned_perks": owned_perks, "automations": automations,
		"last_seen_unix": last_seen_unix, "pending_night": pending_night,
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
	m.tier = clampi(RunStats.to_int(d.get("tier", 1)), 1, SimConfig.MAX_TIER)
	m.picked_tier = clampi(RunStats.to_int(d.get("picked_tier", 1)), 1, m.tier)
	var tb: Variant = d.get("tier_best", {})
	if tb is Dictionary:
		for k: Variant in tb:
			var t := int(str(k))
			if t >= 1 and t <= SimConfig.MAX_TIER:
				m.tier_best[str(t)] = maxi(0, RunStats.to_int(tb[k]))
	m.automations = maxi(0, RunStats.to_int(d.get("automations", 0)))
	m.last_seen_unix = maxi(0, RunStats.to_int(d.get("last_seen_unix", 0)))
	m.pending_night = parse_night(d.get("pending_night", {}))
	var op: Variant = d.get("owned_perks", [])
	if op is Array:
		for v: Variant in op:
			if not m.owned_perks.has(str(v)):
				m.owned_perks.append(str(v))
	return m


## Corrupt-safe parse of a pending night report ({} when missing or malformed).
static func parse_night(v: Variant) -> Dictionary:
	if not v is Dictionary:
		return {}
	var d := v as Dictionary
	if not d.has("commendations") and not d.has("mess_level"):
		return {}
	var lines: Array[String] = []
	var raw: Variant = d.get("lines", [])
	if raw is Array:
		for l: Variant in raw:
			lines.append(str(l))
	return {"commendations": clampi(RunStats.to_int(d.get("commendations", 0)), 0, 1000), "mess_level": clampi(RunStats.to_int(d.get("mess_level", 0)), 0, 3), "lines": lines, "collected": d.get("collected", false) == true}


## Legacy v0: a bare stats.json dictionary.
static func from_legacy_stats(d: Dictionary) -> Meta:
	return from_dict({"stats": d})


func balance() -> int:
	return RunStats.to_int(commendations.get("balance", 0))


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
	var ab := int(summary.get("automation_bonus", 0))
	if ab > 0:
		total += ab
		lines.append(String(texts.get("automated", "Automated: the bots took your job. +{pts}")).replace("{pts}", str(ab)))
	return {"total": total, "lines": lines}


## Awards a finished career: adds to the balance and lifetime total. Caller saves.
func award(summary: Dictionary, rules: Dictionary = {}) -> Dictionary:
	var r := score(summary, rules if not rules.is_empty() else load_commendation_rules())
	commendations["balance"] = balance() + int(r["total"])
	commendations["earned"] = RunStats.to_int(commendations.get("earned", 0)) + int(r["total"])
	return r


static func load_perks(path: String = PERKS_PATH) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


static func perk_def(id: String, defs: Dictionary = {}) -> Dictionary:
	var d := defs if not defs.is_empty() else load_perks()
	for p: Variant in d.get("perks", []):
		if (p as Dictionary).get("id") == id:
			return p as Dictionary
	return {}


func owns(id: String) -> bool:
	return owned_perks.has(id)


## Buys a perk with the spendable balance. False if unknown, owned or unaffordable. Caller saves.
func buy(id: String, defs: Dictionary = {}) -> bool:
	var p := perk_def(id, defs)
	if p.is_empty() or owns(id) or balance() < int(p.get("cost", 0)):
		return false
	commendations["balance"] = balance() - int(p["cost"])
	owned_perks.append(id)
	return true


## Picks the tier the next career starts in (clamped to the unlocked tiers).
func pick_tier(t: int) -> void:
	picked_tier = clampi(t, 1, tier)


## An automation in `career_tier` unlocks the next tier.
func unlock_after(career_tier: int) -> void:
	tier = clampi(maxi(tier, career_tier + 1), 1, SimConfig.MAX_TIER)


func best_for(t: int) -> int:
	return int(tier_best.get(str(t), 0))


## Records a finished career's days for a tier. True when it is a new best there.
func note_best(t: int, days: int) -> bool:
	if days <= best_for(t):
		return false
	tier_best[str(t)] = days
	return true


## Banks the pending night's commendations (once). Returns the amount. Caller saves.
func collect_night() -> int:
	if pending_night.is_empty() or bool(pending_night.get("collected", false)):
		return 0
	var n := int(pending_night.get("commendations", 0))
	commendations["balance"] = balance() + n
	commendations["earned"] = RunStats.to_int(commendations.get("earned", 0)) + n
	pending_night["collected"] = true
	return n


## Called on app start/resume. Returns the report to show ({} = none). A report not yet collected is
## shown again as it was (no re-roll); last_seen never moves backwards. Caller saves.
func night_check(now_unix: int, roster: Array[Bot], seed: int, rules: Dictionary = {}) -> Dictionary:
	if not pending_night.is_empty() and not bool(pending_night.get("collected", false)):
		last_seen_unix = NightShift.next_last_seen(now_unix, last_seen_unix)
		return pending_night
	if last_seen_unix <= 0:  # first run: start the clock
		last_seen_unix = now_unix
		return {}
	var away := NightShift.away_seconds(now_unix, last_seen_unix, rules)
	var r := rules if not rules.is_empty() else NightShift.load_rules()
	if away < int(r.get("min_away_seconds", 120)):
		return {}  # too short: last_seen is left alone so the time keeps adding up
	var est := NightShift.estimate(roster, away, seed, r)
	last_seen_unix = NightShift.next_last_seen(now_unix, last_seen_unix)
	pending_night = {"commendations": est["commendations"], "mess_level": est["mess_level"], "lines": est["lines"], "collected": false}
	return pending_night


## Mess for the next day: consumed once. Day 1 of a new career gets none.
func take_mess(day: int) -> int:
	var n := int(pending_night.get("mess_level", 0))
	pending_night = {}
	return n if day > 1 else 0
