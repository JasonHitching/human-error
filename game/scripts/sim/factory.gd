class_name Factory
extends RefCounted
## Headless factory simulation. Fixed timestep: one step() == one tick.

var tick: int = 0
var shipped: int = 0
var machines: Array[Machine] = []
var rng := RandomNumberGenerator.new()  # sole source of randomness (used from #4)

var _config: SimConfig
var _by_id: Dictionary = {}
var _links: Array[Dictionary] = []  # {from: Machine, to: Machine, ticks: int}
var _out_links: Dictionary = {}  # Machine -> Array[int] indices into _links
var _transit: Array[Dictionary] = []  # {link: int, left: int}


func _init(config: SimConfig, seed: int) -> void:
	_config = config
	rng.seed = seed
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
		m.process_ticks = maxi(1, roundi(float(md["process_time"]) * config.tick_rate))
		machines.append(m)
		_by_id[m.id] = m
		_out_links[m] = []
	for ld in config.links:
		var from: Machine = _by_id[ld["from"]]
		_out_links[from].append(_links.size())
		_links.append({"from": from, "to": _by_id[ld["to"]], "ticks": maxi(1, roundi(float(ld["transit_time"]) * config.tick_rate))})


func get_machine(id: String) -> Machine:
	return _by_id.get(id)


## Items currently moving along links: [{from, to, progress 0..1}].
func items_in_transit() -> Array:
	var out: Array = []
	for t in _transit:
		var l: Dictionary = _links[t["link"]]
		out.append({"from": l["from"].id, "to": l["to"].id, "progress": 1.0 - float(t["left"]) / float(l["ticks"])})
	return out


func step() -> void:
	tick += 1
	_advance_transit()
	for m in machines:
		_step_machine(m)
	for m in machines:
		_dispatch(m)


func _advance_transit() -> void:
	var remaining: Array[Dictionary] = []
	for t in _transit:
		t["left"] -= 1
		if t["left"] <= 0:
			(_links[t["link"]]["to"] as Machine).input_count += 1
		else:
			remaining.append(t)
	_transit = remaining


func _step_machine(m: Machine) -> void:
	if m.busy:
		m.progress = mini(m.progress + 1, m.process_ticks)
		if m.progress >= m.process_ticks:
			if m.type == "warehouse":
				shipped += 1
				m.busy = false
				m.progress = 0
			elif m.output_count < m.output_cap:
				m.output_count += 1
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
			_transit.append({"link": li, "left": _links[li]["ticks"]})
			m.next_link = (m.next_link + k + 1) % idxs.size()
			return


func _in_flight_to(m: Machine) -> int:
	var n := 0
	for t in _transit:
		if _links[t["link"]]["to"] == m:
			n += 1
	return n
