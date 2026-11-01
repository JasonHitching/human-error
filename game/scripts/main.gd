extends Control
## Drives a Career: Foreman banner -> shift -> review/training -> next day ... -> fired.

const BEST_PATH := "user://best.json"
const HUD_TOP := 110.0
const SWIPE_MIN := 80.0
const COLOUR_NAME := "blue"  # matches QaDeskView.COL_BODY
const HINT := "Swipe right: ship good ones. Swipe left: reject defects.\nBots call for help. Go down to fix, come back up to inspect."

enum Phase { BANNER, PLAYING, REVIEW, FIRED }

var _config: SimConfig
var _career: Career
var _factory: Factory
var _view: FactoryView
var _desk: QaDeskView
var _screens: ScreenSwitch
var _swipe_from := Vector2(-1, -1)
var _hud: Hud
var _phase: Phase = Phase.BANNER
var _acc: float = 0.0
var _best_days: int = 0
var _holding: bool = false
var _decoy_tip_shown: bool = false
var _flash_left: float = 0.0
var _offers: Array[Dictionary] = []
var _ship_btn: Button
var _reject_btn: Button
var _scan_btn: Button
var _sfx: Sfx
var _mute_btn: Button
var _muted: bool = false
var _haptics_btn: Button
var _feel := Feel.new()
var _stats: RunStats
var _front_since: float = 0.0
var _last_qn: int = 0
var _was_crew_busy: bool = false
var _last_flash_id: String = ""


func _ready() -> void:
	_config = SimConfig.load_default()
	if not _config.is_valid():
		push_error("config invalid: %s" % str(_config.errors))
		return
	_load_save()
	_stats = RunStats.load_from()
	_sfx = Sfx.new()
	add_child(_sfx)
	_sfx.set_muted(_muted)
	_screens = ScreenSwitch.new()
	_screens.hud_top = HUD_TOP
	add_child(_screens)
	_screens.refused.connect(_flash)
	_view = FactoryView.new()
	_screens.add_view(_screens.floor_page, _view)
	_desk = QaDeskView.new()
	_desk.feel = _feel
	_screens.add_view(_screens.office_page, _desk)
	_hud = Hud.new()
	add_child(_hud)
	_hud.start_pressed.connect(_begin_shift)
	_hud.offer_pressed.connect(_pick_offer)
	_hud.continue_pressed.connect(_next_day)
	_hud.restart_pressed.connect(func() -> void: _new_career(int(Time.get_ticks_usec())))
	_hud.stats_pressed.connect(func() -> void: _hud.show_stats(_stats.summary()))
	_hud.replay_pressed.connect(func() -> void: _new_career(_career.seed))
	_ship_btn = _inspect_button("Ship", true)
	_reject_btn = _inspect_button("Reject", false)
	_scan_btn = Button.new()
	_scan_btn.text = "Scan (S)"
	_scan_btn.add_theme_font_size_override("font_size", 28)
	_scan_btn.pressed.connect(_scan)
	_screens.office_page.add_child(_scan_btn)
	_mute_btn = Button.new()
	_mute_btn.add_theme_font_size_override("font_size", 28)
	_mute_btn.pressed.connect(_toggle_mute)
	add_child(_mute_btn)
	_haptics_btn = Button.new()
	_haptics_btn.add_theme_font_size_override("font_size", 22)
	_haptics_btn.pressed.connect(_toggle_haptics)
	add_child(_haptics_btn)
	_refresh_mute()
	resized.connect(_fit)
	_new_career(int(Time.get_ticks_usec()))


func _new_career(seed_value: int) -> void:
	_decoy_tip_shown = false
	_career = Career.new(_config, seed_value)
	_stats.career_started(int(Time.get_unix_time_from_system()))
	_show_day()


func _show_day() -> void:
	_factory = _career.start_day()
	_screens.factory = _factory
	var board := StatusBoard.new(_factory.machines, _config.monitor_amber_heat)
	_screens.wall.setup(board)
	_screens.wall.radio = _factory.radio_enabled
	_view.setup(_factory, _config)
	_view.board = board
	_feel.reset()
	_front_since = _feel.clock
	_desk.setup(_factory)
	_desk.hint = HINT if _career.day == 1 else ""
	_desk.caption = _spec_caption()
	_desk.spec_new = _factory.spec_change != ""
	_acc = 0.0
	_holding = false
	_phase = Phase.BANNER
	_hud.set_flash("")
	_hud.show_banner(_career.day, _career.foreman_line("start"), _factory.target, _career.twist(), _factory.spec_change, _career.arrival_line())
	_fit()


func _spec_caption() -> String:
	var lines: Array[String] = []
	if _career.day == 1:
		lines.append("6 bolts · label on top · %s body" % COLOUR_NAME)
	for k: String in _factory.spec_extra:
		lines.append("REJECT: " + QaSpec.nice(k))
	for k: String in _factory.spec_allowed:
		lines.append("OK: " + QaSpec.nice(k))
	if _factory.subtle_share > 0.0:
		lines.append("Hairline faults: Scan")
	return " · ".join(lines)


func _toggle_mute() -> void:
	_muted = _sfx.toggle_mute()
	_refresh_mute()
	_save_best()


func _toggle_haptics() -> void:
	Haptics.enabled = not Haptics.enabled
	_refresh_mute()
	_save_best()


func _refresh_mute() -> void:
	var icon := Sprites.tex("icon_mute" if _muted else "icon_sound")
	_mute_btn.icon = icon
	_mute_btn.text = "Muted" if _muted else "Sound"
	_mute_btn.expand_icon = false
	_haptics_btn.text = "Haptics on" if Haptics.enabled else "Haptics off"


func _begin_shift() -> void:
	_sfx.play("transition")
	_phase = Phase.PLAYING
	_screens.active = true
	_hud.hide_overlays()


func _inspect_button(text: String, ship: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 28)
	var icon := Sprites.tex("icon_ship" if ship else "icon_reject")
	if icon != null:
		b.icon = icon
		b.expand_icon = true
	b.pressed.connect(func() -> void: _inspect(ship))
	_screens.office_page.add_child(b)
	return b


func _scan() -> void:
	if _phase != Phase.PLAYING or _factory == null or not _factory.worker_at_desk():
		return
	if _factory.scan() == Factory.InspectResult.SCANNING:
		_desk.hint = ""
		_sfx.play("thunk")
		var q := _factory.qa_queue()
		if not q.is_empty() and bool((q[0] as Dictionary).get("subtle", false)) and _factory.item_bad(q[0]):
			_desk.flash("Scan: hairline fault found", Color(0.6, 0.9, 1.0), 1.4)


func _inspect(ship: bool) -> void:
	if _phase != Phase.PLAYING or _factory == null:
		return
	if not _factory.worker_at_desk():
		return  # on the floor or in transit: the desk isn't here
	var q := _factory.qa_queue()
	var front: Dictionary = q[0] if not q.is_empty() else {}
	var res := _factory.inspect(ship)
	if res in [Factory.InspectResult.SHIPPED, Factory.InspectResult.COMPLAINT, Factory.InspectResult.CAUGHT, Factory.InspectResult.WASTED]:
		_desk.hint = ""
		_desk.play_inspect(front, ship)
		var bad := _factory.item_bad(front)
		var correct := ship != bad
		var quick := _feel.clock - _front_since < Feel.QUICK_SECONDS
		var perfect := correct and bad and (bool(front.get("subtle", false)) or quick)
		var steps := _feel.pitch_steps()
		_sfx.play("thunk")
		for snd in _feel.on_call(ship, correct, perfect, res == Factory.InspectResult.COMPLAINT):
			if snd == "ship" or snd == "reject":
				_sfx.play(snd, steps)
			elif snd != "complaint":
				_sfx.play(snd)
		_front_since = _feel.clock
		Haptics.pulse(30)
	match res:
		Factory.InspectResult.NOT_AT_DESK:
			_desk.flash("BRB - busy at a machine", Color(0.8, 0.8, 0.85))
		Factory.InspectResult.COMPLAINT:
			Haptics.pulse(80)
			_desk.flash("COMPLAINT!", Color(1.0, 0.25, 0.2), 1.6)
			var li := _factory.last_inspected()
			var what := String(li["defect"]) if String(li["defect"]) != "" else String(li["decoy"])
			_desk.flash("Missed: " + what.replace("_", " ").to_upper(), Color(1.0, 0.5, 0.3), 2.0)
			_desk.flash(_career.foreman_line_at("complaint", _factory.complaints), Color(1.0, 0.7, 0.6), 2.0)
		Factory.InspectResult.WASTED:
			var decoy := String(_factory.last_inspected()["decoy"])
			var why := "no defect" if decoy == "" else "just a " + ("sticker" if decoy.begins_with("sticker") else decoy)
			if String(_factory.last_inspected()["defect"]) != "":
				why = String(_factory.last_inspected()["defect"]).replace("_", " ") + " is allowed now"
			_desk.flash("That was fine - " + why, Color(1.0, 0.75, 0.3), 2.0)
		Factory.InspectResult.CAUGHT:
			_desk.flash("Caught it!", Color(0.4, 1.0, 0.5))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		match (event as InputEventKey).keycode:
			KEY_LEFT: _inspect(false)
			KEY_RIGHT: _inspect(true)
			KEY_S: _scan()
			KEY_DOWN: _screens.go_floor()
			KEY_UP: _screens.go_office()


func _fit() -> void:
	if _screens == null:
		return
	_screens.layout()
	var strip := _screens.desk_rect()
	if _mute_btn != null:
		_mute_btn.size = Vector2(120, 80)
		_mute_btn.position = Vector2(size.x - _mute_btn.size.x - 8.0, size.y - 168.0)
		_haptics_btn.size = Vector2(150, 80)
		_haptics_btn.position = _mute_btn.position - Vector2(_haptics_btn.size.x + 8.0, 0.0)
	if _ship_btn != null:
		var w := (size.x - 60.0) / 3.0
		var y := strip.end.y - 104.0
		for b: Button in [_reject_btn, _scan_btn, _ship_btn]:
			b.size = Vector2(w, 84)
		_reject_btn.position = Vector2(20.0, y)
		_scan_btn.position = Vector2(30.0 + w, y)
		_ship_btn.position = Vector2(40.0 + 2.0 * w, y)
	if _view != null:
		_view.area = _screens.floor_rect()
	if _desk != null:
		_desk.rect = strip


func _process(delta: float) -> void:
	if _factory == null:
		return
	_feel.update(delta)
	var qn := _factory.qa_queue().size()
	if _last_qn == 0 and qn > 0:
		_front_since = _feel.clock
	_last_qn = qn
	var dt := 1.0 / _config.tick_rate
	if _phase == Phase.PLAYING:
		_acc += delta
		while _acc >= dt and not _factory.is_over():
			_factory.step()
			_view.push_events(_factory.events)
			for e in _factory.events:
				if e.get("type") == "mistake":
					_sfx.play("boing")
					break
			_acc -= dt
		if _factory.is_over():
			_end_shift()
	if _view != null and _screens != null and _view.area != _screens.floor_rect():
		_fit()  # never draw the floor from a stale rect
	_desk.visible = _phase == Phase.PLAYING
	if _phase == Phase.PLAYING and _career.day == 1 and not _decoy_tip_shown:
		var q := _factory.qa_queue()
		if not q.is_empty() and String(q[0].get("decoy", "")) != "":
			_decoy_tip_shown = true
			_desk.flash("Scuffs and stickers are fine.", Color(0.6, 0.9, 1.0), 3.0)
	_ship_btn.visible = _phase == Phase.PLAYING
	_reject_btn.visible = _phase == Phase.PLAYING
	_scan_btn.visible = _phase == Phase.PLAYING
	_view.alpha = clampf(_acc / dt, 0.0, 1.0) if _phase == Phase.PLAYING else 0.0
	_screens.wall.poll()
	_sfx_events()
	_screens.sync(_view.alpha)
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_hud.set_flash("")
	_hud.update(_factory, _career, _config.tick_rate, roundi(_config.shift_seconds * _config.tick_rate), _best_days)


func _sfx_events() -> void:
	var w := _screens.wall
	if w.flash_left > 0.0 and w.flash_id != _last_flash_id and _feel.allow_alert():
		_sfx.play("alarm")
	_last_flash_id = w.flash_id if w.flash_left > 0.0 else ""
	if _was_crew_busy and not _factory.crew_busy and _phase == Phase.PLAYING:
		_sfx.play("kachunk")
		Haptics.pulse(40)
	_was_crew_busy = _factory.crew_busy


func _end_shift() -> void:
	_sfx.play("transition")
	_release()
	_screens.active = false
	_view.alpha = 0.0
	var res := _career.end_day(_factory)
	var now := int(Time.get_unix_time_from_system())
	_stats.shift_ended(now, int(res["complaints"]))
	if res["fired"]:
		_stats.career_finished(now, _career.day)
		_phase = Phase.FIRED
		var days := _career.day
		var new_best := days > _best_days
		if new_best:
			_best_days = days
			_save_best()
		var bd := "\n".join(RunEnd.breakdown(res, _config.complaint_penalty))
		var praise := _career.foreman_line("new_best") if new_best else ""
		_hud.show_fired(days, _career.foreman_line("fired"), bd, RunEnd.teaser(days, _best_days, new_best, praise))
		return
	_phase = Phase.REVIEW
	_offers = _career.offers() if int(res["points"]) > 0 else ([] as Array[Dictionary])
	var extra := "\n".join(RunEnd.breakdown(res, _config.complaint_penalty)) if not res["hit"] else "Streak: %d days on target" % RunEnd.hit_streak(_career.history)
	extra += "\n" + RunEnd.progress_line(res, _config.bonus_threshold)
	_hud.show_review(res, _career.foreman_line("hit" if res["hit"] else ("probation" if res["probation"] else "miss")), _offers, extra)


func _pick_offer(index: int) -> void:
	if index >= 0 and index < _offers.size():
		_career.apply(_offers[index])
	_next_day()


func _next_day() -> void:
	_career.next_day()
	_show_day()


func _gui_input(event: InputEvent) -> void:
	if _phase != Phase.PLAYING or _factory == null:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		var loc := _factory.worker_location()
		if mb.pressed:
			if loc == Worker.Location.FLOOR:
				_swipe_from = mb.position  # swipe up anywhere on the floor: back to the desk
				_tap(mb.position)
			elif loc == Worker.Location.OFFICE and _desk.rect.has_point(mb.position):
				_swipe_from = mb.position
		else:
			_release()
			if _swipe_from.x >= 0.0:
				var d := mb.position - _swipe_from
				_swipe_from = Vector2(-1, -1)
				if loc == Worker.Location.FLOOR and -d.y >= SWIPE_MIN and -d.y > absf(d.x):
					_screens.go_office()
				elif loc == Worker.Location.OFFICE and absf(d.x) >= SWIPE_MIN:
					_inspect(d.x > 0.0)
	elif event is InputEventMouseMotion and _holding:
		var m := _view.machine_at((event as InputEventMouseMotion).position)
		if m == null or m.id != _factory.crew_target:
			_release()


func _release() -> void:
	if _holding:
		_holding = false
		_factory.release_action()


func _tap(p: Vector2) -> void:
	var m := _view.machine_at(p)
	if m == null or _factory.worker_location() != Worker.Location.FLOOR:
		return
	_apply_tap(m.id)


func _apply_tap(id: String) -> void:
	var m := _factory.get_machine(id)
	var res := _factory.request_action(m.id)
	match res:
		Factory.ActionResult.CREW_BUSY:
			_flash("Crew busy")
		Factory.ActionResult.NOT_ON_FLOOR:
			pass
		Factory.ActionResult.NOTHING_TO_DO:
			if m.state == Machine.State.STARVED:
				_flash("Not broken - look upstream")
			elif m.state == Machine.State.BLOCKED:
				_flash("Not broken - look downstream")
		_:
			_holding = true


func _flash(text: String) -> void:
	_hud.set_flash(text)
	_flash_left = 1.5


func _load_save() -> void:
	if not FileAccess.file_exists(BEST_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BEST_PATH))
	if parsed is Dictionary:
		_best_days = int((parsed as Dictionary).get("best_days", 0))
		_muted = bool((parsed as Dictionary).get("muted", false))
		Haptics.enabled = bool((parsed as Dictionary).get("haptics", true))


func _save_best() -> void:
	var f := FileAccess.open(BEST_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"best_days": _best_days, "muted": _muted, "haptics": Haptics.enabled}))
