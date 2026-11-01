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
var twists: Twists
var rookies_joined: int = 0
var arrival: Dictionary = {}  # today's rookie, {name, replaced} (replaced "" = took a free slot); {} = none
var lessons_learned: int = 0
var perks: Dictionary = {}  # radio: bool, supervise: bot name, auto_inspect: bool (see offers())
var offers_taken: Dictionary = {}  # offer kind -> times taken
var _lines: Dictionary = {}


func _init(p_config: SimConfig, p_seed: int) -> void:
	config = p_config
	seed = p_seed
	rng.seed = p_seed
	twists = Twists.new(p_seed, config.twist_start_day)
	var defs := config.bot_defs.duplicate()
	for i in range(defs.size() - 1, 0, -1):  # seeded Fisher-Yates
		var j := rng.randi_range(0, i)
		var t: Dictionary = defs[i]
		defs[i] = defs[j]
		defs[j] = t
	for d: Dictionary in defs:
		roster.append(Bot.from_dict(d, config.train_factor, config.learn_mult))
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FOREMAN_PATH))
	if parsed is Dictionary:
		_lines = parsed


func day_target() -> int:
	return config.target_base + config.target_per_day * (day - 1)


## Today's twist ({} = none): days before twist_start_day have none.
func twist() -> Dictionary:
	return twists.for_day(day)


## Today's QA spec (see QaSpec).
func qa_spec() -> Dictionary:
	return QaSpec.for_day(config, seed, day)


## Quota including the twist's target multiplier.
func shift_target() -> int:
	return roundi(float(day_target()) * float(twist().get("target_mult", 1.0)))


func day_mult() -> float:
	return pow(config.day_rate_mult, day - 1)


func start_day() -> Factory:
	_add_rookie()
	var f := Factory.new(config, seed * 1000 + day, roster, day_mult())
	f.apply_twist(twist())
	f.apply_spec(qa_spec())
	f.target = shift_target()
	f.pacing.day = day
	f.crew_speed = crew_speed
	f.qa_capacity += qa_bonus
	f.inspect_speed = inspect_speed
	f.apply_perks(perks)
	return f


## Machines a bot can run (everything but the warehouse and QA desk).
func bot_slots() -> int:
	var n := 0
	for md in config.machines:
		if md.get("type") != "warehouse" and md.get("type") != "qa":
			n += 1
	return n


## At the start of a configured rookie day the next rookie joins: a free slot, else the most-trained bot goes to head office.
func _add_rookie() -> void:
	arrival = {}
	var i := rookies_joined
	if i >= config.rookie_days.size() or i >= config.rookie_defs.size() or day < config.rookie_days[i]:
		return
	var rk := Bot.from_dict(config.rookie_defs[i], config.train_factor, config.learn_mult)
	rk.rookie = true
	rookies_joined += 1
	var slots := bot_slots()
	if roster.size() < slots:
		roster.append(rk)
		arrival = {"name": rk.name, "replaced": ""}
		return
	var worst := 0
	for k in mini(slots, roster.size()):
		if roster[k].training_total() > roster[worst].training_total():
			worst = k
	arrival = {"name": rk.name, "replaced": roster[worst].name}
	roster[worst] = rk


## Foreman news for the banner about today's rookie ("" = none).
func arrival_line() -> String:
	if arrival.is_empty():
		return ""
	if String(arrival["replaced"]) == "":
		return "NEW: rookie %s joins the floor." % arrival["name"]
	return "NEW: %s promoted to head office. Rookie %s takes over." % [arrival["replaced"], arrival["name"]]


func end_day(f: Factory) -> Dictionary:
	var score := f.score()
	lessons_learned += f.lessons.size()
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
	return {"probation": not hit and day <= config.probation_days, "hit": hit, "shipped": score, "target": f.target, "strikes": strikes, "fired": fired, "points": points, "caught": f.caught, "complaints": f.complaints, "wasted": f.wasted, "missed_by_type": f.missed_by_type.duplicate(), "spec_change": f.spec_change, "subtle_scanned": f.subtle_scanned, "subtle_caught": f.subtle_caught, "subtle_shipped": f.subtle_shipped, "bot_mistakes": Career.mistake_tally(f.mistake_log), "lessons": f.lessons.duplicate(), "rookie": arrival.duplicate()}


## Builds {bot: {count, top}} from a factory mistake_log.
static func mistake_tally(log: Array) -> Dictionary:
	var per: Dictionary = {}  # bot -> {kind -> n}
	for ev: Dictionary in log:
		var b := String(ev.get("bot", ""))
		var k := String(ev.get("mistake", ""))
		if b == "":
			continue
		var d: Dictionary = per.get(b, {})
		d[k] = int(d.get(k, 0)) + 1
		per[b] = d
	var out: Dictionary = {}
	for b: String in per:
		var d: Dictionary = per[b]
		var kinds := d.keys()
		kinds.sort()
		var top := String(kinds[0])
		var total := 0
		for k: String in kinds:
			total += int(d[k])
			if int(d[k]) > int(d[top]):
				top = k
		out[b] = {"count": total, "top": top}
	return out


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
	if not perks.get("radio", false):
		cands.append({"kind": "radio", "text": "Radio: clear a jam from the desk"})
	if not perks.get("auto_inspect", false):
		cands.append({"kind": "auto_inspect", "text": "Auto-inspector: checks while you're away (errs)"})
	if not roster.is_empty():
		var sb := roster[(seed + day) % roster.size()]
		if sb.name != perks.get("supervise", ""):
			cands.append({"kind": "supervise", "bot": sb.name, "text": "Supervise %s: -%d%% mistakes near you" % [sb.name, roundi((1.0 - config.supervise_mult) * 100.0)]})
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
	var kind := String(offer.get("kind", ""))
	offers_taken[kind] = int(offers_taken.get(kind, 0)) + 1
	if kind == "radio":
		perks["radio"] = true
		return
	if kind == "auto_inspect":
		perks["auto_inspect"] = true
		return
	if kind == "supervise":
		perks["supervise"] = String(offer["bot"])
		return
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


## Which offer a scripted player takes: greedy-style players the first, careful-style the best by a fixed preference.
static func pick_offer(careful: bool, offs: Array[Dictionary]) -> Dictionary:
	if not careful or offs.is_empty():
		return offs[0]
	const PREF := ["radio", "supervise", "auto_inspect", "crew_speed", "qa_capacity", "inspect_speed", "train"]
	var best := offs[0]
	for o in offs:
		if PREF.find(String(o["kind"])) < PREF.find(String(best["kind"])):
			best = o
	return best
