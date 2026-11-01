class_name Autoplayers
extends RefCounted
## Scripted players for sim_runner (not in-game bots). They act as if holding (never release).
## none: never acts or moves. greedy: fixes first, else inspects. careful: stays at the desk while the queue is long.

const NAMES := ["none", "greedy", "careful", "human", "human_careful"]
const VENT_HEAT := 80.0
const ACCURACY := 0.95
const CAREFUL_QUEUE := 4
const CAREFUL_VENT_HEAT := 55.0
## human / human_careful: greedy / careful, but paced like a person: notices a problem after REACT ticks, one move per GAP ticks,
## one inspection per INSPECT_GAP ticks, a bit less accurate. Used to check the game is fair for people.
const HUMAN_REACT := 15
const HUMAN_GAP := 8
const HUMAN_INSPECT_GAP := 12
const HUMAN_SCAN_GAP := 2
const HUMAN_ACCURACY := 0.9


## Own RNG for inspection mistakes (never the factory's). Seed it per run.
static func make_rng(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed * 131 + 7
	return r


## Call once per tick before factory.step(). mem: per-run player memory (pass the same Dictionary every tick).
## Trips: greedy walks to the floor as soon as anything needs fixing and back when all is fixed;
## it fixes in the order problems appeared. careful stays in the office while the queue is long
## (unless a machine is red), walks to the nearest fix next, queues the one after and batches.
static func act(who: String, f: Factory, rng: RandomNumberGenerator = null, mem: Dictionary = {}) -> void:
	if who == "none":
		return
	var paced := who.begins_with("human")  # human pacing on top of the policy
	var player := "careful" if who.ends_with("careful") else "greedy"  # the policy
	var order: Array = mem.get_or_add("order", [])
	var seen: Dictionary = mem.get_or_add("seen", {})
	for m in f.machines:  # remember when problems appeared
		if _needs(m, VENT_HEAT):
			if paced:
				if not seen.has(m.id):
					seen[m.id] = f.tick
				if f.tick - int(seen[m.id]) >= HUMAN_REACT and not order.has(m.id):
					order.append(m.id)  # noticed
			elif not order.has(m.id):
				order.append(m.id)
		else:
			order.erase(m.id)
			seen.erase(m.id)
	if paced and f.tick < int(mem.get("next", 0)):
		return
	if f.crew_busy:
		if player == "careful" and f.crew_queue.is_empty():
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
			mem["next"] = f.tick + HUMAN_GAP
		elif f.transit_target() != Worker.Location.OFFICE:
			f.go_to_office()
			mem["next"] = f.tick + HUMAN_GAP
		return
	var want_floor := job != null and (player != "careful" or f.qa_queue().size() < CAREFUL_QUEUE or _red(f))
	if loc == Worker.Location.TRANSIT:
		if want_floor:
			f.go_to_floor()  # no-op if already heading there; else turn back
		return
	if want_floor:
		f.go_to_floor()
		mem["next"] = f.tick + HUMAN_GAP
		return
	if f.inspect_busy() or rng == null:
		return
	var q := f.qa_queue()
	if q.is_empty():
		return
	var front: Dictionary = q[0]
	if player == "careful" and f.subtle_share > 0.0 and not bool(front.get("scanned", false)) and q.size() < f.scan_queue_max:
		f.scan()  # short queue: take the time to check for subtle defects
		if paced:
			mem["next"] = f.tick + f.scan_ticks + HUMAN_SCAN_GAP  # one tap, then look at the result
		return
	var good := not f.item_visible_bad(front)
	var right := rng.randf() < (HUMAN_ACCURACY if paced else ACCURACY)
	f.inspect(good == right)  # ship good / reject bad when right; the opposite when wrong
	if paced:
		mem["next"] = f.tick + HUMAN_INSPECT_GAP


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
