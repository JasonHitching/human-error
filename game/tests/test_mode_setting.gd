extends TestCase
## The mode setting (core is the default) saves and loads; old saves without it are core.

const P := "user://t_mode.json"
const B := "user://t_mode.bad.json"
const L := "user://t_mode_stats.json"


func _clean() -> void:
	for p: String in [P, B, L, P + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func test_default_and_old_saves_are_core() -> void:
	assert_eq(Meta.new().mode, "core")
	assert_eq(Meta.from_dict({}).mode, "core")
	assert_eq(Meta.from_dict({"version": 1, "tier": 2}).mode, "core")
	assert_eq(Meta.from_dict({"mode": "banana"}).mode, "core")
	assert_eq(Meta.from_dict({"mode": 7}).mode, "core")


func test_mode_saves_and_loads() -> void:
	_clean()
	var m := Meta.new()
	m.mode = "full"
	assert_eq(Meta.from_dict(m.to_dict()).mode, "full")
	assert_true(SaveIO.write_meta(m, P))
	assert_eq(SaveIO.load_meta(P, B, L).mode, "full")
	m.mode = "core"
	SaveIO.write_meta(m, P)
	assert_eq(SaveIO.load_meta(P, B, L).mode, "core")
	_clean()
