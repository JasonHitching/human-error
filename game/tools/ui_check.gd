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
		for p in pts:
			var box := Rect2(p - Vector2(22, 24), Vector2(44, 48))
			if not v.area.encloses(box) or box.intersects(back):
				bad += 1
	if bad > 0:
		_fails.append("%d character positions outside floor area or over the back button" % bad)
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
		f.worker.place(Worker.Location.OFFICE)  # desk buttons: office page on screen
		sw.sync(0.0)
		var vp := Rect2(Vector2.ZERO, lg)
		for b: Button in [_main._ship_btn, _main._reject_btn, sw.factory_btn]:
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
		for b: Button in [sw.back_btn, _main._mute_btn]:
			if not vp.encloses(b.get_global_rect()):
				_fails.append("[%s] button '%s' off-screen %s" % [tag, b.text, b.get_global_rect()])
			if b.size.x < 80.0 or b.size.y < 80.0 or (b == sw.back_btn and b.size.x < 120.0):
				_fails.append("[%s] button '%s' too small %s (scale %.2f)" % [tag, b.text, b.size, k])
		if a.intersects(sw.back_btn.get_global_rect()):
			_fails.append("[%s] floor overlaps back button" % tag)
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


func _process(_delta: float) -> bool:
	_frames += 1
	var hud: Control = _main._hud
	match _frames:
		3:
			_check_glyphs()
			if hud.size != _main.size:
				_fails.append("HUD size %s != screen %s" % [hud.size, _main.size])
			_check_overlay("banner", hud.banner, true)
			hud.start_pressed.emit()
		4:
			if _main._desk.hint == "":
				_fails.append("day 1 hint not shown")
			_check_desk()
			_check_screens()
			_check_sprites_sfx()
			_check_layouts()
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
			_check_glyphs()
			for f in _fails:
				print("FAIL ui_check: " + f)
			print("ui_check: %s" % ("ok" if _fails.is_empty() else "%d failed" % _fails.size()))
			quit(1 if not _fails.is_empty() else 0)
			return true
	return false
