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


func _check_desk() -> void:
	var screen := Rect2(Vector2.ZERO, _main.size)
	var desk: QaDeskView = _main._desk
	if not screen.encloses(desk.rect):
		_fails.append("desk strip %s not inside screen %s" % [desk.rect, screen])
	for b: Button in [_main._reject_btn, _main._ship_btn]:
		if not b.is_visible_in_tree() or not screen.encloses(b.get_global_rect()):
			_fails.append("button '%s' not on-screen: %s" % [b.text, b.get_global_rect()])
		if b.size.x < 120.0 or b.size.y < 80.0:
			_fails.append("button '%s' too small: %s" % [b.text, b.size])
	var spec := desk.spec_rect()
	if not screen.encloses(spec):
		_fails.append("spec card off-screen: %s" % spec)
	for r: Rect2 in [desk.pad_rect(), _main._reject_btn.get_global_rect(), _main._ship_btn.get_global_rect()]:
		if spec.intersects(r):
			_fails.append("spec card %s overlaps %s" % [spec, r])
	if desk.caption == "":
		_fails.append("day 1 spec caption missing")
	var f: Factory = _main._factory
	f._qa_items.append({"defect": "", "decoy": "", "bot": ""})
	f._qa.input_count += 1
	if f.qa_queue().size() != 1:
		_fails.append("forced queue item missing")
	_main._inspect(false)  # rejecting a good product -> wasted
	if not f.qa_queue().is_empty() or f.wasted != 1:
		_fails.append("inspect did not update queue (queue %d, wasted %d)" % [f.qa_queue().size(), f.wasted])
	if desk.hint != "":
		_fails.append("first-time hint not dismissed after inspect")
	f.crew_busy = true
	if not desk.brb_visible():
		_fails.append("BRB not shown while crew busy")
	f.crew_busy = false
	if desk.brb_visible():
		_fails.append("BRB shown while worker at desk")


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
		4:
			if _main._desk.hint == "":
				_fails.append("day 1 hint not shown")
			_check_desk()
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
