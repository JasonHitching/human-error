class_name NightShift
extends RefCounted
## Offline "night shift" (pure sim): what the bots earn and the mess they leave while you are away.
## No clock reads here: callers pass the times in. No networking.

const PATH := "res://data/night_shift.json"


static func load_rules(path: String = PATH) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


## Away time in seconds: now - last_seen clamped to [0, cap]. A clock set backwards (or no last_seen) gives 0.
static func away_seconds(now_unix: int, last_seen_unix: int, rules: Dictionary = {}) -> int:
	var r := rules if not rules.is_empty() else load_rules()
	if last_seen_unix <= 0:
		return 0
	return clampi(now_unix - last_seen_unix, 0, int(r.get("cap_seconds", 28800)))


## The timestamp to store after a check: never moves backwards, so setting the clock back and
## forward again cannot re-earn the same hours.
static func next_last_seen(now_unix: int, last_seen_unix: int) -> int:
	return maxi(now_unix, last_seen_unix)


## A bot's effective mistake rate (events per minute) with training, lessons and trained status applied.
static func bot_mess_rate(b: Bot) -> float:
	var total := 0.0
	for k: String in Bot.MISTAKES:
		total += float(b.rates.get(k, 0.0)) * pow(b.train_factor, b.level(k)) * (b.learn_mult if b.learned.has(k) else 1.0)
	return total * b.trained_scale()


## {commendations, mess_level, lines[]}. Deterministic for (roster, away_seconds, seed); capped by data.
static func estimate(roster: Array[Bot], away_seconds: int, seed: int, rules: Dictionary = {}) -> Dictionary:
	var r := rules if not rules.is_empty() else load_rules()
	var cap_s := int(r.get("cap_seconds", 28800))
	var secs := clampi(away_seconds, 0, cap_s)
	if secs < int(r.get("min_away_seconds", 120)) or roster.is_empty():
		return {"commendations": 0, "mess_level": 0, "lines": [] as Array[String]}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 7 + 23
	var hours := float(secs) / 3600.0
	var jit := float(r.get("jitter", 0.15))
	var earn := 0.0
	var mess_rate := 0.0
	for b in roster:
		earn += hours * float(r.get("per_bot_hour", 0.5)) * (1.0 + float(r.get("per_lesson_mult", 0.15)) * float(b.lesson_count())) * (1.0 + rng.randf_range(-jit, jit))
		mess_rate += bot_mess_rate(b)
	var comm := mini(roundi(earn), int(r.get("max_commendations", 12)))
	var raw := mess_rate * (float(secs) / float(cap_s)) * (1.0 + rng.randf_range(-jit, jit))
	var level := 0
	for step: Variant in r.get("mess_steps", []):
		if raw >= float(step):
			level += 1
	level = clampi(level, 0, int(r.get("max_mess", 3)))
	return {"commendations": maxi(0, comm), "mess_level": level, "lines": _lines(r, roster, hours, comm, level, rng)}


static func _lines(r: Dictionary, roster: Array[Bot], hours: float, comm: int, level: int, rng: RandomNumberGenerator) -> Array[String]:
	var texts: Dictionary = r.get("lines", {})
	var out: Array[String] = []
	var pick := roster[rng.randi_range(0, roster.size() - 1)]
	var subs := {"{hours}": "%.1f" % hours, "{commendations}": str(comm), "{credit}": str(maxi(1, comm / 2)), "{bot}": pick.name, "{bot_hours}": "%.1f" % hours}
	for key: String in ["intro", "earn", "bot", "mess_%d" % level]:
		var arr: Array = texts.get(key, [])
		if arr.is_empty():
			continue
		var s := String(arr[rng.randi_range(0, arr.size() - 1)])
		for k: String in subs:
			s = s.replace(k, String(subs[k]))
		out.append(s)
	return out.slice(0, clampi(int(r.get("report_lines", 4)), 3, 5))
