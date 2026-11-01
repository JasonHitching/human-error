extends SceneTree
## Headless UI smoke check: HUD fills the screen and the end-of-shift overlay
## is visible, full-size and centred. Exits 0/1.
## godot --headless --path game -s res://tools/ui_check.gd

var _main: Node
var _frames := 0


func _initialize() -> void:
	_main = load("res://main.tscn").instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 3:
		_main._factory.tick = int(_main._config.shift_seconds * _main._config.tick_rate)
	if _frames < 10:
		return false
	var fails: Array[String] = []
	var screen: Vector2 = _main.size
	var hud: Control = _main._hud
	var overlay: Control = hud._overlay
	if hud.size != screen:
		fails.append("HUD size %s != screen %s" % [hud.size, screen])
	if not _main._ended or not overlay.is_visible_in_tree():
		fails.append("end overlay not shown after shift end")
	if overlay.size != screen:
		fails.append("overlay size %s != screen %s" % [overlay.size, screen])
	for b: Button in overlay.find_children("*", "Button", true, false):
		var r := b.get_global_rect()
		if not Rect2(Vector2.ZERO, screen).encloses(r):
			fails.append("button '%s' off-screen at %s" % [b.text, r])
	for f in fails:
		print("FAIL ui_check: " + f)
	print("ui_check: %s" % ("ok" if fails.is_empty() else "%d failed" % fails.size()))
	quit(1 if not fails.is_empty() else 0)
	return true
