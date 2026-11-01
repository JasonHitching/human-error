extends TestCase

const P := "user://test_stats.json"


func _run(s: RunStats, t: int, days: int) -> void:
	s.career_started(t)
	for i in days:
		s.shift_ended(t + i, 1)
	s.career_finished(t + days, days)


func test_counters() -> void:
	var s := RunStats.new()
	s.path = P
	_run(s, 1000, 3)
	assert_eq(s.careers_started, 1)
	assert_eq(s.careers_finished, 1)
	assert_eq(s.total_days, 3)
	assert_eq(s.shifts_played, 3)
	assert_eq(s.total_complaints, 3)
	assert_eq(s.best_days, 3)
	assert_near(s.avg_days(), 3.0)
	assert_eq(s.last_career_end_unix, 1003)


func test_back_to_back_rule() -> void:
	var s := RunStats.new()
	s.path = P
	_run(s, 1000, 2)  # ends 1002
	s.career_started(1030)  # 28 s later: back-to-back
	assert_eq(s.streak, 2)
	s.career_finished(1040, 1)  # ends 1040
	s.career_started(1071)  # 31 s later: breaks
	assert_eq(s.streak, 1)
	assert_eq(s.best_streak, 2)


func test_session_rule() -> void:
	var s := RunStats.new()
	s.path = P
	_run(s, 1000, 1)
	s.career_started(1100)
	assert_eq(s.sessions, 1)
	assert_eq(s.careers_in_session, 2)
	s.career_started(1100 + 601)
	assert_eq(s.sessions, 2)
	assert_eq(s.careers_in_session, 1)
	assert_eq(s.session_careers, [2])
	assert_near(s.avg_careers_per_session(), 1.5)


func test_corrupt_and_missing_fall_back() -> void:
	var f := FileAccess.open(P, FileAccess.WRITE)
	f.store_string("{not json ]]")
	f.close()
	var s := RunStats.load_from(P)
	assert_eq(s.careers_started, 0)
	f = FileAccess.open(P, FileAccess.WRITE)
	f.store_string("[1,2]")
	f.close()
	assert_eq(RunStats.load_from(P).sessions, 0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(P))
	assert_eq(RunStats.load_from(P).best_days, 0)
	assert_eq(RunStats.load_from("user://nope/none.json").careers_started, 0)


func test_save_roundtrip_sample() -> void:
	var s := RunStats.new()
	s.path = P
	_run(s, 1000, 4)
	_run(s, 1010, 2)
	_run(s, 5000, 5)
	var r := RunStats.load_from(P)
	assert_eq(r.careers_started, 3)
	assert_eq(r.best_days, 5)
	assert_eq(r.best_streak, 2)
	assert_eq(r.sessions, 2)
	print("SAMPLE stats.json: " + FileAccess.get_file_as_string(P))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(P))
