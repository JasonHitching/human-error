extends SceneTree

## Captures engine/script errors (e.g. a runtime error inside a _draw() call) so the check can fail on them.
class ErrCatcher extends Logger:
	var errors: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, _error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		errors.append("%s:%d %s" % [file.get_file(), line, rationale if rationale != "" else code])

var _catcher := ErrCatcher.new()
## Headless UI smoke check for the career flow: banner, review, training pick,
## next day, and fired overlays are full-screen with on-screen buttons. Exits 0/1.
## godot --headless --path game -s res://tools/ui_check.gd

var _main: Node
var _frames := 0
var _fails: Array[String] = []


func _initialize() -> void:
	OS.add_logger(_catcher)
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
	for b: Button in [_main._reject_btn, _main._ship_btn, _main._scan_btn, _main._flip_btn, _main._lamp_btn]:
		if not b.is_visible_in_tree() or not screen.encloses(b.get_global_rect()):
			_fails.append("button '%s' not on-screen: %s" % [b.text, b.get_global_rect()])
		if b.size.x < 120.0 or b.size.y < 80.0:
			_fails.append("button '%s' too small: %s" % [b.text, b.size])
	if not Rect2(desk.rect).encloses(desk.shelf_rect()):
		_fails.append("shelf not inside desk area: %s" % desk.shelf_rect())
	var spec := desk.spec_rect()
	if not screen.encloses(spec):
		_fails.append("spec card off-screen: %s" % spec)
	for r: Rect2 in [desk.pad_rect(), _main._reject_btn.get_global_rect(), _main._ship_btn.get_global_rect(), _main._scan_btn.get_global_rect(), _main._flip_btn.get_global_rect(), _main._lamp_btn.get_global_rect()]:
		if spec.intersects(r):
			_fails.append("spec card %s overlaps %s" % [spec, r])
	if desk.caption == "":
		_fails.append("day 1 spec caption missing")
	var f: Factory = _main._factory
	_check_spec_and_scan(desk, f)
	f._qa_items.append({"defect": "", "decoy": "", "bot": ""})
	f._qa.input_count += 1
	if f.qa_queue().size() != 1:
		_fails.append("forced queue item missing")
	_main._inspect(false)  # rejecting a good product -> wasted
	if not f.qa_queue().is_empty() or f.wasted != 1:
		_fails.append("inspect did not update queue (queue %d, wasted %d)" % [f.qa_queue().size(), f.wasted])
	if desk.hint != "":
		_fails.append("first-time hint not dismissed after inspect")
	f.worker.place(Worker.Location.FLOOR)  # crew jobs happen on the floor
	f.crew_busy = true
	if not desk.brb_visible():
		_fails.append("BRB not shown while crew busy")
	f.crew_busy = false
	if not desk.brb_visible():
		_fails.append("BRB not shown while worker on the floor")
	f.go_to_office()
	if not desk.brb_visible():
		_fails.append("BRB not shown while worker walking")
	f.worker.place(Worker.Location.OFFICE)
	if desk.brb_visible():
		_fails.append("BRB shown while worker at desk")


## Spec card shows a changed rule; a subtle product is drawn only after the scan.
func _check_spec_and_scan(desk: QaDeskView, f: Factory) -> void:
	f.apply_spec({"extra": ["scuff"], "allowed": ["dent"], "change": "New spec: scuff is now a defect.", "subtle_share": 0.3})
	var cap: String = _main._spec_caption()
	if not cap.contains("REJECT: scuff") or not cap.contains("OK: dent"):
		_fails.append("spec caption lacks the changed rules: '%s'" % cap)
	var item := {"defect": "crack", "decoy": "", "bot": "", "subtle": true}
	if QaDeskView.shown_defect(item) != "":
		_fails.append("subtle defect drawn before the scan")
	f.worker.place(Worker.Location.OFFICE)
	f._qa_items.append(item)
	f._qa.input_count += 1
	_main._scan()
	if QaDeskView.shown_defect(item) != "crack" or not f.inspect_busy():
		_fails.append("scan did not reveal the subtle defect / take time")
	f._inspect_left = 0
	f.inspect(false)
	f.apply_spec({})
	f.caught = 0
	f._inspect_left = 0


func _check_button(b: Button, screen: Rect2) -> void:
	if not b.is_visible_in_tree() or not screen.encloses(b.get_global_rect()):
		_fails.append("button '%s' not on-screen: %s" % [b.text, b.get_global_rect()])
	if b.size.x < 120.0 or b.size.y < 80.0:
		_fails.append("button '%s' too small: %s" % [b.text, b.size])


## Press a nav button; location must change exactly after transition_seconds of ticks.
func _press_and_travel(b: Button, dest: Worker.Location) -> void:
	var f: Factory = _main._factory
	var trip := roundi(_main._config.transition_seconds * _main._config.tick_rate)
	b.pressed.emit()
	if f.worker_location() != Worker.Location.TRANSIT or f.transit_target() != dest:
		_fails.append("'%s' did not start transit" % b.text)
	for i in trip - 1:
		f.step()
	_main._screens.sync(0.5)
	var off: float = _main._screens.offset
	if f.worker_location() != Worker.Location.TRANSIT or off <= 0.0 or off >= 1.0:
		_fails.append("'%s' arrived early or no slide (offset %.2f)" % [b.text, off])
	f.step()
	if f.worker_location() != dest:
		_fails.append("'%s' not arrived after %d ticks" % [b.text, trip])
	_main._screens.sync(0.0)


func _check_wall(sw: ScreenSwitch, f: Factory) -> void:
	var wall: WallMonitor = sw.wall
	var n := 0
	for m in f.machines:
		if m.type != "qa" and m.type != "warehouse":
			n += 1
	var rects := wall.light_rects()
	if rects.size() != n or n == 0:
		_fails.append("wall monitor has %d lights, expected %d" % [rects.size(), n])
		return
	for r in rects:
		if not Rect2(Vector2.ZERO, wall.size).encloses(r):
			_fails.append("monitor light %s outside monitor %s" % [r, wall.size])
	var m := f.get_machine("proc_a")
	m.state = Machine.State.JAMMED
	wall.poll()
	if wall.board.machine_light(m) != StatusBoard.Light.RED:
		_fails.append("forced jam did not turn the light RED")
	if wall.call_text == "" or wall.flash_id != "proc_a" or wall.flash_left <= 0.0:
		_fails.append("forced jam showed no call-in/flash: '%s'" % wall.call_text)
	m.state = Machine.State.IDLE
	wall.poll()
	if wall.quiet_left <= 0.0:
		_fails.append("fixing the last problem did not show the 'All quiet.' cue")
	else:
		var w := ThemeDB.fallback_font.get_string_size("All quiet.", HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		if 16.0 + w > wall.size.x or wall.size.y - 100.0 < 0.0:
			_fails.append("'All quiet.' cue does not fit inside the monitor %s" % wall.size)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = rects[0].get_center()
	wall._gui_input(ev)
	if f.worker_location() != Worker.Location.TRANSIT or f.transit_target() != Worker.Location.FLOOR:
		_fails.append("tapping a monitor light did not start a trip to the floor")
	f.worker.place(Worker.Location.OFFICE)


func _check_screens() -> void:
	var screen := Rect2(Vector2.ZERO, _main.size)
	var sw: ScreenSwitch = _main._screens
	var f: Factory = _main._factory
	sw.sync(0.0)
	for r: Rect2 in [sw.monitor_rect(), sw.desk_rect(), sw.floor_rect()]:
		if not screen.encloses(r):
			_fails.append("screen rect %s not inside viewport %s" % [r, screen])
	if sw.office_page.position != Vector2.ZERO or sw.floor_page.visible:
		_fails.append("office not shown at desk")
	_check_button(sw.factory_btn, screen)
	if sw.desk_rect().intersects(sw.monitor_rect()):
		_fails.append("desk overlaps wall monitor")
	_check_wall(sw, f)
	_press_and_travel(sw.factory_btn, Worker.Location.FLOOR)
	if sw.floor_page.position != Vector2.ZERO or sw.office_page.visible:
		_fails.append("floor not shown on the floor")
	if not screen.encloses(_main._view.area):
		_fails.append("factory view %s not inside viewport" % _main._view.area)
	_check_button(sw.back_btn, screen)
	_check_button(sw.worst_btn, screen)
	if _main._ship_btn.is_visible_in_tree():
		_fails.append("ship button visible on the floor")
	var ql: Label = sw.queue_label
	if not ql.is_visible_in_tree() or not screen.encloses(ql.get_global_rect()) or not ql.text.begins_with("Desk queue"):
		_fails.append("queue meter not visible on the floor: '%s' %s" % [ql.text, ql.get_global_rect()])
	_check_floor_chars()
	_press_and_travel(sw.back_btn, Worker.Location.OFFICE)
	if sw.office_page.position != Vector2.ZERO:
		_fails.append("office not shown after back to desk")


## Run a forced shift on the floor with jobs and misroutes; bots and worker stay inside the floor area.
func _check_floor_chars() -> void:
	var f: Factory = _main._factory
	var v: FactoryView = _main._view
	var sw: ScreenSwitch = _main._screens
	f.worker.place(Worker.Location.FLOOR)
	sw.sync(0.0)
	v.area = sw.floor_rect()
	var back := sw.back_btn.get_global_rect()
	var bad := 0
	var off_sim := 0
	var away := 0
	for i in 900:
		f.step()
		v.push_events(f.events)
		if i % 40 == 0:
			var m := f.machines[(i / 40) % f.machines.size()]
			if m.type != "qa":
				m.misrouted = true
				v.push_events([{"type": "mistake", "mistake": "misroute", "machine_id": m.id}])
				f.request_action(m.id)
		v._process(0.1)
		var pts: Array[Vector2] = []
		for m in f.machines:
			if m.bot != null:
				pts.append(v.bot_pos(m))
		pts.append(v.worker_pos())
		var sim_px := v.layout_to_px(f.worker.floor_pos_at(v.alpha))
		if v.worker_pos().distance_to(sim_px) > WorkerView.HALF + 1.0:  # only the edge clamp may move it
			off_sim += 1
		if f.worker.floor_pos.distance_to(f.worker.stairs) > 0.1:
			away += 1
		for p in pts:
			var box := Rect2(p - Vector2(22, 24), Vector2(44, 48))
			if not v.area.encloses(box) or box.intersects(back):
				bad += 1
	if bad > 0:
		_fails.append("%d character positions outside floor area or over the back button" % bad)
	if off_sim > 0:
		_fails.append("%d frames with the worker not drawn at the sim position" % off_sim)
	if away == 0:
		_fails.append("worker never walked away from the stairs")
	f.crew_busy = false
	f.worker.place(Worker.Location.FLOOR)


const SIZES: Array[Vector2i] = [Vector2i(720, 1280), Vector2i(390, 844), Vector2i(360, 800), Vector2i(430, 932), Vector2i(768, 1024)]


## Window size -> logical viewport (project stretch: canvas_items, aspect expand, base 720x1280).
func _logical(win: Vector2i) -> Vector2:
	var s := minf(win.x / 720.0, win.y / 1280.0)
	return Vector2(win) / s


func _within(inner: Rect2, outer: Rect2, tag: String, tol: float = 0.5) -> bool:
	if outer.grow(tol).encloses(inner):
		return true
	_fails.append("%s %s outside floor %s" % [tag, inner, outer])
	return false


## Tier 2 (#88): the bigger floor, every machine, the wall monitor and the worst-first button fit at every size.
func _check_tier_two() -> void:
	_main._meta.unlock_after(1)
	_main._meta.pick_tier(2)
	_main._new_career(7)
	if _main._tier != 2 or _main._factory == null or _main._factory.machines.size() != SimConfig.load_tier(2).machines.size():
		_fails.append("tier 2 career did not build the tier 2 floor")
	else:
		_check_layouts()
		var n := 0
		for m in _main._factory.machines:
			n += 0 if m.type == "qa" or m.type == "warehouse" else 1
		if _main._screens.wall.light_rects().size() != n:
			_fails.append("tier 2 wall monitor lights != %d" % n)
	_main._meta.tier = 1
	_main._meta.pick_tier(1)
	_main._new_career(1)
	_main._hud.start_pressed.emit()


func _check_layouts() -> void:
	var f: Factory = _main._factory
	var v: FactoryView = _main._view
	var sw: ScreenSwitch = _main._screens
	var old: Vector2 = _main.size
	for win in SIZES:
		var lg := _logical(win)
		var k := minf(win.x / 720.0, win.y / 1280.0)
		_main.size = lg
		_main._fit()
		sw.sync(0.0)
		_main._process(0.0)
		var tag := "%dx%d" % [win.x, win.y]
		_main._open_home()
		_check_home(tag, false)
		_main._home.visible = false
		f.worker.place(Worker.Location.OFFICE)  # desk buttons: office page on screen
		sw.sync(0.0)
		var vp := Rect2(Vector2.ZERO, lg)
		for b: Button in [_main._ship_btn, _main._reject_btn, _main._scan_btn, _main._flip_btn, _main._lamp_btn, sw.factory_btn]:
			if not vp.encloses(b.get_global_rect()):
				_fails.append("[%s] button '%s' off-screen %s" % [tag, b.text, b.get_global_rect()])
			if b.size.x < 120.0 or b.size.y < 80.0:
				_fails.append("[%s] button '%s' too small %s" % [tag, b.text, b.size])
		f.worker.place(Worker.Location.FLOOR)
		sw.sync(0.0)
		var a: Rect2 = v.area
		var screen := Rect2(Vector2.ZERO, lg)
		if not screen.encloses(a) or a.size.x < 100.0 or a.size.y < 400.0:
			_fails.append("[%s] floor area %s bad in viewport %s" % [tag, a, lg])
		var rects: Array[Rect2] = []
		var mh := v.machine_h()
		for m in f.machines:
			var r: Rect2 = v.hatch_rect(m) if m.type == "qa" else v.machine_rect(m)
			_within(r.grow(6.0) if m.type != "qa" else r, a, "[%s] %s" % [tag, m.id])
			for o in rects:
				if o.intersects(r):
					_fails.append("[%s] machine %s overlaps another" % [tag, m.id])
			rects.append(r)
			if m.type == "qa":
				continue
			var hb := v.heat_rect(m)
			_within(hb, a, "[%s] %s heat bar" % [tag, m.id])
			if hb.get_center().distance_to(r.get_center()) > mh:
				_fails.append("[%s] %s heat bar detached" % [tag, m.id])
			if m.bot != null:
				var bp := v.bot_pos(m)
				_within(Rect2(bp - Vector2(22, 24), Vector2(44, 48)), a, "[%s] %s robot" % [tag, m.id])
				var bd := v.badge_rect(m)
				_within(bd, a, "[%s] %s badge" % [tag, m.id])
				if bd.get_center().distance_to(r.get_center()) > mh * 1.5 or absf(bd.get_center().y - r.get_center().y) > mh * 1.5:
					_fails.append("[%s] %s badge detached from machine" % [tag, m.id])
		var sr := v.scrap_rect()
		_within(sr, a, "[%s] scrap bin" % tag)
		for o in rects:
			if o.intersects(sr):
				_fails.append("[%s] scrap bin overlaps a machine" % tag)
		var wp := v.worker_pos()
		_within(Rect2(wp - Vector2(22, 22), Vector2(44, 44)), a, "[%s] worker" % tag)
		for b: Button in [sw.back_btn, sw.worst_btn, _main._mute_btn]:
			if not vp.encloses(b.get_global_rect()):
				_fails.append("[%s] button '%s' off-screen %s" % [tag, b.text, b.get_global_rect()])
			if b.size.x < 80.0 or b.size.y < 80.0 or ((b == sw.back_btn or b == sw.worst_btn) and b.size.x < 120.0):
				_fails.append("[%s] button '%s' too small %s (scale %.2f)" % [tag, b.text, b.size, k])
		if a.intersects(sw.back_btn.get_global_rect()) or a.intersects(sw.worst_btn.get_global_rect()):
			_fails.append("[%s] floor overlaps back/worst button" % tag)
		if sw.worst_btn.get_global_rect().intersects(sw.back_btn.get_global_rect()):
			_fails.append("[%s] worst-first overlaps back button" % tag)
		for m in v.factory.machines:
			if m.type != "qa" and m.type != "warehouse" and not v.machine_rect(m).encloses(v.queue_badge_rect(m)):
				_fails.append("[%s] %s queue badge outside machine rect" % [tag, m.id])
		_check_jitter(tag)
	_main.size = old
	_main._fit()
	f.worker.place(Worker.Location.OFFICE)


## No events for 60 frames: machines and badges stay put (<1 px), robots only bob (<=3 px).
func _check_jitter(tag: String) -> void:
	var f: Factory = _main._factory
	var v: FactoryView = _main._view
	var prev := {}
	for i in 60:
		v._process(1.0 / 60.0)
		for m in f.machines:
			var cur: Array = [v.machine_rect(m).position, Vector2.ZERO, Vector2.ZERO]
			if m.bot != null:
				cur[1] = v.badge_rect(m).position
				cur[2] = v.bot_pos(m)
			if prev.has(m.id):
				var p: Array = prev[m.id]
				if (cur[0] as Vector2).distance_to(p[0]) >= 1.0 or (cur[1] as Vector2).distance_to(p[1]) >= 1.0:
					_fails.append("[%s] %s jitters frame to frame" % [tag, m.id])
				if (cur[2] as Vector2).distance_to(p[2]) > 3.0:
					_fails.append("[%s] %s robot moves >3 px per frame" % [tag, m.id])
			prev[m.id] = cur


## UI text sticks to basic ASCII plus the middle dot (default web font lacks other symbols).
func _check_glyphs() -> void:
	var bad := {}
	for n in _main.find_children("*", "Control", true, false):
		var t := ""
		if n is Label:
			t = (n as Label).text
		elif n is Button:
			t = (n as Button).text
		for i in t.length():
			var c := t.unicode_at(i)
			if (c > 126 or (c < 32 and c != 10)) and c != 0xB7:
				bad[String.chr(c)] = "U+%04X in '%s'" % [c, t.substr(0, 24)]
	for k in bad:
		_fails.append("non-ASCII glyph: " + bad[k])


func _check_sprites_sfx() -> void:
	if Sprites.tex("no_such_sprite") != null:
		_fails.append("missing sprite should be null")
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color.RED)
	var t := ImageTexture.create_from_image(img)
	Sprites.inject("test_sprite", t)
	if Sprites.tex("test_sprite") != t:
		_fails.append("injected sprite not returned by loader")
	Sprites.inject("bot_sparky", t)  # draw sites must accept a sprite without erroring
	Sprites.inject("machine_processor", t)
	Sprites.inject("product", t)
	await_redraw()  # cleared next frame, after the draw sites ran with sprites
	var sfx: Sfx = _main._sfx
	for k in Sfx.KINDS:
		if sfx.render(k).is_empty():
			_fails.append("sfx '%s' renders nothing" % k)
	sfx.start()
	sfx.play("ship")  # must not error headless
	var mb: Button = _main._mute_btn
	if not mb.is_visible_in_tree() or mb.size.x < 80.0 or mb.size.y < 80.0:
		_fails.append("mute button missing/too small: %s" % mb.size)
	if not Rect2(Vector2.ZERO, _main.size).encloses(mb.get_global_rect()):
		_fails.append("mute button off-screen: %s" % mb.get_global_rect())
	var hb: Button = _main._haptics_btn
	if not hb.is_visible_in_tree() or hb.size.x < 120.0 or hb.size.y < 80.0 or mb.size.x < 120.0:
		_fails.append("sound/haptics toggles missing/too small: %s %s" % [mb.size, hb.size])
	if not Rect2(Vector2.ZERO, _main.size).encloses(hb.get_global_rect()) or hb.get_global_rect().intersects(mb.get_global_rect()):
		_fails.append("haptics button off-screen or overlapping: %s" % hb.get_global_rect())
	hb.pressed.emit()
	hb.pressed.emit()
	var feel: Feel = _main._feel  # forced streak then a forced complaint: draw every effect
	for i in 21:
		feel.on_call(i % 2 == 0, true, true, false)
	feel.on_call(true, false, false, true)
	_main._desk.queue_redraw()
	await_redraw()
	var before: bool = sfx.muted
	mb.pressed.emit()
	if sfx.muted == before:
		_fails.append("mute button did not toggle")
	mb.pressed.emit()


func await_redraw() -> void:
	_main._view.queue_redraw()
	_main._desk.queue_redraw()


func _end_shift(shipped: int) -> void:
	_main._factory.shipped = shipped
	_main._factory.tick = int(_main._config.shift_seconds * _main._config.tick_rate)


func _check_rookie(hud: Hud) -> void:
	var rook: Machine = null
	for m in _main._factory.machines:
		if m.bot != null and m.bot.rookie:
			rook = m
	if rook == null:
		_fails.append("rookie not on the floor on a rookie day")
		return
	if not hud.banner.is_visible_in_tree() or not hud._banner_label.text.contains("NEW: ") or not hud._banner_label.text.contains(rook.bot.name):
		_fails.append("foreman banner did not announce the rookie")
	_check_overlay("rookie banner", hud.banner, true)
	var wall: WallMonitor = _main._screens.wall
	rook.state = Machine.State.JAMMED
	wall.poll()
	if not wall.call_text.begins_with(rook.bot.name):
		_fails.append("rookie call-in not on the monitor: '%s'" % wall.call_text)
	rook.state = Machine.State.IDLE
	wall.poll()
	# the review lists a learned lesson
	hud.show_review({"shipped": 30, "target": 24, "hit": true, "caught": 0, "complaints": 0, "wasted": 0, "strikes": 0, "points": 1, "probation": false, "lessons": [{"bot": "Pip", "mistake": "wrong_recipe"}, {"bot": "Bolt", "mistake": "overclock"}, {"bot": "Nudge", "mistake": "misroute"}], "rookie": {"name": "Pip", "replaced": "Clank"}}, "ok", [{"text": "Train Pip: jam -40%"}, {"text": "Quick eye: inspect -20%"}, {"text": "Bigger desk: +2 queue"}] as Array[Dictionary], "Streak: 1 days on target\nTraining point banked: pick below")
	if not hud._review_label.text.contains("Pip learned") or not hud._review_label.text.contains("Rookie: "):
		_fails.append("review did not list the lesson and rookie")
	_check_overlay("lesson review", hud.review, true)


func _check_home(tag: String, placed: bool = true) -> void:
	var h: Home = _main._home
	if not h.visible:
		_fails.append("[%s] Home not shown" % tag)
		return
	var vp := Rect2(Vector2.ZERO, _main.size)
	var need: Vector2 = h.start_btn.get_parent().get_combined_minimum_size()
	if need.y > vp.size.y or need.x > vp.size.x:
		_fails.append("[%s] Home content %s does not fit %s" % [tag, need, vp.size])
	for b: Button in [h.start_btn, h.daily_btn, h.stats_btn]:
		if placed and not vp.encloses(b.get_global_rect()):
			_fails.append("[%s] Home button '%s' off-screen %s" % [tag, b.text, b.get_global_rect()])
		if b.size.x < 120.0 or b.size.y < 80.0:
			_fails.append("[%s] Home button '%s' too small %s" % [tag, b.text, b.size])


func _check_night() -> void:
	var n: NightReport = _main._night
	n.show_report({"commendations": 7, "mess_level": 2, "lines": ["Line one of the Foreman report, which is long enough to wrap around the screen a bit.", "Line two.", "Line three.", "Line four."]})
	_check_overlay("night report", n, true)
	var vp := Rect2(Vector2.ZERO, _main.size)
	if n.collect_btn.size.x < 120.0 or n.collect_btn.size.y < 80.0 or not vp.encloses(n.collect_btn.get_global_rect()):
		_fails.append("night Collect button bad: %s" % n.collect_btn.get_global_rect())
	n.collect_btn.pressed.emit()
	if n.visible:
		_fails.append("Collect did not close the night report")
	_main._meta.commendations["balance"] = 0  # undo the bank so later checks see a clean slate
	_main._meta.pending_night = {}


func _check_stats(hud: Hud) -> void:
	var sb: Button = hud.stats_btn
	if sb.size.x < 120 or sb.size.y < 80:
		_fails.append("stats button too small: %s" % sb.size)
	hud.stats_pressed.emit()
	_check_overlay("stats", hud.stats_overlay, true)
	var lab: Label = hud.stats_overlay.find_children("*", "Label", true, false)[0]
	if not Rect2(Vector2.ZERO, _main.size).encloses(lab.get_global_rect()):
		_fails.append("stats text off-screen %s" % lab.get_global_rect())
	if lab.text.is_empty() or lab.text.contains("%"):
		_fails.append("stats text bad: " + lab.text)
	hud.hide_stats()
	if hud.stats_overlay.visible:
		_fails.append("stats close did not hide overlay")


func _process(_delta: float) -> bool:
	_frames += 1
	var hud: Control = _main._hud
	match _frames:
		3:
			_check_glyphs()
			if hud.size != _main.size:
				_fails.append("HUD size %s != screen %s" % [hud.size, _main.size])
			_check_overlay("banner", hud.banner, true)
			_check_home("start")
			_check_night()
			_main._home_start()
			if _main._home.visible:
				_fails.append("Home Start did not hide Home")
			hud.start_pressed.emit()
		4:
			if _main._desk.hint == "":
				_fails.append("day 1 hint not shown")
			_check_desk()
			_check_screens()
			_check_sprites_sfx()
			_check_layouts()
			_check_tier_two()
		5:
			Sprites.clear_cache()
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
			var rb: Button = hud._retry_btn
			var need := Vector2(200, 100) if _main.size == Vector2(720, 1280) else Vector2(120, 80)
			if rb.size.x < need.x or rb.size.y < need.y:
				_fails.append("retry button too small: %s" % rb.size)
			_check_stats(hud)
			hud.restart_pressed.emit()
			_check_home("after run-end")
			_main._home.visible = false
			_check_glyphs()
			_main._career.twists = Twists.new(_main._career.seed, 3)  # fresh cache,
			_main._career.twists.twist_chance = 1.0  # forced twist
			_main._career.day = 3  # first twist day
			_main._show_day()
		22:
			if _main._factory.twist_id == "":
				_fails.append("day 3 has no twist")
			elif not hud.banner.is_visible_in_tree() or not (_main._hud._banner_label.text.contains("TWIST")):
				_fails.append("twist banner not shown on a twist day")
			_check_overlay("twist banner", hud.banner, true)
			hud.start_pressed.emit()
		24:
			if not hud._twist.is_visible_in_tree() or hud._twist.text == "":
				_fails.append("twist HUD label not visible on a twist day")
			hud.start_pressed.emit()
			_main._career.day = 4  # first rookie day
			_main._show_day()
		26:
			_check_rookie(hud)
			hud.start_pressed.emit()
		28:
			for e in _catcher.errors.slice(0, 5):
				_fails.append("engine/script error while drawing: " + e)
			for f in _fails:
				print("FAIL ui_check: " + f)
			print("ui_check: %s" % ("ok" if _fails.is_empty() else "%d failed" % _fails.size()))
			quit(1 if not _fails.is_empty() else 0)
			return true
	return false
