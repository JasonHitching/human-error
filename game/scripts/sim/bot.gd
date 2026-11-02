class_name Bot
extends RefCounted
## An AI coworker running a machine. Its mistakes cause the problems.

const MISTAKES := ["jam", "overclock", "misroute", "wrong_recipe"]

var name: String = ""
var color: Color = Color.WHITE
var rates: Dictionary = {}  # mistake -> events per minute
var sloppy: float = 0.0  # chance per product of a defect (before ramp/day/training)
var lines: Array[String] = []
var call_in: Array[String] = []  # lines said on the office wall monitor when this bot's machine goes RED
var levels: Dictionary = {}  # mistake -> training level (default 0)
var train_factor: float = 0.6
var learn_mult: float = 0.5
var fixes: Dictionary = {}  # mistake -> fixes the worker made on this bot's machines
var learned: Dictionary = {}  # mistake -> true once the bot has learned from fixes
var rookie: bool = false
var trained_lessons: int = 3  # lessons (training picks + lessons learned from fixes) to count as trained
var trained_mult: float = 0.4  # mistake chance multiplier once trained


static func from_dict(d: Dictionary, train: float, p_learn_mult: float = 0.5, p_trained_lessons: int = 3, p_trained_mult: float = 0.4) -> Bot:
	var b := Bot.new()
	b.name = String(d.get("name", ""))
	b.color = Color.html(String(d.get("color", "#ffffff")))
	b.rates = (d.get("rates", {}) as Dictionary).duplicate()
	b.sloppy = float(d.get("sloppy", 0.0))
	for l: Variant in d.get("lines", []):
		b.lines.append(String(l))
	for l: Variant in d.get("call_in", []):
		b.call_in.append(String(l))
	b.train_factor = train
	b.learn_mult = p_learn_mult
	b.trained_lessons = p_trained_lessons
	b.trained_mult = p_trained_mult
	return b


func level(mistake: String) -> int:
	return int(levels.get(mistake, 0))


func rate_per_tick(mistake: String, tick_rate: int, ramp: float, day_mult: float) -> float:
	var r := float(rates.get(mistake, 0.0))
	if r <= 0.0:
		return 0.0
	return r / 60.0 / float(tick_rate) * ramp * day_mult * pow(train_factor, level(mistake)) * (learn_mult if learned.has(mistake) else 1.0) * trained_scale()


## Chance this bot spoils one product: sloppy * ramp * day_mult, reduced by "sloppy" training.
func sloppy_chance(ramp: float, day_mult: float) -> float:
	return clampf(sloppy * ramp * day_mult * pow(train_factor, level("sloppy")) * trained_scale(), 0.0, 1.0)


## Lessons so far: training picks plus lessons learned from the worker's fixes.
func lesson_count() -> int:
	return training_total() + learned.size()


func is_trained() -> bool:
	return lesson_count() >= trained_lessons


func trained_scale() -> float:
	return trained_mult if is_trained() else 1.0


func training_total() -> int:
	var n := 0
	for k: String in levels:
		n += int(levels[k])
	return n


## Counts one fix of `mistake`. Returns true when the bot learns the lesson now:
## after `after` fixes, `roll` (a seeded 0..1 draw) must be below `chance`. At most once per mistake.
func note_fix(mistake: String, after: int, chance: float, roll: float) -> bool:
	if learned.has(mistake):
		return false
	var n := int(fixes.get(mistake, 0)) + 1
	fixes[mistake] = n
	if n < after or roll >= chance:
		return false
	learned[mistake] = true
	return true
