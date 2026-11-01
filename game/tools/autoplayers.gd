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


## Call once per tick before factory.step(). mem: per-run player memory (pass the same Dictionary every tick).
## Trips: greedy walks to the floor as soon as anything needs fixing and back when all is fixed;
## it fixes in the order problems appeared. careful stays in the office while the queue is long
## (unless a machine is red), walks to the nearest fix next, queues the one after and batches.
static func act(player: String, f: Factory, rng: RandomNumberGenerator = null, mem: Dictionary = {}) -> void:
	if player == "none":
		return
	var order: Array = mem.get_or_add("order", [])
	for m in f.machines:  # remember when problems appeared
		if _needs(m, VENT_HEAT) and not order.has(m.id):
			order.append(m.id)
		elif not _needs(m, VENT_HEAT):
			order.erase(m.id)
	if f.crew_busy:
		if player == "careful" and f.crew_queued == "":
			var nxt := _nearest(f, f.get_machine(f.crew_target).pos, CAREFUL_VENT_HEAT, f.crew_target)
			if nxt != null:
				f.request_action(nxt.id)
		return
	var job := _pick(player, f, VENT_HEAT, order)
	var loc := f.worker_location()
	if loc == Worker.Location.FLOOR:
		if player == "careful" and job == null:
			job = _pick(player, f, CAREFUL_VENT_HEAT, order)  # batch: vent warm machines while already here
		if job != null:
			f.request_action(job.id)
		elif f.transit_target() != Worker.Location.OFFICE:
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


## Does m need the crew (venting only from vent_heat)?
static func _needs(m: Machine, vent_heat: float) -> bool:
	if m.is_faulted() or m.state == Machine.State.CLOGGED or m.wrong_recipe or m.misrouted or m.overclocked:
		return true
	return m.state == Machine.State.WORKING and m.heat >= vent_heat


## The machine the player would fix next, or null if nothing needs fixing.
static func _pick(player: String, f: Factory, vent_heat: float, order: Array) -> Machine:
	if player == "careful":
		var from := f.worker.floor_pos if f.worker_location() == Worker.Location.FLOOR else f.worker.stairs
		return _nearest(f, from, vent_heat, "")
	for id: String in order:
		var m := f.get_machine(id)
		if _needs(m, vent_heat):
			return m
	return null


static func _nearest(f: Factory, from: Vector2, vent_heat: float, skip: String) -> Machine:
	var best: Machine = null
	for m in f.machines:
		if m.id != skip and _needs(m, vent_heat) and (best == null or from.distance_to(m.pos) < from.distance_to(best.pos)):
			best = m
	return best
