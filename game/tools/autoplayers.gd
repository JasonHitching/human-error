class_name Autoplayers
extends RefCounted
## Scripted players for sim_runner (not in-game bots). They act as if holding (never release).

const NAMES := ["none", "greedy"]
const VENT_HEAT := 80.0


## Call once per tick before factory.step().
static func act(player: String, f: Factory) -> void:
	if player != "greedy" or f.crew_busy:
		return
	for m in f.machines:
		if m.is_faulted():
			f.request_action(m.id)
			return
	for m in f.machines:
		if m.overclocked:
			f.request_action(m.id)
			return
	var hottest: Machine = null
	for m in f.machines:
		if m.state == Machine.State.WORKING and m.heat >= VENT_HEAT and (hottest == null or m.heat > hottest.heat):
			hottest = m
	if hottest != null:
		f.request_action(hottest.id)
