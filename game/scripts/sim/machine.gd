class_name Machine
extends RefCounted

enum State { IDLE, WORKING, STARVED, BLOCKED, OVERHEATED, JAMMED, CLOGGED }  # OVERHEATED/JAMMED are faults; CLOGGED = junk in input (cause upstream)

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
var bot: Bot = null  # null for the warehouse
var overclocked: bool = false
var speed_frac: float = 0.0  # fractional progress carry when overclocked
var misrouted: bool = false  # output goes to the scrap bin
var wrong_recipe: bool = false  # output is junk
var junk_count: int = 0  # junk items in input (counted within input_count)
var output_junk: int = 0  # junk items in output (counted within output_count)
var venting: bool = false  # crew is venting this machine (paused, cooling)
var next_link: int = 0  # round-robin pointer over outgoing links


func state_name() -> String:
	return State.keys()[state]


func is_faulted() -> bool:
	return state == State.OVERHEATED or state == State.JAMMED
