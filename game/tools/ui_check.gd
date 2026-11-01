extends SceneTree
## Headless UI smoke check for the career flow: banner, review, training pick,
## next day, and fired overlays are full-screen with on-screen buttons. Exits 0/1.
## godot --headless --path game -s res://tools/ui_check.gd

var _main: Node
var _frames := 0
var _fails: Array[String] = []


func _initialize() -> void:
	_main = load("res://main.tscn").instantiate()
	root.add_child(_main)


func _check_overlay(name: String, o: Control, need_buttons: bool) -> void:
	var screen: Vector2 = _main.size
	if not o.is_visible_in_tree():
		_fails.append("%s overlay not visible" % name)
		return
	if o.size != screen:
		_fails.append("%s overlay size %s != screen %s" % [name, o.size, screen])
	var buttons := o.find_children("*", "Button", true, false)
	if need_buttons and buttons.is_empty():
		_fails.append("%s overlay has no buttons" % name)
	for b: Button in buttons:
		if not Rect2(Vector2.ZERO, screen).encloses(b.get_global_rect()):
			_fails.append("%s button '%s' off-screen at %s" % [name, b.text, b.get_global_rect()])


func _end_shift(shipped: int) -> void:
	_main._factory.shipped = shipped
	_main._factory.tick = int(_main._config.shift_seconds * _main._config.tick_rate)


func _process(_delta: float) -> bool:
	_frames += 1
	var hud: Control = _main._hud
	match _frames:
		3:
			if hud.size != _main.size:
				_fails.append("HUD size %s != screen %s" % [hud.size, _main.size])
			_check_overlay("banner", hud.banner, true)
			hud.start_pressed.emit()
		5:
			if _main._phase != _main.Phase.PLAYING:
				_fails.append("shift did not start after banner tap")
			_end_shift(_main._factory.target * 2)  # hit with bonus -> points to spend
		8:
			_check_overlay("review", hud.review, true)
			if _main._offers.is_empty():
				_fails.append("no training offers after a hit")
			else:
				hud.offer_pressed.emit(0)
		10:
			if _main._career.day != 2 or _main._phase != _main.Phase.BANNER:
				_fails.append("picking an offer did not start day 2")
			hud.start_pressed.emit()
		12:
			_end_shift(0)  # strike 1
		14:
			_check_overlay("review (miss)", hud.review, true)
			hud.continue_pressed.emit()
		16:
			hud.start_pressed.emit()
		18:
			_end_shift(0)  # strike 2 -> fired
		21:
			_check_overlay("fired", hud.fired, true)
			for f in _fails:
				print("FAIL ui_check: " + f)
			print("ui_check: %s" % ("ok" if _fails.is_empty() else "%d failed" % _fails.size()))
			quit(1 if not _fails.is_empty() else 0)
			return true
	return false
