class_name Career
extends RefCounted
## A run: days until fired, with training between days. Pure sim.

const FOREMAN_PATH := "res://data/foreman.json"
const PHASE_CLOCK_IN := "clock_in"
const PHASE_SHIFT := "shift"
const PHASE_END_OF_DAY := "end_of_day"

var config: SimConfig
var seed: int = 0
var rng := RandomNumberGenerator.new()
var roster: Array[Bot] = []
var day: int = 1
var strikes: int = 0
var points: int = 0
var fired: bool = false
var automated: bool = false  # every bot on the roster is trained: the Foreman replaces you (a win)
var automated_day: int = 0
var crew_speed: float = 1.0
var qa_bonus: int = 0  # extra queue slots (Bigger desk)
var inspect_speed: float = 1.0  # Quick eye multiplies inspect time
var history: Array = []  # {day, shipped, target, hit}
var twists: Twists
var rookies_joined: int = 0
var arrival: Dictionary = {}  # today's rookie, {name, replaced} (replaced "" = took a free slot); {} = none
var lessons_learned: int = 0
var night_mess: int = 0  # extra jammed machines at the start of the next day (day 1 never)
var clean_shifts: int = 0  # shifts with zero complaints
var twist_days_done: int = 0  # shifts played under a twist
var perks: Dictionary = {}  # radio: bool, supervise: bot name, auto_inspect: bool (see offers())
var offers_taken: Dictionary = {}  # offer kind -> times taken
var meta_perks: Array = []  # owned permanent perk ids (data/perks.json)
var _perk_defs: Dictionary = {}
var _forgive_left: int = 0
var _perk_note: String = ""
var _lines: Dictionary = {}
var phase: String = PHASE_CLOCK_IN  # day phase: the sim clock only runs in "shift"
var _dialogue := Dialogue.new()


func _init(p_config: SimConfig, p_seed: int, p_perks: Array = []) -> void:
	config = p_config
	meta_perks = p_perks.duplicate() if p_config.feature("perks") else []
	if not meta_perks.is_empty():
		_perk_defs = Meta.load_perks()
	seed = p_seed
	rng.seed = p_seed
	twists = Twists.new(p_seed, config.twist_start_day)
	var defs := config.bot_defs.duplicate()
	for i in range(defs.size() - 1, 0, -1):  # seeded Fisher-Yates
		var j := rng.randi_range(0, i)
		var t: Dictionary = defs[i]
		defs[i] = defs[j]
		defs[j] = t
	if config.bots_dealt > 0:
		defs = defs.slice(0, config.bots_dealt)
	for d: Dictionary in defs:
		roster.append(Bot.from_dict(d, config.train_factor, config.learn_mult, config.trained_lessons, config.trained_mistake_mult))
	_forgive_left = 1 if meta_perks.has("forgive") else 0
	if meta_perks.has("lesson") and not roster.is_empty():
		var pr := RandomNumberGenerator.new()  # separate stream: the career rng is untouched
		pr.seed = p_seed * 131 + 17
		var lb := roster[pr.randi_range(0, roster.size() - 1)]
		var lm: String = Bot.MISTAKES[pr.randi_range(0, Bot.MISTAKES.size() - 1)]
		lb.levels[lm] = lb.level(lm) + 1
		_perk_note = "%s did the orientation (%s)." % [lb.name, lm]
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FOREMAN_PATH))
	if parsed is Dictionary:
		_lines = parsed


func day_target() -> int:
	return config.target_base + config.target_per_day * (day - 1)


## Today's twist ({} = none): days before twist_start_day have none.
func twist() -> Dictionary:
	return twists.for_day(day) if config.feature("twists") else {}


## Today's QA spec (see QaSpec).
func qa_spec() -> Dictionary:
	return QaSpec.for_day(config, seed, day)


## Quota including the twist's target multiplier.
func shift_target() -> int:
	return roundi(float(day_target()) * float(twist().get("target_mult", 1.0)))


func day_mult() -> float:
	return pow(config.day_rate_mult, day - 1)


func start_day() -> Factory:
	phase = PHASE_CLOCK_IN
	_add_rookie()
	var f := Factory.new(config, seed * 1000 + day, roster, day_mult())
	f.apply_twist(twist())
	f.apply_spec(qa_spec())
	f.target = shift_target()
	f.pacing.day = day
	f.crew_speed = crew_speed * (float(_perk_defs.get("repair_mult", 0.9)) if meta_perks.has("repair") else 1.0)
	if meta_perks.has("shelf"):
		f.shelf_slots += int(_perk_defs.get("shelf_bonus", 1))
	f.qa_capacity += qa_bonus
	f.inspect_speed = inspect_speed
	f.apply_perks(perks)
	if day > 1:
		f.apply_mess(night_mess, seed * 1000 + day)
	night_mess = 0
	return f


## Clock in: the shift begins (only from the clock-in phase). Returns true if the phase changed.
func start_shift() -> bool:
	if phase != PHASE_CLOCK_IN:
		return false
	phase = PHASE_SHIFT
	return true


## Advance the factory one tick, but only during the shift phase. Returns true if it ticked.
func step(f: Factory) -> bool:
	if phase != PHASE_SHIFT:
		return false
	f.step()
	return true


## Day-specific deterministic RNG for dialogue picks (separate stream: the career RNG is untouched).
func _line_rng(salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed * 6469 + day * 101 + salt
	return r


## Clock-in screen content: {briefing, bot, bot_line}. The bot is drawn from today's crew.
func clock_in() -> Dictionary:
	var r := _line_rng(1)
	var briefing := Dialogue.pick(_dialogue.foreman_lines("foreman_briefing"), r).replace("{day}", str(day)).replace("{target}", str(shift_target()))
	var bot := ""
	var line := ""
	if not roster.is_empty():
		bot = roster[r.randi_range(0, roster.size() - 1)].name
		line = Dialogue.pick(_dialogue.bot_lines(bot), r)
	return {"briefing": briefing, "bot": bot, "bot_line": line}


## Foreman's end-of-day reaction line for a day result (hit / bonus / miss).
func reaction(res: Dictionary) -> String:
	var key := "miss"
	if bool(res.get("hit", false)):
		key = "bonus" if float(res["shipped"]) >= float(res["target"]) * config.bonus_threshold else "hit"
	return Dialogue.pick(_dialogue.foreman_lines("foreman_reaction", key), _line_rng(2))


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
	if not config.feature("rookies") or i >= config.rookie_days.size() or i >= config.rookie_defs.size() or day < config.rookie_days[i]:
		return
	var rk := Bot.from_dict(config.rookie_defs[i], config.train_factor, config.learn_mult, config.trained_lessons, config.trained_mistake_mult)
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
	phase = PHASE_END_OF_DAY
	var score := f.score()
	lessons_learned += f.lessons.size()
	if f.complaints == 0:
		clean_shifts += 1
	if f.twist_id != "":
		twist_days_done += 1
	var hit := score >= f.target
	var near := float(score) >= float(f.target) * float(_perk_defs.get("near_miss", 0.5))  # perks only forgive an honest try
	history.append({"day": day, "shipped": score, "target": f.target, "hit": hit})
	if hit:
		points += 1
		if float(score) >= float(f.target) * config.bonus_threshold:
			points += 1
	elif day > config.probation_days and not (near and meta_perks.has("grace") and day <= probation_days()):
		if near and _forgive_left > 0:
			_forgive_left -= 1
		else:
			strikes += 1
		if strikes >= config.max_strikes:
			fired = true
	check_automation()
	return {"probation": not hit and (day <= config.probation_days or (near and meta_perks.has("grace") and day <= probation_days())), "hit": hit, "shipped": score, "target": f.target, "strikes": strikes, "fired": fired, "automated": automated, "points": points, "caught": f.caught, "complaints": f.complaints, "wasted": f.wasted, "missed_by_type": f.missed_by_type.duplicate(), "spec_change": f.spec_change, "subtle_scanned": f.subtle_scanned, "subtle_caught": f.subtle_caught, "subtle_shipped": f.subtle_shipped, "back_shipped": f.back_shipped, "bot_mistakes": Career.mistake_tally(f.mistake_log), "lessons": f.lessons.duplicate(), "rookie": arrival.duplicate()}


## Career summary for Meta.award. days = days survived (the day you were fired on counts).
func summary() -> Dictionary:
	var best := 0
	var run := 0
	for h: Dictionary in history:
		run = run + 1 if bool(h["hit"]) else 0
		best = maxi(best, run)
	return {"automated": automated, "automation_bonus": config.automation_bonus if automated else 0, "days": day, "clean_shifts": clean_shifts, "best_streak": best, "lessons": lessons_learned, "twist_days": twist_days_done}


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


## True once every bot on the roster is trained (rookies who join later must be trained too). Sets `automated`.
func check_automation() -> bool:
	if automated or fired or roster.is_empty():
		return automated
	for b in roster:
		if not b.is_trained():
			return false
	automated = true
	automated_day = day
	return true


func probation_days() -> int:
	return config.probation_days + (int(_perk_defs.get("grace_days", 1)) if meta_perks.has("grace") else 0)


func offers_per_review() -> int:
	return config.offers_per_review + (int(_perk_defs.get("extra_choices", 1)) if meta_perks.has("choice") else 0)


## Day-1 banner news: owned perks, then today's rookie.
func banner_news() -> String:
	var parts: Array[String] = []
	if day == 1 and not meta_perks.is_empty():
		var names: Array[String] = []
		for id: String in meta_perks:
			var d := Meta.perk_def(id, _perk_defs)
			names.append(String(d.get("name", id)))
		parts.append("PERKS: " + ", ".join(names) + ".")
		if _perk_note != "":
			parts.append(_perk_note)
	var a := arrival_line()
	if a != "":
		parts.append(a)
	return " ".join(parts)


func offers() -> Array[Dictionary]:
	var cands: Array[Dictionary] = []
	for b in roster:
		var ms: Array = Bot.MISTAKES.filter(func(k: String) -> bool: return config.feature_mistake(k))
		ms.sort_custom(func(a: String, c: String) -> bool: return _eff(b, a) > _eff(b, c))
		for k in mini(2, ms.size()):  # each bot's two highest effective rates
			var m: String = ms[k]
			cands.append({"kind": "train", "bot": b.name, "mistake": m, "text": "Train %s: %s -%d%%" % [b.name, m, roundi((1.0 - b.train_factor) * 100.0)]})
		if b.sloppy > 0.0:
			cands.append({"kind": "train", "bot": b.name, "mistake": "sloppy", "text": "Train %s: sloppy -%d%%" % [b.name, roundi((1.0 - b.train_factor) * 100.0)]})
	cands.append({"kind": "qa_capacity", "text": "Bigger desk: +%d queue" % config.bigger_desk_bonus})
	cands.append({"kind": "inspect_speed", "text": "Quick eye: inspect -%d%%" % roundi((1.0 - config.quick_eye_mult) * 100.0)})
	cands.append({"kind": "crew_speed", "text": "Faster hands: crew jobs -%d%%" % roundi((1.0 - config.crew_speed_upgrade) * 100.0)})
	if config.feature("offers_extra") and not perks.get("radio", false):
		cands.append({"kind": "radio", "text": "Radio: clear a jam from the desk"})
	if config.feature("offers_extra") and not perks.get("auto_inspect", false):
		cands.append({"kind": "auto_inspect", "text": "Auto-inspector: checks while you're away (errs)"})
	if config.feature("offers_extra") and not roster.is_empty():
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
		if out.size() >= offers_per_review():
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
	check_automation()


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


## Offer a scripted player takes. `human_careful` and `careful` take a "train a bot" offer when one helps an untrained bot
## (the one closest to trained); other players use pick_offer.
func choose_offer(player: String, offs: Array[Dictionary]) -> Dictionary:
	var careful := player.ends_with("careful")
	if careful:
		var best: Dictionary = {}
		var best_n := -1
		for o in offs:
			if String(o["kind"]) != "train":
				continue
			for b in roster:
				if b.name == o["bot"] and not b.is_trained() and b.lesson_count() > best_n:
					best_n = b.lesson_count()
					best = o
		if not best.is_empty():
			return best
	return Career.pick_offer(careful, offs)
