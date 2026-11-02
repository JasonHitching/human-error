extends Control
## Drives a Career: Foreman banner -> shift -> review/training -> next day ... -> fired.

const BEST_PATH := "user://best.json"
const SWIPE_MIN := 80.0
const COLOUR_NAME := "blue"  # matches QaDeskView.COL_BODY
const HINT := "Swipe right: ship good ones. Swipe left: reject defects.\nBots call for help. Go down to fix, come back up to inspect."

enum Phase { BANNER, PLAYING, REVIEW, FIRED }

var _config: SimConfig
var _tier: int = 1
var _career: Career
var _factory: Factory
var _view: FactoryView
var _desk: QaDeskView
var _screens: ScreenSwitch
var _swipe_from := Vector2(-1, -1)
var _hud: Hud
var _info: MachineInfo
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
var _flip_btn: Button
var _lamp_btn: Button
var _sfx: Sfx
var _settings: SettingsOverlay
var _muted: bool = false
var _feel := Feel.new()
var _meta: Meta
var _home: Home
var _daily_date: String = ""  # "" = normal career; else the date of the daily being played
var _night: NightReport
var _tutorial: Tutorial
var _stats: RunStats
var _front_since: float = 0.0
var _last_qn: int = 0
var _was_crew_busy: bool = false
var _last_flash_id: String = ""


func _ready() -> void:
	_load_save()
	_meta = SaveIO.load_meta()
	_meta.note_best(1, _best_days)  # best.json predates tiers: it was tier 1
	_set_tier(_meta.picked_tier)
	if not _config.is_valid():
		push_error("config invalid: %s" % str(_config.errors))
		return
	_stats = _meta.stats
	_sfx = Sfx.new()
	add_child(_sfx)
	_sfx.set_muted(_muted)
	_screens = ScreenSwitch.new()
	_screens.hud_top = TopBar.height() + 36.0
	add_child(_screens)
	_screens.refused.connect(_flash)
	_view = FactoryView.new()
	_screens.add_view(_screens.floor_page, _view)
	_info = MachineInfo.new()
	_screens.floor_page.add_child(_info)
	_screens.wall.light_tapped.connect(func(id: String) -> void: _view.focus_machine(id))  # alert tap
	_screens.worst_btn.pressed.connect(_focus_worst)
	_desk = QaDeskView.new()
	_desk.feel = _feel
	_screens.add_view(_screens.office_page, _desk)
	_hud = Hud.new()
	add_child(_hud)
	_hud.start_pressed.connect(_begin_shift)
	_hud.offer_pressed.connect(_pick_offer)
	_hud.continue_pressed.connect(_next_day)
	_hud.restart_pressed.connect(_open_home)
	_hud.again_pressed.connect(_home_start)
	_hud.stats_pressed.connect(func() -> void: _hud.show_stats(_stats.summary()))
	_hud.replay_pressed.connect(func() -> void: _new_career(_career.seed, _daily_date))
	_ship_btn = _inspect_button("Ship", true)
	_reject_btn = _inspect_button("Reject", false)
	_scan_btn = _desk_button("Scan", "secondary", 30, _scan)
	UiTheme.add_icon(_scan_btn, func(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void: UiTheme.draw_magnifier(ci, c, r, col), 30)
	_flip_btn = _desk_button("Flip", "secondary", 24, _flip)
	_lamp_btn = _desk_button("X-ray", "secondary", 24, _lamp)
	_hud.debug_overlay = _config.debug_overlay
	_settings = SettingsOverlay.create()
	add_child(_settings)
	_settings.sound_toggled.connect(_toggle_mute)
	_settings.haptics_toggled.connect(_toggle_haptics)
	_settings.effects_toggled.connect(_toggle_effects)
	_settings.home_pressed.connect(func() -> void:
		_settings.close()
		_open_home())
	_hud.settings_pressed.connect(func() -> void: _settings.open(not _muted, Haptics.enabled))
	_home = Home.create()
	add_child(_home)
	_home.start_pressed.connect(_home_start)
	_home.tier_picked.connect(func(t: int) -> void:
		_meta.pick_tier(t)
		SaveIO.write_meta(_meta)
		_home_refresh())
	_home.perk_bought.connect(func(id: String) -> void:
		if _meta.buy(id):
			SaveIO.write_meta(_meta)
		_home_refresh())
	_home.daily_pressed.connect(_daily_start)
	_home.settings_pressed.connect(func() -> void: _settings.open(not _muted, Haptics.enabled))
	_home.stats_pressed.connect(func() -> void: _hud.show_stats(_stats.summary()))
	_hud.stats_overlay.z_index = 20  # stats opens above Home
	_night = NightReport.create()
	add_child(_night)
	_night.collected.connect(_night_collected)
	_tutorial = Tutorial.new()
	add_child(_tutorial)
	_tutorial.finished.connect(_tutorial_finished)
	_home.tutorial_pressed.connect(_replay_tutorial)
	resized.connect(_fit)
	_new_career(int(Time.get_ticks_usec()))
	_open_home()
	_night_return()


## Night shift: on start/resume show the Foreman's report if we were away long enough.
func _night_return() -> void:
	var rep := _meta.night_check(int(Time.get_unix_time_from_system()), _career.roster, int(_meta.last_seen_unix))
	SaveIO.write_meta(_meta)
	if not rep.is_empty() and not bool(rep.get("collected", false)):
		_night.show_report(rep)


func _tutorial_finished(_skipped: bool) -> void:
	_meta.tutorial_done = true
	SaveIO.write_meta(_meta)


## Home "Replay tutorial": forget it was done and start a fresh career so day 1 teaches again.
func _replay_tutorial() -> void:
	_meta.tutorial_done = false
	SaveIO.write_meta(_meta)
	_home.visible = false
	_new_career(int(Time.get_ticks_usec()))


func _tutorial_tick() -> void:
	if _tutorial == null or not _tutorial.active:
		return
	if _career.day != 1 or _daily_date != "":
		_tutorial.skip()  # past day 1 (or a daily): done for good
		return
	var strip := _screens.desk_rect()
	_tutorial.targets = {
		"floor": _screens.floor_rect(), "desk": strip,
		"review": Rect2(Vector2(8, 8), size - Vector2(16, 16)),
	}
	if _phase == Phase.PLAYING or _phase == Phase.REVIEW:
		_tutorial.observe(Tutorial.snapshot(_factory, _phase == Phase.REVIEW and not _offers.is_empty()))


func _night_collected() -> void:
	_meta.collect_night()
	SaveIO.write_meta(_meta)
	_home_refresh()


func _notification(what: int) -> void:
	if _meta == null:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_meta.last_seen_unix = NightShift.next_last_seen(int(Time.get_unix_time_from_system()), _meta.last_seen_unix)
		SaveIO.write_meta(_meta)
	elif (what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN) and _night != null and not _night.visible:
		_night_return()


func _today() -> String:
	return Time.get_date_string_from_system()  # local date


func _home_refresh() -> void:
	_home.setup(_meta, _today(), SimConfig.load_tier(_meta.picked_tier).target_base)


func _open_home() -> void:
	_home_refresh()
	_home.visible = true


## Start career: at app start a career is already set up behind Home; after a run-end begin a fresh one.
func _home_start() -> void:
	_home.visible = false
	if _phase == Phase.FIRED or _meta.picked_tier != _tier or _daily_date != "":
		_new_career(int(Time.get_ticks_usec()))


func _daily_start() -> void:
	_home.visible = false
	var d := _today()
	_new_career(Daily.seed_for(d), d)


func _set_tier(t: int) -> void:
	_tier = clampi(t, 1, _meta.tier)
	_config = SimConfig.load_tier(_tier)
	_best_days = _meta.best_for(_tier)


func _new_career(seed_value: int, daily_date: String = "") -> void:
	_daily_date = daily_date
	_set_tier(Daily.TIER if daily_date != "" else _meta.picked_tier)
	_decoy_tip_shown = false
	_career = Career.new(_config, seed_value, [] if daily_date != "" else _meta.owned_perks)
	_stats.career_started(int(Time.get_unix_time_from_system()))
	SaveIO.write_meta(_meta)
	_show_day()
	if _tutorial != null:
		if _meta.tutorial_done or daily_date != "":
			_tutorial.stop()
		else:
			_tutorial.start()


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
	_hud.show_banner(_career.day, _career.foreman_line("start"), _factory.target, _career.twist(), _factory.spec_change, _career.banner_news())
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
		lines.append("Hairline faults: Scan or Lamp")
	if _factory.back_share > 0.0:
		lines.append("Check the back: Flip")
	return " · ".join(lines)


func _toggle_mute() -> void:
	_muted = _sfx.toggle_mute()
	_refresh_mute()
	_save_best()


func _toggle_haptics() -> void:
	Haptics.enabled = not Haptics.enabled
	_refresh_mute()
	_save_best()


func _toggle_effects() -> void:
	FloorFx.enabled = not FloorFx.enabled
	_refresh_mute()
	_save_best()


func _refresh_mute() -> void:
	_settings.refresh(not _muted, Haptics.enabled)


func _begin_shift() -> void:
	_sfx.play("transition")
	_phase = Phase.PLAYING
	_screens.active = true
	_hud.hide_overlays()


func _desk_button(text: String, kind: String, font_size: int, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	UiTheme.style_button(b, kind, font_size)
	b.pressed.connect(cb)
	_screens.office_page.add_child(b)
	return b


func _inspect_button(text: String, ship: bool) -> Button:
	var b := _desk_button(text, "primary" if ship else "danger", 30, func() -> void: _inspect(ship))
	if ship:
		UiTheme.add_icon(b, func(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void: UiTheme.draw_tick(ci, c, r, col, 5.0), 30)
	else:
		UiTheme.add_icon(b, func(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void: UiTheme.draw_x(ci, c, r, col, 5.0), 30)
	return b


func _flip() -> void:
	if _phase != Phase.PLAYING or _factory == null or not _factory.worker_at_desk():
		return
	if _factory.flip() == Factory.InspectResult.SCANNING:
		_desk.hint = ""
		_sfx.play("thunk")
		var q := _factory.qa_queue()
		if not q.is_empty() and bool((q[0] as Dictionary).get("back", false)) and _factory.item_bad(q[0]):
			_desk.flash("Flip: fault on the back", Color(0.6, 0.9, 1.0), 1.4)


func _lamp() -> void:
	if _phase != Phase.PLAYING or _factory == null or not _factory.worker_at_desk():
		return
	if _factory.lamp() == Factory.InspectResult.SCANNING:
		_desk.hint = ""
		_sfx.play("thunk")
		var q := _factory.qa_queue()
		if not q.is_empty() and bool((q[0] as Dictionary).get("subtle", false)) and _factory.item_bad(q[0]):
			_desk.flash("X-ray: hairline fault found", Color(0.6, 0.9, 1.0), 1.4)


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
			KEY_F: _flip()
			KEY_L: _lamp()
			KEY_DOWN: _screens.go_floor()
			KEY_UP: _screens.go_office()


func _fit() -> void:
	if _screens == null:
		return
	_screens.layout()
	var strip := _screens.desk_rect()
	if _desk != null:
		_desk.rect = strip
	if _ship_btn != null:
		var mr := _desk.main_row()
		var sr := _desk.small_row()
		var row: Array[Button] = [_reject_btn, _scan_btn, _ship_btn, _flip_btn, _lamp_btn]
		var rects: Array[Rect2] = [mr[0], mr[1], mr[2], sr[0], sr[1]]
		for i in row.size():
			row[i].size = rects[i].size
			row[i].position = rects[i].position
	if _view != null:
		_view.area = _screens.floor_rect()
		_info.place(_view.area)


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
	_flip_btn.visible = _phase == Phase.PLAYING
	_lamp_btn.visible = _phase == Phase.PLAYING
	_view.alpha = clampf(_acc / dt, 0.0, 1.0) if _phase == Phase.PLAYING else 0.0
	_info.show_machine(_factory.get_machine(_view.selected) if _view.selected != "" else null)
	if _phase == Phase.PLAYING and _factory.worker_location() == Worker.Location.FLOOR:
		_view.keys(delta)
	_screens.wall.poll()
	_sfx_events()
	_screens.sync(_view.alpha)
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_hud.set_flash("")
	_hud.update(_factory, _career, _config.tick_rate, roundi(_config.shift_seconds * _config.tick_rate), _best_days)
	_tutorial_tick()


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
	_meta.last_seen_unix = NightShift.next_last_seen(now, _meta.last_seen_unix)
	var awarded := {"total": 0, "lines": [] as Array[String]}
	if res["fired"] or res["automated"]:
		_stats.career_finished(now, _career.day)
		if res["automated"]:
			_meta.automations += 1
			_meta.unlock_after(_tier)
		awarded = _meta.award(_career.summary())
	SaveIO.write_meta(_meta)
	if res["fired"] or res["automated"]:
		_phase = Phase.FIRED
		var days := _career.day
		var new_best := _note_best(days)
		var bd := "\n".join(RunEnd.breakdown(res, _config.complaint_penalty))
		var praise := _career.foreman_line("new_best") if new_best else ""
		var auto := bool(res["automated"])
		_hud.show_fired(days, _career.foreman_line("automated" if auto else "fired"), bd, RunEnd.teaser(days, _best_days, new_best, praise), RunEnd.awards_text(awarded), "AUTOMATED (you win)" if auto else "FIRED", _fired_info(res, awarded))
		return
	_phase = Phase.REVIEW
	_offers = _career.offers() if int(res["points"]) > 0 else ([] as Array[Dictionary])
	var extra := "\n".join(RunEnd.breakdown(res, _config.complaint_penalty)) if not res["hit"] else "Streak: %d days on target" % RunEnd.hit_streak(_career.history)
	extra += "\n" + RunEnd.progress_line(res, _config.bonus_threshold) + "\n" + RunEnd.training_lines(_career.roster)
	_hud.show_review(res, _career.foreman_line("hit" if res["hit"] else ("probation" if res["probation"] else "miss")), _offers, extra)


func _fired_info(res: Dictionary, awarded: Dictionary) -> Dictionary:
	var colors := {}
	for b: Bot in _career.roster:
		colors[b.name] = b.color
	var info := {"best": _best_days, "colors": colors, "award_total": int(awarded.get("total", 0))}
	if not res.is_empty():
		info["score"] = int(res["shipped"])
		info["target"] = int(res["target"])
	return info


func _pick_offer(index: int) -> void:
	if index >= 0 and index < _offers.size():
		_career.apply(_offers[index])
	if _career.automated:
		_end_automated()
		return
	_next_day()


## A training pick trained the last bot: the career ends as a win.
## Records a finished career's days (daily: per-date best + first-daily bonus; else per-tier best). True on a new best.
func _note_best(days: int) -> bool:
	if _daily_date != "":
		var r := _meta.note_daily(_daily_date, days)
		SaveIO.write_meta(_meta)
		return bool(r["new_best"])
	var nb := days > _best_days
	if nb:
		_best_days = days
		_meta.note_best(_tier, days)
		SaveIO.write_meta(_meta)
		_save_best()
	return nb


func _end_automated() -> void:
	var now := int(Time.get_unix_time_from_system())
	_stats.career_finished(now, _career.day)
	_meta.automations += 1
	_meta.unlock_after(_tier)
	var awarded := _meta.award(_career.summary())
	SaveIO.write_meta(_meta)
	_phase = Phase.FIRED
	var days := _career.day
	var new_best := _note_best(days)
	_hud.show_fired(days, _career.foreman_line("automated"), "", RunEnd.teaser(days, _best_days, new_best, ""), RunEnd.awards_text(awarded), "AUTOMATED (you win)", _fired_info({}, awarded))


func _next_day() -> void:
	_career.next_day()
	if _meta.pending_night.get("collected", false) == true:
		_career.night_mess = _meta.take_mess(_career.day)
		SaveIO.write_meta(_meta)
	_show_day()


func _gui_input(event: InputEvent) -> void:
	if _phase != Phase.PLAYING or _factory == null:
		return
	if event is InputEventMouseButton and ((event as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_UP or (event as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_DOWN):
		_view.zoom_by(1.1 if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.1, (event as InputEventMouseButton).position)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
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
	elif event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask != 0 and _factory.worker_location() == Worker.Location.FLOOR:
		_view.pan_by((event as InputEventMouseMotion).relative)  # drag to pan the floor
	elif event is InputEventPanGesture and _factory.worker_location() == Worker.Location.FLOOR:
		_view.pan_by(-(event as InputEventPanGesture).delta * 12.0)
	elif event is InputEventMagnifyGesture and _factory.worker_location() == Worker.Location.FLOOR:
		_view.zoom_by((event as InputEventMagnifyGesture).factor, (event as InputEventMagnifyGesture).position)  # pinch
	elif event is InputEventMouseMotion and _holding:
		var m := _view.machine_at((event as InputEventMouseMotion).position)
		if m == null or m.id != _factory.crew_target:
			_release()


func _release() -> void:
	if _holding:
		_holding = false
		_factory.release_action()


## "Fix worst first": the sim queued (or started) the worst machine; bring it into view.
func _focus_worst() -> void:
	if _factory == null:
		return
	var id: String = _factory.crew_queue.back() if not _factory.crew_queue.is_empty() else (_factory.crew_target if _factory.crew_busy else "")
	if id != "":
		_view.focus_machine(id)


func _tap(p: Vector2) -> void:
	var m := _view.machine_at(p)
	if m == null:
		_view.select("")
		return
	_view.focus_machine(m.id)
	if _factory.worker_location() != Worker.Location.FLOOR:
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
	FloorFx.enabled = SimConfig.load_tier(1).ambient_effects
	if not FileAccess.file_exists(BEST_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BEST_PATH))
	if parsed is Dictionary:
		_best_days = int((parsed as Dictionary).get("best_days", 0))
		_muted = bool((parsed as Dictionary).get("muted", false))
		Haptics.enabled = bool((parsed as Dictionary).get("haptics", true))
		FloorFx.enabled = bool((parsed as Dictionary).get("effects", FloorFx.enabled))


func _save_best() -> void:
	var f := FileAccess.open(BEST_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"best_days": _meta.best_for(1) if _meta != null else _best_days, "muted": _muted, "haptics": Haptics.enabled, "effects": FloorFx.enabled}))
