class_name Pacing
extends RefCounted
## Pacing director: decides when NEW bot mistakes may happen so problems come in waves with breathers.
## A "problem" = a machine that needs the crew (fault, clog, overclock, misroute, wrong recipe).
## Pure sim; random jitter comes from the factory's seeded RNG only. Heat-driven overheating is not gated.

var day: int = 1
var active: int = 0  # problems right now (machines needing the crew)
var calm_ticks: int = 0  # ticks since the last problem was fixed (0 while a problem is active)
var calm_started: bool = false  # true for the one tick a calm window begins

var _cfg: SimConfig
var _breather_left: int = 0
var _had_problem: bool = false
var _wave_left: int = 0
var _burst_left: int = 0
var _rng: RandomNumberGenerator


func _init(config: SimConfig, rng: RandomNumberGenerator) -> void:
	_cfg = config
	_rng = rng
	_wave_left = _ticks(config.wave_seconds * (0.5 + rng.randf()))


func _ticks(secs: float) -> int:
	return maxi(1, roundi(secs * _cfg.tick_rate))


func max_problems() -> int:
	return _cfg.max_active_problems + (1 if day >= 6 else 0)


func breather_seconds() -> float:
	return maxf(_cfg.breather_floor, _cfg.breather_seconds - _cfg.breather_shrink_per_day * float(maxi(0, day - 1)))


## May a new mistake happen right now? (Rolls that fail this are simply re-rolled next tick: delayed, not dropped.)
func allows() -> bool:
	return active < max_problems() and _breather_left <= 0


## Multiplier on mistake rates: load compensation, and the wave burst.
func rate_mult() -> float:
	return _cfg.mistake_rate_mult * (_cfg.burst_mult if _burst_left > 0 else 1.0)


func note_mistake() -> void:
	active += 1


func in_burst() -> bool:
	return _burst_left > 0


## Call once per tick before the machines roll, with the number of machines that need the crew.
func step(problems: int) -> void:
	calm_started = false
	active = problems
	if problems > 0:
		_had_problem = true
		calm_ticks = 0
		_breather_left = 0
	else:
		if _had_problem:
			_had_problem = false
			_breather_left = _ticks(breather_seconds())
			calm_started = true
		calm_ticks += 1
		_breather_left = maxi(0, _breather_left - 1)
	_burst_left = maxi(0, _burst_left - 1)
	_wave_left -= 1
	if _wave_left <= 0 and _cfg.wave_seconds > 0.0 and _breather_left <= 0 and problems == 0:
		_burst_left = _ticks(_cfg.burst_seconds)
		_wave_left = _ticks(_cfg.wave_seconds * (0.8 + 0.4 * _rng.randf()))
	elif _wave_left <= 0:
		_wave_left = 1  # wait for the calm to open before starting the wave
