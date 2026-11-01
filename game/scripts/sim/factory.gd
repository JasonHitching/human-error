class_name Factory
extends RefCounted
## Headless factory simulation. Fixed timestep: one step() == one tick.

var tick: int = 0
var shipped: int = 0
var machines: Array[Machine] = []
var rng := RandomNumberGenerator.new()  # sole source of randomness (used from #4)

enum InspectResult { SHIPPED, COMPLAINT, CAUGHT, WASTED, NOT_AT_DESK, EMPTY, BUSY }
const DEFECTS := ["missing_bolt", "crack", "wrong_paint", "flipped_label", "dent"]
const DECOYS := ["scuff", "sticker_blue", "sticker_green"]
enum ActionResult { STARTED_REPAIR, STARTED_VENT, STARTED_FIX, STARTED_CLEAR, CREW_BUSY, NOTHING_TO_DO, NOT_ON_FLOOR, QUEUED, UNQUEUED }

var target: int = 0
var scrapped: int = 0
var clog_count: int = 0  # times a machine became clogged
var crew_busy: bool = false
var crew_target: String = ""
var crew_progress: float = 0.0  # 0..1 (0 while walking to the machine)
var crew_queued: String = ""  # next machine to fix (max 1), tap mode only
var fault_counts: Dictionary = {"OVERHEATED": 0, "JAMMED": 0}
var mistake_counts: Dictionary = {"jam": 0, "overclock": 0, "misroute": 0, "wrong_recipe": 0, "sloppy": 0}
var events: Array[Dictionary] = []  # this tick's {type: "mistake", mistake, machine_id, bot}; cleared each step()
var mistake_log: Array[Dictionary] = []  # all mistakes this run (for stats)
var day_mult: float = 1.0
var crew_speed: float = 1.0  # multiplies crew job durations (career upgrade < 1)
var actions: Array[Dictionary] = []  # {tick, machine_id}, {tick, release: true}, {tick, inspect: true, ship} or {tick, go: "floor"|"office"}
var worker: Worker
var complaints: int = 0
var caught: int = 0
var wasted: int = 0
var missed_by_type: Dictionary = {}  # defect -> count shipped with that defect this shift
var streak: int = 0  # consecutive correct rejects
var idle_ticks: int = 0  # worker had nothing useful to do
var qa_ticks: int = 0
var qa_queue_sum: int = 0  # sum of queue length over ticks (for the average)
var qa_queue_max: int = 0
var qa_full_seen: bool = false
var inspect_speed: float = 1.0  # multiplies inspect time (career upgrade < 1)
var qa_capacity: int = 8:
	set(v):
		qa_capacity = v
		if _qa != null:
			_qa.input_cap = v

var _config: SimConfig
var _qa: Machine = null
var _last_inspected: Dictionary = {}
var _qa_items: Array[Dictionary] = []  # products waiting for inspection, front first
var _qa_link: int = -1  # link index qa -> warehouse
var _inspect_left: int = 0
var _qa_rng := RandomNumberGenerator.new()  # defect/decoy rolls, separate from rng
var _crew_kind: int = ActionResult.NOTHING_TO_DO
var _crew_ticks: int = 0
var _crew_left: int = 0
var _crew_walking: bool = false
var _held: bool = false
var _shift_ticks: int = 1
var _by_id: Dictionary = {}
var _links: Array[Dictionary] = []  # {from: Machine, to: Machine, ticks: int}
var _out_links: Dictionary = {}  # Machine -> Array[int] indices into _links
var _transit: Array[Dictionary] = []  # {link: int, left: int, junk: bool, scrap: bool}


func _init(config: SimConfig, seed: int, roster: Array[Bot] = [], p_day_mult: float = 1.0) -> void:
	_config = config
	day_mult = p_day_mult
	rng.seed = seed
	_qa_rng.seed = seed * 31 + 17
	target = config.target
	_shift_ticks = maxi(1, roundi(config.shift_seconds * config.tick_rate))
	worker = Worker.new(roundi(config.transition_seconds * config.tick_rate), config.stairs, config.walk_speed / config.tick_rate)
	for md in config.machines:
		var m := Machine.new()
		m.id = String(md["id"])
		m.type = String(md["type"])
		var p: Array = md["pos"]
		m.pos = Vector2(float(p[0]), float(p[1]))
		m.input_resource = String(md.get("input", ""))
		m.output_resource = String(md.get("output", ""))
		m.input_cap = int(md.get("input_cap", 0))
		m.output_cap = int(md.get("output_cap", 0))
		m.heat_per_sec = float(md.get("heat_per_sec", 0.0))
		m.cool_per_sec = float(md.get("cool_per_sec", 0.0))
		m.process_ticks = maxi(1, roundi(float(md["process_time"]) * config.tick_rate))
		machines.append(m)
		_by_id[m.id] = m
		_out_links[m] = []
	_assign_bots(roster)
	for m in machines:
		if m.type == "qa":
			_qa = m
	qa_capacity = config.qa_capacity
	for ld in config.links:
		var from: Machine = _by_id[ld["from"]]
		_out_links[from].append(_links.size())
		_links.append({"from": from, "to": _by_id[ld["to"]], "ticks": maxi(1, roundi(float(ld["transit_time"]) * config.tick_rate))})
		if from.type == "qa":
			_qa_link = _links.size() - 1


func _assign_bots(roster: Array[Bot]) -> void:
	var pool: Array[Bot] = roster.duplicate()
	if pool.is_empty():
		var defs := _config.bot_defs.duplicate()
		for i in range(defs.size() - 1, 0, -1):  # seeded Fisher-Yates
			var j := rng.randi_range(0, i)
			var t: Dictionary = defs[i]
			defs[i] = defs[j]
			defs[j] = t
		for d: Dictionary in defs:
			pool.append(Bot.from_dict(d, _config.train_factor))
	if pool.is_empty():
		return
	var n := 0
	for m in machines:
		if m.type != "warehouse" and m.type != "qa":
			m.bot = pool[n % pool.size()]
			n += 1


func bot_for(machine_id: String) -> Bot:
	var m := get_machine(machine_id)
	return m.bot if m != null else null


func get_machine(id: String) -> Machine:
	return _by_id.get(id)


## Items currently moving along links: [{from, to, progress 0..1}].
func items_in_transit() -> Array:
	var out: Array = []
	for t in _transit:
		var l: Dictionary = _links[t["link"]]
		out.append({"from": l["from"].id, "to": "scrap" if t["scrap"] else l["to"].id, "via": l["to"].id, "junk": t["junk"], "progress": 1.0 - float(t["left"]) / float(l["ticks"])})
	return out


func step() -> void:
	events.clear()
	tick += 1
	_inspect_left = maxi(0, _inspect_left - 1)
	worker.step()
	_step_crew()
	_advance_transit()
	for m in machines:
		_step_machine(m)
	for m in machines:
		_dispatch(m)
	_track_qa()


func _advance_transit() -> void:
	var remaining: Array[Dictionary] = []
	for t in _transit:
		t["left"] -= 1
		if t["left"] <= 0:
			if t["scrap"]:
				scrapped += 1
			else:
				var dest: Machine = _links[t["link"]]["to"]
				dest.input_count += 1
				if dest == _qa and not t["junk"]:
					_qa_items.append(t["product"])
				if t["junk"]:
					if dest.junk_count == 0:
						clog_count += 1
					dest.junk_count += 1
		else:
			remaining.append(t)
	_transit = remaining


func is_over() -> bool:
	return tick >= _shift_ticks


## Score for the Foreman: shipped minus complaint penalties, never below 0.
func score() -> int:
	return maxi(0, shipped - complaints * _config.complaint_penalty)


## Products waiting at the QA desk, front first: [{defect, decoy, bot}].
func qa_queue() -> Array:
	return _qa_items.duplicate()


func inspect_busy() -> bool:
	return _inspect_left > 0


func worker_at_desk() -> bool:
	return worker.location == Worker.Location.OFFICE


func worker_location() -> Worker.Location:
	return worker.location


## Where the worker is heading (== worker_location() when not in transit).
func transit_target() -> Worker.Location:
	return worker.target


## Walk to the factory floor. No-op if there or heading there. Recorded for replay.
func go_to_floor() -> bool:
	actions.append({"tick": tick, "go": "floor"})
	return worker.go(Worker.Location.FLOOR)


## Walk back to the QA office. Refused (false) while a crew job runs. Recorded for replay.
func go_to_office() -> bool:
	actions.append({"tick": tick, "go": "office"})
	if crew_busy:
		return false
	return worker.go(Worker.Location.OFFICE)


## The product just inspected: {defect, decoy, bot}. Empty before the first inspect.
func last_inspected() -> Dictionary:
	return _last_inspected.duplicate()


## Inspect the front product: ship it or reject it. Recorded for replay.
func inspect(ship: bool) -> int:
	actions.append({"tick": tick, "inspect": true, "ship": ship})
	if _qa == null or not worker_at_desk():
		return InspectResult.NOT_AT_DESK
	if _inspect_left > 0:
		return InspectResult.BUSY
	if _qa_items.is_empty():
		return InspectResult.EMPTY
	var item: Dictionary = _qa_items.pop_front()
	_last_inspected = {"defect": item["defect"], "decoy": item.get("decoy", ""), "bot": item.get("bot", "")}
	_qa.input_count = maxi(0, _qa.input_count - 1)
	_inspect_left = maxi(1, roundi(_config.inspect_seconds * inspect_speed * _config.tick_rate))
	var bad := String(item["defect"]) != ""
	if ship:
		if _qa_link >= 0:
			_transit.append({"link": _qa_link, "left": _links[_qa_link]["ticks"], "junk": false, "scrap": false, "product": item})
		if bad:
			complaints += 1
			missed_by_type[item["defect"]] = int(missed_by_type.get(item["defect"], 0)) + 1
			streak = 0
			return InspectResult.COMPLAINT
		return InspectResult.SHIPPED
	if bad:
		caught += 1
		streak += 1
		return InspectResult.CAUGHT
	wasted += 1
	streak = 0
	return InspectResult.WASTED


func _has_fixable() -> bool:
	for m in machines:
		if _job_kind(m) != ActionResult.NOTHING_TO_DO:
			return true
	return false


func _track_qa() -> void:
	if _qa == null:
		return
	var n := _qa_items.size()
	qa_ticks += 1
	qa_queue_sum += n
	qa_queue_max = maxi(qa_queue_max, n)
	if n >= qa_capacity:
		qa_full_seen = true
	if crew_busy:
		return
	var fixable := _has_fixable()
	if worker_at_desk():
		if n == 0 and not fixable:
			idle_ticks += 1
	elif not fixable:  # walking about or standing on the floor with nothing to fix
		idle_ticks += 1


## Product data for a freshly assembled item. Defect chance = mean "sloppy" of the assembler's
## bot and the processors' bots (each scaled by ramp, day_mult, training). Blame is weighted by chance.
func _make_product(asm: Machine) -> Dictionary:
	var makers: Array[Machine] = []
	for m in machines:
		if m == asm or m.type == "processor":
			if m.bot != null:
				makers.append(m)
	var total := 0.0
	var chances: Array[float] = []
	for m in makers:
		var c := m.bot.sloppy_chance(ramp(), day_mult)
		chances.append(c)
		total += c
	var p := total / float(maxi(1, makers.size()))
	var roll := _qa_rng.randf()
	var kind := _qa_rng.randi_range(0, DEFECTS.size() - 1)
	var pick := _qa_rng.randf() * total
	var decoy_roll := _qa_rng.randf()
	var decoy_kind := _qa_rng.randi_range(0, DECOYS.size() - 1)
	var prod := {"defect": "", "decoy": "", "bot": asm.bot.name if asm.bot != null else ""}
	if p > 0.0 and roll < p:
		var culprit := makers[0]
		var acc := 0.0
		for i in makers.size():
			acc += chances[i]
			if pick < acc:
				culprit = makers[i]
				break
		prod["defect"] = DEFECTS[kind]
		prod["bot"] = culprit.bot.name
		mistake_counts["sloppy"] += 1
		var ev := {"type": "mistake", "mistake": "sloppy", "machine_id": culprit.id, "bot": culprit.bot.name}
		events.append(ev)
		mistake_log.append(ev)
	elif decoy_roll < _config.decoy_chance:
		prod["decoy"] = DECOYS[decoy_kind]
	return prod


## Fault pressure multiplier: linear from ramp_start to ramp_end over the shift.
func ramp() -> float:
	return lerpf(_config.ramp_start, _config.ramp_end, clampf(float(tick) / float(_shift_ticks), 0.0, 1.0))


## Ask the crew to act on a machine: the worker walks there, then the job runs. Recorded for replay.
## While busy, tapping another machine queues it (max 1); tapping the queued one again cancels it.
func request_action(machine_id: String) -> int:
	actions.append({"tick": tick, "machine_id": machine_id})
	if worker.location != Worker.Location.FLOOR:
		return ActionResult.NOT_ON_FLOOR
	var m := get_machine(machine_id)
	var kind := _job_kind(m)
	if crew_busy:
		if crew_queued == machine_id:
			crew_queued = ""
			return ActionResult.UNQUEUED
		if crew_queued != "" or machine_id == crew_target or _config.repair_mode != "tap":
			return ActionResult.CREW_BUSY
		if kind != ActionResult.NOTHING_TO_DO:
			crew_queued = machine_id
			return ActionResult.QUEUED
	if kind != ActionResult.NOTHING_TO_DO:
		worker.go(Worker.Location.FLOOR)  # stop leaving, if on the way to the stairs
		_start_walk(m)
	return kind


func _job_kind(m: Machine) -> int:
	return CrewJob.kind(m, _config)


func _start_walk(m: Machine) -> void:
	crew_busy = true
	crew_target = m.id
	crew_progress = 0.0
	_held = true
	_crew_walking = true
	worker.walk_to(m.pos)
	if not worker.is_walking():
		_begin_job()


## On arrival: the job (re-checked now) starts its timer; nothing to do -> on to the queued fix.
func _begin_job() -> void:
	_crew_walking = false
	_crew_kind = _job_kind(_by_id[crew_target])
	if _crew_kind == ActionResult.NOTHING_TO_DO:
		_end_job()
		return
	_crew_ticks = maxi(1, roundi(CrewJob.seconds(_crew_kind, _config) * crew_speed * _config.tick_rate))
	_crew_left = _crew_ticks


func crew_walking() -> bool:  # the crew job is still the walk to its machine
	return crew_busy and _crew_walking


## Hold mode: stop holding. Cancels the job and resets progress. No-op in tap mode.
func release_action() -> void:
	actions.append({"tick": tick, "release": true})
	if _config.repair_mode == "hold":
		_held = false
		if crew_busy:
			_end_job()


func _end_job() -> void:
	crew_busy = false
	crew_target = ""
	crew_progress = 0.0
	_held = false
	_crew_walking = false
	var next := get_machine(crew_queued)
	crew_queued = ""
	if _job_kind(next) != ActionResult.NOTHING_TO_DO and worker.location == Worker.Location.FLOOR:
		_start_walk(next)


func _step_crew() -> void:
	for m in machines:
		m.venting = false
	if not crew_busy or not (_held or _config.repair_mode == "tap"):
		return
	if _crew_walking:
		if not worker.is_walking():
			_begin_job()
		return
	var m: Machine = _by_id[crew_target]
	if _crew_kind == ActionResult.STARTED_VENT:
		m.venting = true
	_crew_left -= 1
	crew_progress = 1.0 - float(_crew_left) / float(_crew_ticks)
	if _crew_left > 0:
		return
	CrewJob.finish(m, _crew_kind)
	_end_job()


## Replay a recorded run: same seed + same action list => same result.
static func replay(config: SimConfig, seed: int, recorded: Array[Dictionary], ticks: int) -> Factory:
	var f := Factory.new(config, seed)
	var i := 0
	for _t in ticks:
		while i < recorded.size() and int(recorded[i]["tick"]) <= f.tick:
			if recorded[i].has("release"):
				f.release_action()
			elif recorded[i].has("inspect"):
				f.inspect(bool(recorded[i]["ship"]))
			elif recorded[i].has("go"):
				if recorded[i]["go"] == "floor":
					f.go_to_floor()
				else:
					f.go_to_office()
			else:
				f.request_action(String(recorded[i]["machine_id"]))
			i += 1
		f.step()
	return f


func _step_machine(m: Machine) -> void:
	if m.type == "qa":  # never processes on its own; the worker ships items
		m.state = Machine.State.CLOGGED if m.junk_count > 0 else Machine.State.IDLE
		return
	if m.is_faulted():
		return
	if m.venting:
		m.state = Machine.State.IDLE
		m.heat = maxf(0.0, m.heat - _config.vent_cool_per_sec / _config.tick_rate)
		return
	if m.junk_count > 0:
		m.state = Machine.State.CLOGGED
		m.heat = maxf(0.0, m.heat - m.cool_per_sec / float(_config.tick_rate))
		return
	_advance_machine(m)
	var rate := float(_config.tick_rate)
	if m.state == Machine.State.WORKING:
		m.heat += m.heat_per_sec * (_config.overclock_heat_mult if m.overclocked else 1.0) / rate
		if m.heat >= 100.0:
			m.heat = 100.0
			m.overclocked = false
			_fault(m, Machine.State.OVERHEATED)
		elif _roll(m, "jam"):
			_mistake(m, "jam")
			_fault(m, Machine.State.JAMMED)
		else:
			if not m.overclocked and _roll(m, "overclock"):
				_mistake(m, "overclock")
				m.overclocked = true
			if not m.misrouted and not _out_links[m].is_empty() and _roll(m, "misroute"):
				_mistake(m, "misroute")
				m.misrouted = true
			if not m.wrong_recipe and (m.type == "processor" or m.type == "assembler") and _roll(m, "wrong_recipe"):
				_mistake(m, "wrong_recipe")
				m.wrong_recipe = true
	else:
		m.heat = maxf(0.0, m.heat - m.cool_per_sec / rate)


func _roll(m: Machine, mistake: String) -> bool:
	if m.bot == null:
		return false
	var p := m.bot.rate_per_tick(mistake, _config.tick_rate, ramp(), day_mult)
	return p > 0.0 and rng.randf() < p


func _mistake(m: Machine, mistake: String) -> void:
	mistake_counts[mistake] += 1
	var ev := {"type": "mistake", "mistake": mistake, "machine_id": m.id, "bot": m.bot.name}
	events.append(ev)
	mistake_log.append(ev)


func _fault(m: Machine, s: Machine.State) -> void:
	m.state = s
	fault_counts[m.state_name()] += 1


func _advance_machine(m: Machine) -> void:
	if m.busy:
		m.speed_frac += _config.overclock_speed_mult if m.overclocked else 1.0
		var add := int(m.speed_frac)
		m.speed_frac -= add
		m.progress = mini(m.progress + add, m.process_ticks)
		if m.progress >= m.process_ticks:
			if m.type == "warehouse":
				shipped += 1
				m.busy = false
				m.progress = 0
			elif m.output_count < m.output_cap:
				m.output_count += 1
				if m.type == "assembler":
					m.output_products.append(_make_product(m))
				if m.wrong_recipe:
					m.output_junk += 1
				m.busy = false
				m.progress = 0
			else:
				m.state = Machine.State.BLOCKED
				return
		else:
			m.state = Machine.State.WORKING
			return
	# not busy: try to start the next item
	if m.type != "warehouse" and m.output_count >= m.output_cap:
		m.state = Machine.State.BLOCKED
		return
	if m.type != "generator":
		if m.input_count <= 0:
			m.state = Machine.State.STARVED
			return
		m.input_count -= 1
	m.busy = true
	m.progress = 0
	m.state = Machine.State.WORKING


## Move one finished item from m's output onto a link whose target has room.
func _dispatch(m: Machine) -> void:
	if m.output_count <= 0:
		return
	var idxs: Array = _out_links[m]
	for k in idxs.size():
		var li: int = idxs[(m.next_link + k) % idxs.size()]
		var to: Machine = _links[li]["to"]
		if to.input_count + _in_flight_to(to) < to.input_cap:
			m.output_count -= 1
			var junk := m.output_junk > 0
			if junk:
				m.output_junk -= 1
			var prod: Dictionary = m.output_products.pop_front() if not m.output_products.is_empty() else {}
			_transit.append({"link": li, "left": _links[li]["ticks"], "junk": junk, "scrap": m.misrouted, "product": prod})
			m.next_link = (m.next_link + k + 1) % idxs.size()
			return


func _in_flight_to(m: Machine) -> int:
	var n := 0
	for t in _transit:
		if _links[t["link"]]["to"] == m:
			n += 1
	return n
