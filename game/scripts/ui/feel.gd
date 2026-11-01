class_name Feel
extends RefCounted
## View-side game-feel state: call streak, pitch steps, short decaying effects. No sim access.

const MAX_STEPS := 7
const MILESTONES := [5, 10, 20]
const QUICK_SECONDS := 2.5
const ALERT_GAP := 3.0
const SHAKE_TIME := 0.08
const SHAKE_PX := 3.0

var streak: int = 0
var stamp_t: float = 0.0  # >0 while the stamp punch plays
var stamp_ship: bool = true
var shake_t: float = 0.0
var flash_t: float = 0.0
var flash_color: Color = Color(1, 1, 1)
var caught_t: float = 0.0
var gold_t: float = 0.0
var pop_t: float = 0.0
var clock: float = 0.0
var _last_alert: float = -100.0


## Semitone offset for the next ship/reject sound.
func pitch_steps() -> int:
	return mini(streak, MAX_STEPS)


## Register one inspect. correct: right call; perfect: subtle/quick catch. Returns sound names to play.
func on_call(ship: bool, correct: bool, perfect: bool, complaint: bool) -> Array[String]:
	var sounds: Array[String] = []
	stamp_t = 0.3
	stamp_ship = ship
	if correct:
		sounds.append("ship" if ship else "reject")
		streak += 1
		pop_t = 0.25
		if streak in MILESTONES:
			sounds.append("fanfare")
			gold_t = 0.9
		if perfect:
			caught_t = 0.7
			flash_t = 0.2
			flash_color = Color(1, 1, 1)
			shake_t = SHAKE_TIME
	else:
		sounds.append("ship" if ship else "reject")
		if streak > 0:
			sounds.append("deflate")
		streak = 0
		pop_t = 0.25
		if complaint:
			flash_t = 0.35
			flash_color = Color(0.6, 0.1, 0.1)
			sounds.append("complaint")
	return sounds


func reset() -> void:
	streak = 0
	stamp_t = 0.0
	shake_t = 0.0
	flash_t = 0.0
	caught_t = 0.0
	gold_t = 0.0
	pop_t = 0.0


func update(d: float) -> void:
	clock += d
	stamp_t = maxf(0.0, stamp_t - d)
	shake_t = maxf(0.0, shake_t - d)
	flash_t = maxf(0.0, flash_t - d)
	caught_t = maxf(0.0, caught_t - d)
	gold_t = maxf(0.0, gold_t - d)
	pop_t = maxf(0.0, pop_t - d)


## Screen punch offset: a few px, decaying to exactly zero within SHAKE_TIME.
func shake_offset() -> Vector2:
	if shake_t <= 0.0:
		return Vector2.ZERO
	var k := shake_t / SHAKE_TIME
	var dir := 1.0 if int(shake_t * 1000.0) % 2 == 0 else -1.0
	return Vector2(dir * SHAKE_PX * k, -SHAKE_PX * k * 0.5)


## Rate limit for the wall-monitor alert blip: at most one per ALERT_GAP seconds.
func allow_alert() -> bool:
	if clock - _last_alert < ALERT_GAP:
		return false
	_last_alert = clock
	return true


func is_quiet() -> bool:
	return stamp_t == 0.0 and shake_t == 0.0 and flash_t == 0.0 and caught_t == 0.0 and gold_t == 0.0 and pop_t == 0.0
