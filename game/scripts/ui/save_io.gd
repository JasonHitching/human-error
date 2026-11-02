class_name SaveIO
extends RefCounted
## File IO for Meta: user://save.json (atomic write), with corrupt/too-new backup and
## one-time import of the legacy user://stats.json.

const PATH := "user://save.json"
const BAD_PATH := "user://save.bad.json"
const LEGACY_PATH := "user://stats.json"


static func _g(p: String) -> String:
	return ProjectSettings.globalize_path(p)


static func _parse(p: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(p))


static func load_meta(p: String = PATH, bad: String = BAD_PATH, legacy: String = LEGACY_PATH) -> Meta:
	if FileAccess.file_exists(p):
		var parsed: Variant = _parse(p)
		if parsed is Dictionary and int((parsed as Dictionary).get("version", -1)) >= 1 \
				and int((parsed as Dictionary)["version"]) <= Meta.VERSION:
			return Meta.from_dict(parsed as Dictionary)
		DirAccess.copy_absolute(_g(p), _g(bad))  # keep the evidence; never silently overwrite
		return Meta.new()
	if FileAccess.file_exists(legacy):
		var old: Variant = _parse(legacy)
		if old is Dictionary:
			var m := Meta.from_legacy_stats(old as Dictionary)
			write_meta(m, p)
			return m
	return Meta.new()


static func write_meta(m: Meta, p: String = PATH) -> bool:
	var tmp := p + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(m.to_dict()))
	f.close()
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(_g(p))
	return DirAccess.rename_absolute(_g(tmp), _g(p)) == OK
