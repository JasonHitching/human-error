class_name Career
extends RefCounted
## A run: days until fired, with training between days. Pure sim.

const FOREMAN_PATH := "res://data/foreman.json"

var config: SimConfig
var seed: int = 0
var rng := RandomNumberGenerator.new()
var roster: Array[Bot] = []
var day: int = 1
var strikes: int = 0
var points: int = 0
var fired: bool = false
var crew_speed: float = 1.0
var qa_bonus: int = 0  # extra queue slots (Bigger desk)
var inspect_speed: float = 1.0  # Quick eye multiplies inspect time
var history: Array = []  # {day, shipped, target, hit}
var _lines: Dictionary = {}


func _init(p_config: SimConfig, p_seed: int) -> void:
	config = p_config
	seed = p_seed
	rng.seed = p_seed
	var defs := config.bot_defs.duplicate()
	for i in range(defs.size() - 1, 0, -1):  # seeded Fisher-Yates
		var j := rng.randi_range(0, i)
		var t: Dictionary = defs[i]
		defs[i] = defs[j]
		defs[j] = t
	for d: Dictionary in defs:
		roster.append(Bot.from_dict(d, config.train_factor))
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FOREMAN_PATH))
	if parsed is Dictionary:
		_lines = parsed


func day_target() -> int:
	return config.target_base + config.target_per_day * (day - 1)


func day_mult() -> float:
	return pow(config.day_rate_mult, day - 1)


func start_day() -> Factory:
	var f := Factory.new(config, seed * 1000 + day, roster, day_mult())
	f.target = day_target()
	f.pacing.day = day
	f.crew_speed = crew_speed
	f.qa_capacity += qa_bonus
	f.inspect_speed = inspect_speed
	return f


func end_day(f: Factory) -> Dictionary:
	var score := f.score()
	var hit := score >= f.target
	history.append({"day": day, "shipped": score, "target": f.target, "hit": hit})
	if hit:
		points += 1
		if float(score) >= float(f.target) * config.bonus_threshold:
			points += 1
	elif day > config.probation_days:
		strikes += 1
		if strikes >= config.max_strikes:
			fired = true
	return {"probation": not hit and day <= config.probation_days, "hit": hit, "shipped": score, "target": f.target, "strikes": strikes, "fired": fired, "points": points, "caught": f.caught, "complaints": f.complaints, "wasted": f.wasted, "missed_by_type": f.missed_by_type.duplicate()}


func offers() -> Array[Dictionary]:
	var cands: Array[Dictionary] = []
	for b in roster:
		var ms: Array = Bot.MISTAKES.duplicate()
		ms.sort_custom(func(a: String, c: String) -> bool: return _eff(b, a) > _eff(b, c))
		for k in mini(2, ms.size()):  # each bot's two highest effective rates
			var m: String = ms[k]
			cands.append({"kind": "train", "bot": b.name, "mistake": m, "text": "Train %s: %s -%d%%" % [b.name, m, roundi((1.0 - b.train_factor) * 100.0)]})
		if b.sloppy > 0.0:
			cands.append({"kind": "train", "bot": b.name, "mistake": "sloppy", "text": "Train %s: sloppy -%d%%" % [b.name, roundi((1.0 - b.train_factor) * 100.0)]})
	cands.append({"kind": "qa_capacity", "text": "Bigger desk: +%d queue" % config.bigger_desk_bonus})
	cands.append({"kind": "inspect_speed", "text": "Quick eye: inspect -%d%%" % roundi((1.0 - config.quick_eye_mult) * 100.0)})
	cands.append({"kind": "crew_speed", "text": "Faster hands: crew jobs -%d%%" % roundi((1.0 - config.crew_speed_upgrade) * 100.0)})
	var r := RandomNumberGenerator.new()
	r.seed = seed * 7919 + day * 31 + history.size()  # deterministic per career state
	for i in range(cands.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var t: Dictionary = cands[i]
		cands[i] = cands[j]
		cands[j] = t
	var out: Array[Dictionary] = []
	for c in cands:
		if out.size() >= config.offers_per_review:
			break
		out.append(c)
	return out


func _eff(b: Bot, m: String) -> float:
	return float(b.rates.get(m, 0.0)) * pow(b.train_factor, b.level(m))


func apply(offer: Dictionary) -> void:
	if points < 1:
		return
	points -= 1
	if offer.get("kind") == "crew_speed":
		crew_speed *= config.crew_speed_upgrade
		return
	if offer.get("kind") == "qa_capacity":
		qa_bonus += config.bigger_desk_bonus
		return
	if offer.get("kind") == "inspect_speed":
		inspect_speed *= config.quick_eye_mult
		return
	for b in roster:
		if b.name == offer.get("bot"):
			var m := String(offer["mistake"])
			b.levels[m] = b.level(m) + 1


func next_day() -> void:
	day += 1


func foreman_line(kind: String) -> String:
	var arr: Array = _lines.get(kind, [])
	if arr.is_empty():
		return ""
	var s: String = arr[rng.randi_range(0, arr.size() - 1)]
	return s.replace("{day}", str(day)).replace("{target}", str(day_target()))


## Deterministic line pick that does not touch the career RNG (safe to call mid-shift).
func foreman_line_at(kind: String, index: int) -> String:
	var arr: Array = _lines.get(kind, [])
	return "" if arr.is_empty() else String(arr[index % arr.size()])
