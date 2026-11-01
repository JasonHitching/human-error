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


static func from_dict(d: Dictionary, train: float) -> Bot:
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
	return b


func level(mistake: String) -> int:
	return int(levels.get(mistake, 0))


func rate_per_tick(mistake: String, tick_rate: int, ramp: float, day_mult: float) -> float:
	var r := float(rates.get(mistake, 0.0))
	if r <= 0.0:
		return 0.0
	return r / 60.0 / float(tick_rate) * ramp * day_mult * pow(train_factor, level(mistake))


## Chance this bot spoils one product: sloppy * ramp * day_mult, reduced by "sloppy" training.
func sloppy_chance(ramp: float, day_mult: float) -> float:
	return clampf(sloppy * ramp * day_mult * pow(train_factor, level("sloppy")), 0.0, 1.0)
