class_name Machine
extends RefCounted

enum State { IDLE, WORKING, STARVED, BLOCKED, OVERHEATED, JAMMED }  # last two are root faults

var id: String
var type: String
var pos: Vector2
var input_resource: String = ""
var output_resource: String = ""
var input_cap: int = 0
var output_cap: int = 0
var process_ticks: int = 1

var input_count: int = 0
var output_count: int = 0
var progress: int = 0  # ticks of work done on current item
var busy: bool = false  # an item is being processed
var state: State = State.IDLE
var heat: float = 0.0  # 0..100
var heat_per_sec: float = 0.0
var cool_per_sec: float = 0.0
var jam_chance_per_sec: float = 0.0
var venting: bool = false  # crew is venting this machine (paused, cooling)
var next_link: int = 0  # round-robin pointer over outgoing links


func state_name() -> String:
	return State.keys()[state]


func is_faulted() -> bool:
	return state == State.OVERHEATED or state == State.JAMMED
