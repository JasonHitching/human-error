extends Control
## Drives a Career: Foreman banner -> shift -> review/training -> next day ... -> fired.

const BEST_PATH := "user://best.json"
const HUD_TOP := 110.0
const FACTORY_FRAC := 0.62  # factory view: top 62% (below the HUD)
const STRIP_FRAC := 0.67  # desk strip: bottom 33%
const SWIPE_MIN := 80.0
const HINT := "Swipe → ship good ones. Swipe ← reject defects. Bots will interrupt you."

enum Phase { BANNER, PLAYING, REVIEW, FIRED }

var _config: SimConfig
var _career: Career
var _factory: Factory
var _view: FactoryView
var _desk: QaDeskView
var _swipe_from := Vector2(-1, -1)
var _hud: Hud
var _phase: Phase = Phase.BANNER
var _acc: float = 0.0
var _best_days: int = 0
var _holding: bool = false
var _flash_left: float = 0.0
var _offers: Array[Dictionary] = []
var _ship_btn: Button  # temporary inspect buttons (real desk comes in M2-02)
var _reject_btn: Button


func _ready() -> void:
	_config = SimConfig.load_default()
	if not _config.is_valid():
		push_error("config invalid: %s" % str(_config.errors))
		return
	_best_days = _load_best()
	_view = FactoryView.new()
	add_child(_view)
	_desk = QaDeskView.new()
	add_child(_desk)
	_hud = Hud.new()
	add_child(_hud)
	_hud.start_pressed.connect(_begin_shift)
	_hud.offer_pressed.connect(_pick_offer)
	_hud.continue_pressed.connect(_next_day)
	_hud.restart_pressed.connect(func() -> void: _new_career(int(Time.get_ticks_usec())))
	_hud.replay_pressed.connect(func() -> void: _new_career(_career.seed))
	_ship_btn = _inspect_button("✔ Ship", true)
	_reject_btn = _inspect_button("✖ Reject", false)
	resized.connect(_fit)
	_new_career(int(Time.get_ticks_usec()))


func _new_career(seed_value: int) -> void:
	_career = Career.new(_config, seed_value)
	_show_day()


func _show_day() -> void:
	_factory = _career.start_day()
	_view.setup(_factory, _config)
	_desk.setup(_factory)
	_desk.hint = HINT if _career.day == 1 else ""
	_acc = 0.0
	_holding = false
	_phase = Phase.BANNER
	_hud.set_flash("")
	_hud.show_banner(_career.day, _career.foreman_line("start"), _career.day_target())
	_fit()


func _begin_shift() -> void:
	_phase = Phase.PLAYING
	_hud.hide_overlays()


func _inspect_button(text: String, ship: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 28)
	b.pressed.connect(func() -> void: _inspect(ship))
	add_child(b)
	return b


func _inspect(ship: bool) -> void:
	if _phase != Phase.PLAYING or _factory == null:
		return
	var q := _factory.qa_queue()
	var front: Dictionary = q[0] if not q.is_empty() else {}
	var res := _factory.inspect(ship)
	if res in [Factory.InspectResult.SHIPPED, Factory.InspectResult.COMPLAINT, Factory.InspectResult.CAUGHT, Factory.InspectResult.WASTED]:
		_desk.hint = ""
		_desk.play_inspect(front, ship)
	match res:
		Factory.InspectResult.NOT_AT_DESK:
			_desk.flash("BRB — busy at a machine", Color(0.8, 0.8, 0.85))
		Factory.InspectResult.COMPLAINT:
			_desk.flash("COMPLAINT!", Color(1.0, 0.25, 0.2), 1.6)
			_desk.flash(_career.foreman_line_at("complaint", _factory.complaints), Color(1.0, 0.7, 0.6), 2.0)
		Factory.InspectResult.WASTED:
			_desk.flash("Wasted", Color(1.0, 0.75, 0.3))
		Factory.InspectResult.CAUGHT:
			_desk.flash("Caught it!", Color(0.4, 1.0, 0.5))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		match (event as InputEventKey).keycode:
			KEY_LEFT: _inspect(false)
			KEY_RIGHT: _inspect(true)


func _fit() -> void:
	var strip := Rect2(0, size.y * STRIP_FRAC, size.x, size.y * (1.0 - STRIP_FRAC))
	if _ship_btn != null:
		var w := size.x * 0.45
		var y := strip.end.y - 104.0
		_reject_btn.size = Vector2(w, 84)
		_ship_btn.size = Vector2(w, 84)
		_reject_btn.position = Vector2(size.x * 0.03, y)
		_ship_btn.position = Vector2(size.x * 0.52, y)
	if _view != null:
		_view.area = Rect2(0, HUD_TOP, size.x, maxf(100.0, size.y * FACTORY_FRAC - HUD_TOP))
		_view.desk_anchor = Vector2(0, strip.position.y + 30.0)
	if _desk != null:
		_desk.rect = strip


func _process(delta: float) -> void:
	if _factory == null:
		return
	var dt := 1.0 / _config.tick_rate
	if _phase == Phase.PLAYING:
		_acc += delta
		while _acc >= dt and not _factory.is_over():
			_factory.step()
			_view.push_events(_factory.events)
			_acc -= dt
		if _factory.is_over():
			_end_shift()
	_desk.visible = _phase == Phase.PLAYING
	_ship_btn.visible = _phase == Phase.PLAYING
	_reject_btn.visible = _phase == Phase.PLAYING
	_view.alpha = clampf(_acc / dt, 0.0, 1.0) if _phase == Phase.PLAYING else 0.0
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_hud.set_flash("")
	_hud.update(_factory, _career, _config.tick_rate, roundi(_config.shift_seconds * _config.tick_rate), _best_days)


func _end_shift() -> void:
	_release()
	_view.alpha = 0.0
	var res := _career.end_day(_factory)
	if res["fired"]:
		_phase = Phase.FIRED
		var days := _career.day
		var new_best := days > _best_days
		if new_best:
			_best_days = days
			_save_best()
		_hud.show_fired(days, _best_days, new_best, _career.foreman_line("fired"))
		return
	_phase = Phase.REVIEW
	_offers = _career.offers() if int(res["points"]) > 0 else ([] as Array[Dictionary])
	_hud.show_review(res, _career.foreman_line("hit" if res["hit"] else "miss"), _offers)


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
		if mb.pressed:
			if _desk.rect.has_point(mb.position):
				_swipe_from = mb.position
			else:
				_tap(mb.position)
		else:
			_release()
			if _swipe_from.x >= 0.0:
				var dx := mb.position.x - _swipe_from.x
				_swipe_from = Vector2(-1, -1)
				if absf(dx) >= SWIPE_MIN:
					_inspect(dx > 0.0)
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
	if m == null:
		return
	var res := _factory.request_action(m.id)
	match res:
		Factory.ActionResult.CREW_BUSY:
			_flash("Crew busy")
		Factory.ActionResult.NOTHING_TO_DO:
			if m.state == Machine.State.STARVED:
				_flash("Not broken — look upstream")
			elif m.state == Machine.State.BLOCKED:
				_flash("Not broken — look downstream")
		_:
			_holding = true


func _flash(text: String) -> void:
	_hud.set_flash(text)
	_flash_left = 1.5


func _load_best() -> int:
	if not FileAccess.file_exists(BEST_PATH):
		return 0
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BEST_PATH))
	return int((parsed as Dictionary).get("best_days", 0)) if parsed is Dictionary else 0


func _save_best() -> void:
	var f := FileAccess.open(BEST_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"best_days": _best_days}))
