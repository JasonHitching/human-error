class_name Machine
extends RefCounted

enum State { IDLE, WORKING, STARVED, BLOCKED }  # fault states (OVERHEATED, JAMMED) added later

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
var next_link: int = 0  # round-robin pointer over outgoing links


func state_name() -> String:
	return State.keys()[state]
