class_name TwistStats
extends RefCounted
## Twist yardstick: failed-day share on twist vs non-twist days of the SAME day number.

const MIN_PER_SIDE := 10

var _t: Dictionary = {}  # day -> [days, failed] on twist days
var _p: Dictionary = {}  # day -> [days, failed] on plain days


func add(day: int, twisted: bool, failed: bool) -> void:
	var d: Dictionary = _t if twisted else _p
	var a: Array = d.get(day, [0, 0])
	a[0] += 1
	a[1] += 1 if failed else 0
	d[day] = a


## Day numbers (sorted) with >= MIN_PER_SIDE shifts of each kind.
func eligible_days() -> Array[int]:
	var out: Array[int] = []
	for day: int in _t:
		if _p.has(day) and int(_t[day][0]) >= MIN_PER_SIDE and int(_p[day][0]) >= MIN_PER_SIDE:
			out.append(day)
	out.sort()
	return out


## Pooled {twist, plain, ratio}: per-day failed shares averaged with weight = shifts on that day number.
## ratio = twist / plain (INF if plain is 0 and twist > 0, 1.0 if both 0).
func pooled() -> Dictionary:
	var w_sum := 0.0
	var ts := 0.0
	var ps := 0.0
	for day in eligible_days():
		var t: Array = _t[day]
		var p: Array = _p[day]
		var w := float(int(t[0]) + int(p[0]))
		w_sum += w
		ts += w * float(t[1]) / float(t[0])
		ps += w * float(p[1]) / float(p[0])
	if w_sum == 0.0:
		return {"twist": 0.0, "plain": 0.0, "ratio": 1.0, "days": 0}
	ts /= w_sum
	ps /= w_sum
	var ratio := 1.0 if ts == 0.0 and ps == 0.0 else (INF if ps == 0.0 else ts / ps)
	return {"twist": ts, "plain": ps, "ratio": ratio, "days": eligible_days().size()}


func report_lines() -> Array[String]:
	var out: Array[String] = []
	var all: Array = _t.keys() + _p.keys()
	var seen := {}
	var days: Array[int] = []
	for d: int in all:
		if not seen.has(d):
			seen[d] = true
			days.append(d)
	days.sort()
	for d in days:
		var t: Array = _t.get(d, [0, 0])
		var p: Array = _p.get(d, [0, 0])
		out.append("  twist yardstick day %2d: twist %3d (%4.1f%% failed) | plain %3d (%4.1f%% failed)%s" % [
			d, t[0], 100.0 * t[1] / maxf(1.0, t[0]), p[0], 100.0 * p[1] / maxf(1.0, p[0]),
			"" if eligible_days().has(d) else "  (n<10, not pooled)"])
	var r := pooled()
	out.append("  twist yardstick pooled over %d day numbers: twist %.1f%% vs plain %.1f%% = %.2fx" % [r["days"], 100.0 * r["twist"], 100.0 * r["plain"], r["ratio"]])
	return out
