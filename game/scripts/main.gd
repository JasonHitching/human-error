extends Control
## Owns the Factory; fixed-timestep stepping, input, best-score persistence.

const BEST_PATH := "user://best.json"
const HUD_TOP := 110.0
const HUD_BOTTOM := 120.0

var _config: SimConfig
var _factory: Factory
var _view: FactoryView
var _hud: Hud
var _seed: int = 1
var _acc: float = 0.0
var _best: int = 0
var _ended: bool = false
var _holding: bool = false
var _flash_left: float = 0.0


func _ready() -> void:
	_config = SimConfig.load_default()
	if not _config.is_valid():
		push_error("config invalid: %s" % str(_config.errors))
		return
	_best = _load_best()
	_view = FactoryView.new()
	add_child(_view)
	_hud = Hud.new()
	add_child(_hud)
	_hud.restart_pressed.connect(func() -> void: _start(int(Time.get_ticks_usec())))
	_hud.replay_pressed.connect(func() -> void: _start(_seed))
	resized.connect(_fit)
	_start(int(Time.get_ticks_usec()))


func _start(seed_value: int) -> void:
	_seed = seed_value
	_factory = Factory.new(_config, _seed)
	_view.setup(_factory, _config)
	_acc = 0.0
	_ended = false
	_holding = false
	_hud.hide_end()
	_hud.set_flash("")
	_fit()


func _fit() -> void:
	if _view != null:
		_view.area = Rect2(0, HUD_TOP, size.x, maxf(100.0, size.y - HUD_TOP - HUD_BOTTOM))


func _process(delta: float) -> void:
	if _factory == null:
		return
	var dt := 1.0 / _config.tick_rate
	if not _ended:
		_acc += delta
		while _acc >= dt and not _factory.is_over():
			_factory.step()
			_acc -= dt
		if _factory.is_over():
			_end_shift()
	_view.alpha = 0.0 if _ended else clampf(_acc / dt, 0.0, 1.0)
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_hud.set_flash("")
	_hud.update(_factory, _config.tick_rate, roundi(_config.shift_seconds * _config.tick_rate), _best, _seed)


func _end_shift() -> void:
	_ended = true
	_view.alpha = 0.0
	var new_best := _factory.shipped > _best
	if new_best:
		_best = _factory.shipped
		_save_best()
	_hud.show_end(_factory.shipped, _factory.target, _best, new_best)


func _gui_input(event: InputEvent) -> void:
	if _ended or _factory == null:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			_tap(mb.position)
		else:
			_release()
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
	return int((parsed as Dictionary).get("best", 0)) if parsed is Dictionary else 0


func _save_best() -> void:
	var f := FileAccess.open(BEST_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"best": _best}))
