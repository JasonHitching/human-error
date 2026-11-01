class_name Autoplayers
extends RefCounted
## Scripted players for sim_runner (not in-game bots). They act as if holding (never release).
## none: never acts. greedy: fixes first, else inspects. careful: stays at the desk while the queue is long.

const NAMES := ["none", "greedy", "careful"]
const VENT_HEAT := 80.0
const ACCURACY := 0.95
const CAREFUL_QUEUE := 4


## Own RNG for inspection mistakes (never the factory's). Seed it per run.
static func make_rng(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed * 131 + 7
	return r


## Call once per tick before factory.step().
static func act(player: String, f: Factory, rng: RandomNumberGenerator = null) -> void:
	if player == "none" or f.crew_busy:
		return
	var may_fix := true
	if player == "careful" and f.qa_queue().size() >= CAREFUL_QUEUE:
		may_fix = false
		for m in f.machines:
			if m.state == Machine.State.OVERHEATED or m.state == Machine.State.CLOGGED:
				may_fix = true
	if may_fix and _fix(f):
		return
	if f.inspect_busy() or rng == null:
		return
	var q := f.qa_queue()
	if q.is_empty():
		return
	var good := String((q[0] as Dictionary)["defect"]) == ""
	var right := rng.randf() < ACCURACY
	f.inspect(good == right)  # ship good / reject bad when right; the opposite when wrong


static func _fix(f: Factory) -> bool:
	for m in f.machines:
		if m.is_faulted():
			f.request_action(m.id)
			return true
	for m in f.machines:
		if m.state == Machine.State.CLOGGED:
			f.request_action(m.id)
			return true
	for flag in ["wrong_recipe", "misrouted", "overclocked"]:
		for m in f.machines:
			if m.get(flag):
				f.request_action(m.id)
				return true
	var hottest: Machine = null
	for m in f.machines:
		if m.state == Machine.State.WORKING and m.heat >= VENT_HEAT and (hottest == null or m.heat > hottest.heat):
			hottest = m
	if hottest != null:
		f.request_action(hottest.id)
		return true
	return false
