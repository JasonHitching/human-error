extends TestCase

const P := "user://t_save.json"
const B := "user://t_save.bad.json"
const L := "user://t_stats.json"


func _clean() -> void:
	for f: String in [P, B, L, P + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))


func _put(p: String, txt: String) -> void:
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(txt)
	f.close()


func _played() -> Meta:
	var m := Meta.new()
	m.stats.career_started(1000)
	m.stats.shift_ended(1001, 2)
	m.stats.career_finished(1002, 4)
	m.tier = 2
	m.unlocked = ["a"]
	return m


func test_round_trip() -> void:
	_clean()
	var m := _played()
	assert_true(SaveIO.write_meta(m, P))
	var r := SaveIO.load_meta(P, B, L)
	assert_eq(r.to_dict(), m.to_dict())
	assert_eq(r.version, 1)
	assert_true(not FileAccess.file_exists(P + ".tmp"), "no half file")
	_clean()


func test_missing_gives_defaults() -> void:
	_clean()
	var r := SaveIO.load_meta(P, B, L)
	assert_eq(r.stats.careers_started, 0)
	assert_eq(r.tier, 1)
	assert_true(not FileAccess.file_exists(P))


func test_corrupt_and_too_new_backed_up() -> void:
	_clean()
	_put(P, "{not json ]]")
	assert_eq(SaveIO.load_meta(P, B, L).stats.careers_started, 0)
	assert_eq(FileAccess.get_file_as_string(B), "{not json ]]")
	_clean()
	_put(P, '{"version": 99, "stats": {"careers_started": 7}}')
	assert_eq(SaveIO.load_meta(P, B, L).stats.careers_started, 0)
	assert_true(FileAccess.file_exists(B))
	assert_eq(FileAccess.get_file_as_string(P), '{"version": 99, "stats": {"careers_started": 7}}')
	_clean()


func test_legacy_stats_migration_same_numbers() -> void:
	_clean()
	var old := _played().stats
	_put(L, JSON.stringify(old.to_dict()))
	var r := SaveIO.load_meta(P, B, L)
	assert_eq(r.stats.summary(), old.summary())
	assert_eq(r.stats.to_dict(), old.to_dict())
	assert_true(FileAccess.file_exists(L), "stats.json kept")
	assert_true(FileAccess.file_exists(P), "save.json written")
	# save.json now wins over stats.json
	_put(L, "{}")
	assert_eq(SaveIO.load_meta(P, B, L).stats.best_days, 4)
	_clean()
