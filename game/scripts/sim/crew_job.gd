class_name CrewJob
extends RefCounted
## What a crew job on a machine is, how long it takes and what it does. Static helpers for Factory.


## The job a machine needs right now (a Factory.ActionResult STARTED_*), or NOTHING_TO_DO.
static func kind(m: Machine, cfg: SimConfig) -> int:
	if m == null:
		return Factory.ActionResult.NOTHING_TO_DO
	if m.is_faulted():
		return Factory.ActionResult.STARTED_REPAIR
	if m.state == Machine.State.CLOGGED:
		return Factory.ActionResult.STARTED_CLEAR
	if m.overclocked or m.misrouted or m.wrong_recipe:
		return Factory.ActionResult.STARTED_FIX
	if m.state == Machine.State.WORKING and m.heat >= cfg.vent_min_heat:
		return Factory.ActionResult.STARTED_VENT
	return Factory.ActionResult.NOTHING_TO_DO


static func seconds(k: int, cfg: SimConfig) -> float:
	match k:
		Factory.ActionResult.STARTED_REPAIR: return cfg.repair_seconds
		Factory.ActionResult.STARTED_CLEAR: return cfg.clear_seconds
		Factory.ActionResult.STARTED_FIX: return cfg.fix_seconds
		Factory.ActionResult.STARTED_VENT: return cfg.vent_seconds
	return 0.0


## A finished job's effect on its machine.
static func finish(m: Machine, k: int) -> void:
	if k == Factory.ActionResult.STARTED_REPAIR:
		m.state = Machine.State.IDLE
		m.heat = 0.0
	if k == Factory.ActionResult.STARTED_FIX:
		if m.overclocked:
			m.heat = maxf(0.0, m.heat - 50.0)
		m.overclocked = false
		m.misrouted = false
		m.wrong_recipe = false
	if k == Factory.ActionResult.STARTED_CLEAR:
		m.input_count = maxi(0, m.input_count - m.junk_count)
		m.junk_count = 0
	m.venting = false
