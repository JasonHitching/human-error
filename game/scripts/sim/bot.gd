class_name Bot
extends RefCounted
## An AI coworker running a machine. Its mistakes cause the problems.

const MISTAKES := ["jam", "overclock", "misroute", "wrong_recipe"]

var name: String = ""
var color: Color = Color.WHITE
var rates: Dictionary = {}  # mistake -> events per minute
var lines: Array[String] = []
var levels: Dictionary = {}  # mistake -> training level (default 0)
var train_factor: float = 0.6


static func from_dict(d: Dictionary, train: float) -> Bot:
	var b := Bot.new()
	b.name = String(d.get("name", ""))
	b.color = Color.html(String(d.get("color", "#ffffff")))
	b.rates = (d.get("rates", {}) as Dictionary).duplicate()
	for l: Variant in d.get("lines", []):
		b.lines.append(String(l))
	b.train_factor = train
	return b


func level(mistake: String) -> int:
	return int(levels.get(mistake, 0))


func rate_per_tick(mistake: String, tick_rate: int, ramp: float, day_mult: float) -> float:
	var r := float(rates.get(mistake, 0.0))
	if r <= 0.0:
		return 0.0
	return r / 60.0 / float(tick_rate) * ramp * day_mult * pow(train_factor, level(mistake))
