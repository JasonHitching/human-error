class_name Sfx
extends Node
## Code-generated blips through an AudioStreamGenerator. Tuning: balance.json "sfx".
## Starts on the first user input (browsers need a gesture). Safe with no audio device.

const MIX_RATE := 22050.0
const KINDS := ["ship", "reject", "complaint", "alarm", "fix", "transition", "thunk", "deflate", "fanfare", "kachunk", "boing"]

var muted: bool = false
var params: Dictionary = {}
var _player: AudioStreamPlayer
var _pb: AudioStreamGeneratorPlayback
var _started: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance.json"))
	if parsed is Dictionary and (parsed as Dictionary).get("sfx") is Dictionary:
		params = (parsed as Dictionary)["sfx"]
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.5
	_player = AudioStreamPlayer.new()
	_player.stream = gen
	add_child(_player)


func _exit_tree() -> void:
	_pb = null
	if _player != null:
		_player.stop()


func _input(event: InputEvent) -> void:
	if _started:
		return
	if (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) or (event is InputEventKey and (event as InputEventKey).pressed) or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed):
		start()


## Begin the generator. Call from a user gesture. Returns whether a playback exists.
func start() -> bool:
	_started = true
	if _player == null:
		return false
	if not _player.playing:
		_player.play()
	_pb = _player.get_stream_playback() as AudioStreamGeneratorPlayback
	return _pb != null


func set_muted(m: bool) -> void:
	muted = m
	if muted and _pb != null and _player != null:
		_player.stop()  # drop everything queued, immediately
		_player.play()
		_pb = _player.get_stream_playback() as AudioStreamGeneratorPlayback


func toggle_mute() -> bool:
	set_muted(not muted)
	return muted


## Samples for a sound kind (mono floats). Pure; used by play() and by tests.
func render(kind: String, steps: int = 0) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var p: Dictionary = params.get(kind, {})
	if p.is_empty():
		return out
	var n := int(float(p.get("length", 0.1)) * MIX_RATE)
	var mult := pow(2.0, float(clampi(steps, 0, 7)) / 12.0)
	var f0 := float(p.get("pitch", 400)) * mult
	var f1 := float(p.get("pitch_end", f0)) * mult
	var vol := float(p.get("volume", 1.0)) * float(params.get("volume", 0.3))
	out.resize(n)
	var phase := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / float(maxi(n - 1, 1))
		var env := minf(1.0, t * 20.0) * (1.0 - t)
		var s := 0.0
		match kind:
			"complaint":
				phase += f0 / MIX_RATE
				s = 1.0 if fposmod(phase * (1.0 + 0.3 * sin(t * 60.0)), 1.0) < 0.5 else -1.0
				s *= 0.6
			"alarm":
				phase += (f0 if t < 0.5 else f1) / MIX_RATE
				s = sin(phase * TAU) * (1.0 if fmod(t * 4.0, 1.0) < 0.85 else 0.0)
			"fix":
				var step := floorf(t * 4.0)
				phase += lerpf(f0, f1, step / 3.0) / MIX_RATE
				s = sin(phase * TAU)
			"thunk":
				phase += lerpf(f0, f1, t) / MIX_RATE
				lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.2
				s = sin(phase * TAU) + lp * 0.5 * (1.0 - t)
			"fanfare":
				var note := floorf(t * 3.0)
				phase += f0 * pow(2.0, [0, 4, 7][mini(int(note), 2)] / 12.0) / MIX_RATE
				s = 1.0 if fposmod(phase, 1.0) < 0.5 else -1.0
				s *= 0.4
			"kachunk":
				phase += (f0 if t < 0.35 else f1) / MIX_RATE
				s = sin(phase * TAU) * (1.0 if t < 0.3 or t > 0.4 else 0.0)
			"boing":
				phase += f0 * (1.0 + 0.5 * sin(t * 30.0) * (1.0 - t)) / MIX_RATE
				s = sin(phase * TAU)
			"transition":
				lp += (_rng.randf_range(-1.0, 1.0) - lp) * lerpf(0.05, 0.4, sin(t * PI))
				s = lp * 2.0
			_:
				phase += lerpf(f0, f1, t) / MIX_RATE
				s = sin(phase * TAU)
		out[i] = s * env * vol
	return out


func play(kind: String, steps: int = 0) -> void:
	if muted or not _started or _pb == null:
		return
	var samples := render(kind, steps)
	if samples.is_empty() or _pb.get_frames_available() < samples.size():
		return
	var frames := PackedVector2Array()
	frames.resize(samples.size())
	for i in samples.size():
		frames[i] = Vector2(samples[i], samples[i])
	_pb.push_buffer(frames)
