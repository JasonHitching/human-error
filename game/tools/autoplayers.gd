class_name Autoplayers
extends RefCounted
## Scripted players for sim_runner (not in-game bots). They act as if holding (never release).
## none: never acts or moves. greedy: fixes first, else inspects. careful: stays at the desk while the queue is long.

const NAMES := ["none", "greedy", "careful"]
const VENT_HEAT := 80.0
const ACCURACY := 0.95
const CAREFUL_QUEUE := 4
const CAREFUL_VENT_HEAT := 55.0


## Own RNG for inspection mistakes (never the factory's). Seed it per run.
static func make_rng(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed * 131 + 7
	return r


## Call once per tick before factory.step().
## Trips: greedy walks to the floor as soon as anything needs fixing and back when all is fixed.
## careful stays in the office while the queue is long (unless a machine is red) and fixes everything in one trip.
static func act(player: String, f: Factory, rng: RandomNumberGenerator = null) -> void:
	if player == "none" or f.crew_busy:
		return
	var job := _pick(f, VENT_HEAT)
	var loc := f.worker_location()
	if loc == Worker.Location.FLOOR:
		if player == "careful" and job == null:
			job = _pick(f, CAREFUL_VENT_HEAT)  # batch: vent warm machines while already here
		if job != null:
			f.request_action(job.id)
		else:
			f.go_to_office()
		return
	var want_floor := job != null and (player == "greedy" or f.qa_queue().size() < CAREFUL_QUEUE or _red(f))
	if loc == Worker.Location.TRANSIT:
		if want_floor:
			f.go_to_floor()  # no-op if already heading there; else turn back
		return
	if want_floor:
		f.go_to_floor()
		return
	if f.inspect_busy() or rng == null:
		return
	var q := f.qa_queue()
	if q.is_empty():
		return
	var good := String((q[0] as Dictionary)["defect"]) == ""
	var right := rng.randf() < ACCURACY
	f.inspect(good == right)  # ship good / reject bad when right; the opposite when wrong


static func _red(f: Factory) -> bool:
	for m in f.machines:
		if m.state == Machine.State.OVERHEATED or m.state == Machine.State.CLOGGED:
			return true
	return false


## The machine the player would fix next, or null if nothing needs fixing.
static func _pick(f: Factory, vent_heat: float) -> Machine:
	for m in f.machines:
		if m.is_faulted():
			return m
	for m in f.machines:
		if m.state == Machine.State.CLOGGED:
			return m
	for flag in ["wrong_recipe", "misrouted", "overclocked"]:
		for m in f.machines:
			if m.get(flag):
				return m
	var hottest: Machine = null
	for m in f.machines:
		if m.state == Machine.State.WORKING and m.heat >= vent_heat and (hottest == null or m.heat > hottest.heat):
			hottest = m
	return hottest
