extends TestCase
## Every sprite listed in docs/ART_PIPELINE.md must exist in assets/sprites/, be a valid
## transparent PNG and have the documented size (so later sessions can't silently break the set).

const DOC := "../docs/ART_PIPELINE.md"
const DIR := "res://assets/sprites/"


func _rows() -> Array:
	var out: Array = []
	var f := FileAccess.open(ProjectSettings.globalize_path("res://") + DOC, FileAccess.READ)
	if f == null:
		return out
	var re := RegEx.new()
	re.compile("^\\| `([a-z0-9_/]+)` \\| (\\d+)x(\\d+) \\| (\\d+),(\\d+) \\|")
	while not f.eof_reached():
		var m := re.search(f.get_line())
		if m != null:
			out.append([m.get_string(1), int(m.get_string(2)), int(m.get_string(3)), int(m.get_string(4)), int(m.get_string(5))])
	return out


func test_documented_sprites_exist_with_documented_size() -> void:
	var rows := _rows()
	assert_true(rows.size() >= 30, "ART_PIPELINE.md should list the sprite set (found %d)" % rows.size())
	for r: Array in rows:
		var path := ProjectSettings.globalize_path(DIR + String(r[0]) + ".png")
		var img := Image.load_from_file(path)
		if img == null or img.is_empty():
			failures.append("%s.png missing or not a valid PNG" % r[0])
			continue
		assert_eq(Vector2i(img.get_width(), img.get_height()), Vector2i(r[1], r[2]), "size of %s" % r[0])
		assert_true(img.detect_alpha() != Image.ALPHA_NONE, "%s.png needs an alpha channel" % r[0])
		assert_eq(img.get_pixel(0, 0).a, 0.0, "%s.png top-left pixel should be transparent" % r[0])
		assert_true(int(r[3]) < int(r[1]) and int(r[4]) < int(r[2]), "anchor inside canvas for %s" % r[0])
