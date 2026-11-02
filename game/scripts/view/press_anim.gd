class_name PressAnim
extends RefCounted
## Meshy press animation for processor machines: frames res://assets/sprites/press/press_0..5.png
## (0 idle, 1 descend, 2 pressed, 3 sparks, 4 smoke, 5 reset). Drawn in FactoryView's _draw so it
## depth-sorts with the other floor objects; this class only picks the frame.

const FRAMES := 6
const FPS := 9.0
const IDLE := 0
const PRESSED := 2
## Press sprite px -> baked-2x px. Chosen so the baked belt reaches exactly the far end of the two
## neighbouring belt tiles (1.5 cells each side of the press cell): the press owns those tiles' belt
## and IsoFloor hides them (FIX-7). Bigger would cover the bend that follows; smaller leaves a gap.
const SCALE := 1.38
## Sprite px from the anchor (x) to either belt tip, measured on press_0..5 (10..288 around x=150).
const BELT_REACH_PX := 139.0
## Sprite px width of the press arch (the machine body without its belt arms), measured on press_0.
const BODY_PX := 172.0


## Logical px (at scale 1) the baked belt reaches along screen x from the ground point.
static func belt_reach() -> float:
	return BELT_REACH_PX * 0.5 * SCALE


## Logical px width of the press body as drawn (scale 1).
static func body_width() -> float:
	return BODY_PX * 0.5 * SCALE


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
