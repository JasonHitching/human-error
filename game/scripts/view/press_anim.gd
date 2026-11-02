class_name PressAnim
extends RefCounted
## Meshy press animation for processor machines: frames res://assets/sprites/press/press_0..5.png
## (0 idle, 1 descend, 2 pressed, 3 sparks, 4 smoke, 5 reset). Drawn in FactoryView's _draw so it
## depth-sorts with the other floor objects; this class only picks the frame.

const FRAMES := 6
const FPS := 9.0
const IDLE := 0
const PRESSED := 2
const SCALE := 0.94  # sprite px -> baked-2x px: the baked belt spans two cells, end to end


## Frame for a machine in `state` at clock `t` seconds. Effects off: no spark/smoke frames, held on idle.
static func frame(state: int, t: float, effects: bool) -> int:
	match state:
		Machine.State.WORKING:
			return int(t * FPS) % FRAMES if effects else IDLE
		Machine.State.JAMMED, Machine.State.OVERHEATED:
			return PRESSED
	return IDLE


## Texture name for a frame (Sprites.tex name).
static func sprite_name(i: int) -> String:
	return "press/press_%d" % i


## True when the frame files exist (else the caller draws the static machine sprite).
static func available() -> bool:
	return Sprites.tex(sprite_name(IDLE)) != null
