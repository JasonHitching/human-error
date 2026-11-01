class_name RunStats
extends RefCounted
## Local run stats persisted to user://stats.json. Pure data + file IO, nothing leaves the device.
## Time is always passed in (unix seconds) so tests are deterministic.

const PATH := "user://stats.json"
const BACK_TO_BACK_SECS := 30
const SESSION_GAP_SECS := 600

var careers_started: int = 0
var careers_finished: int = 0
var best_days: int = 0
var total_days: int = 0
var finished_days: int = 0
var shifts_played: int = 0
var total_complaints: int = 0
var last_career_end_unix: int = 0
var last_event_unix: int = 0
var sessions: int = 0
var careers_in_session: int = 0
var session_careers: Array = []  # careers_in_session of past sessions
var streak: int = 0
var best_streak: int = 0
var path: String = PATH


static func load_from(p: String = PATH) -> RunStats:
	var s := RunStats.new()
	s.path = p
	if not FileAccess.file_exists(p):
		return s
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	if parsed is Dictionary:
		s._apply(parsed as Dictionary)
	return s


func _apply(d: Dictionary) -> void:
	careers_started = maxi(0, int(d.get("careers_started", 0)))
	careers_finished = maxi(0, int(d.get("careers_finished", 0)))
	best_days = maxi(0, int(d.get("best_days", 0)))
	total_days = maxi(0, int(d.get("total_days", 0)))
	finished_days = maxi(0, int(d.get("finished_days", 0)))
	shifts_played = maxi(0, int(d.get("shifts_played", 0)))
	total_complaints = maxi(0, int(d.get("total_complaints", 0)))
	last_career_end_unix = maxi(0, int(d.get("last_career_end_unix", 0)))
	last_event_unix = maxi(0, int(d.get("last_event_unix", 0)))
	sessions = maxi(0, int(d.get("sessions", 0)))
	careers_in_session = maxi(0, int(d.get("careers_in_session", 0)))
	streak = maxi(0, int(d.get("streak", 0)))
	best_streak = maxi(0, int(d.get("best_streak", 0)))
	session_careers = []
	var sc: Variant = d.get("session_careers", [])
	if sc is Array:
		for v: Variant in sc:
			session_careers.append(maxi(0, int(v)))


func to_dict() -> Dictionary:
	return {
		"careers_started": careers_started, "careers_finished": careers_finished,
		"best_days": best_days, "total_days": total_days, "finished_days": finished_days,
		"shifts_played": shifts_played, "total_complaints": total_complaints,
		"last_career_end_unix": last_career_end_unix, "last_event_unix": last_event_unix,
		"sessions": sessions, "careers_in_session": careers_in_session,
		"session_careers": session_careers, "streak": streak, "best_streak": best_streak,
	}


func save() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(to_dict()))


func _touch(now: int) -> void:
	if sessions == 0 or now - last_event_unix > SESSION_GAP_SECS:
		if sessions > 0:
			session_careers.append(careers_in_session)
		sessions += 1
		careers_in_session = 0
	last_event_unix = now


func career_started(now: int) -> void:
	_touch(now)
	careers_started += 1
	careers_in_session += 1
	if last_career_end_unix > 0 and now - last_career_end_unix <= BACK_TO_BACK_SECS:
		streak += 1
	else:
		streak = 1
	best_streak = maxi(best_streak, streak)
	save()


func shift_ended(now: int, complaints: int) -> void:
	_touch(now)
	shifts_played += 1
	total_days += 1
	total_complaints += complaints
	save()


func career_finished(now: int, days: int) -> void:
	_touch(now)
	careers_finished += 1
	finished_days += days
	best_days = maxi(best_days, days)
	last_career_end_unix = now
	save()


func avg_days() -> float:
	return float(finished_days) / careers_finished if careers_finished > 0 else 0.0


func avg_careers_per_session() -> float:
	return float(careers_started) / sessions if sessions > 0 else 0.0


func summary() -> String:
	return "STATS\nCareers: %d (finished %d)\nBest days: %d\nAverage days: %.1f\nBest back-to-back streak: %d\nCareers per session: %.1f" % [careers_started, careers_finished, best_days, avg_days(), best_streak, avg_careers_per_session()]
