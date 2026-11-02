class_name FlowReadout
extends RefCounted
## Production-flow reading of the sim (view side, read-only): belt queues, input fill, bottleneck.

const FULL_FILL := 0.5  # input queue at/over this share marks a machine as backed up
const ROLE_OK := "ok"
const ROLE_STARVED := "starved"
const ROLE_BLOCKED := "blocked"
const ROLE_BOTTLENECK := "bottleneck"


## Share of the machine's input queue that is filled, 0..1 (0 when it has no input queue).
static func input_fill(m: Machine) -> float:
	if m.input_cap <= 0:
		return 0.0
	return clampf(float(m.input_count) / float(m.input_cap), 0.0, 1.0)


## Items waiting on the belt from -> to: in transit, plus those held back at the sender
## because the receiver's input queue is full.
static func queued_on(f: Factory, from_id: String, to_id: String) -> int:
	var n := 0
	for it: Dictionary in f.items_in_transit():
		if it["from"] == from_id and it["via"] == to_id:
			n += 1
	var a := f.get_machine(from_id)
	var b := f.get_machine(to_id)
	if a != null and b != null and b.input_cap > 0 and b.input_count >= b.input_cap:
		n += a.output_count
	return n


## Id of the machine limiting throughput: working (or faulted) with the fullest input queue. "" if none.
static func bottleneck(f: Factory) -> String:
	var best := ""
	var best_fill := FULL_FILL - 0.0001
	for m in f.machines:
		if m.type == "warehouse" or m.type == "qa" or m.state == Machine.State.STARVED or m.state == Machine.State.BLOCKED:
			continue
		var fill := input_fill(m)
		if fill > best_fill:
			best_fill = fill
			best = m.id
	return best


## Flow role of a machine: bottleneck, starved (waiting for input), blocked (output backed up) or ok.
static func role(f: Factory, m: Machine) -> String:
	if m.id == bottleneck(f):
		return ROLE_BOTTLENECK
	if m.state == Machine.State.STARVED:
		return ROLE_STARVED
	if m.state == Machine.State.BLOCKED:
		return ROLE_BLOCKED
	return ROLE_OK
