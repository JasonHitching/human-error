class_name FloorFx
extends RefCounted
## Floor atmosphere (view only): state glow, steam, lamp, dust, vignette, belt motion.
## No sim access, no RNG; everything is a pure function of time and a fixed particle pool.

static var enabled: bool = true  # Settings "Effects"; off = no steam/lamp/dust/vignette/belt motion

const STEAM_N := 24
const DUST_N := 12  # STEAM_N + DUST_N = 36 live max
const STEAM_LIFE := 1.8
const GLOW_W := 300.0  # logical px; flattened to the iso ellipse
const GLOW_H := 170.0
const COL_HEALTHY := Color(1.0, 0.86, 0.62, 0.30)
const COL_WARM := Color(1.0, 0.71, 0.28, 0.55)  # UiTheme.WARN
const COL_HOT := Color(1.0, 0.36, 0.36, 0.70)  # UiTheme.CRIT

static var _glow: Texture2D

var _mid: PackedInt32Array = PackedInt32Array()  # steam: machine index (-1 = free)
var _ox: PackedFloat32Array = PackedFloat32Array()
var _age: PackedFloat32Array = PackedFloat32Array()
var _timer: PackedFloat32Array = PackedFloat32Array()  # per machine seconds to next puff
var _n: int = 0  # emitted puffs, hash seed
var _vig: Array[PackedVector2Array] = []
var _vig_col := PackedColorArray([Color(0, 0, 0, 0.38), Color(0, 0, 0, 0.38), Color(0, 0, 0, 0), Color(0, 0, 0, 0)])
var _vig_area := Rect2()


static func glow_tex() -> Texture2D:
	if _glow == null:
		var g := Gradient.new()
		g.set_color(0, Color.WHITE)
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 256
		t.height = 256
		_glow = t
	return _glow


func reset(machine_count: int) -> void:
	_mid.resize(STEAM_N)
	_mid.fill(-1)
	_ox.resize(STEAM_N)
	_age.resize(STEAM_N)
	_timer.resize(machine_count)
	for i in machine_count:
		_timer[i] = 0.4 + 0.37 * float(i)
	_n = 0
	_vig_area = Rect2()


func live_count() -> int:
	var c := 0
	for i in STEAM_N:
		if _mid[i] >= 0:
			c += 1
	return c + (DUST_N if enabled else 0)


## kinds: per machine 0 fine / 1 warn / 2 crit (-1 = no steam, e.g. the QA hatch).
func update(d: float, kinds: PackedInt32Array) -> void:
	if not enabled:
		for i in STEAM_N:
			_mid[i] = -1
		return
	for i in STEAM_N:
		if _mid[i] >= 0:
			_age[i] += d
			if _age[i] >= STEAM_LIFE:
				_mid[i] = -1
	for m in mini(kinds.size(), _timer.size()):
		if kinds[m] < 0:
			continue
		_timer[m] -= d
		if _timer[m] <= 0.0:
			_timer[m] = [2.6, 1.1, 0.6][kinds[m]]
			_emit(m)


func _emit(m: int) -> void:
	for i in STEAM_N:
		if _mid[i] < 0:
			_mid[i] = m
			_age[i] = 0.0
			_ox[i] = float((_n * 37) % 41 - 20)
			_n += 1
			return


func glow_color(kind: int, t: float) -> Color:
	if kind == 2:
		var c := COL_HOT
		c.a *= 0.8 + 0.2 * sin(t * 3.0)
		return c
	return COL_WARM if kind == 1 else COL_HEALTHY


## Soft state glow on the floor under a machine (ground g, screen scale s).
func draw_glow(ci: CanvasItem, g: Vector2, s: float, kind: int, t: float) -> void:
	var w := GLOW_W * s * (1.15 if kind == 2 else 1.0)
	var h := GLOW_H * s * (1.15 if kind == 2 else 1.0)
	ci.draw_texture_rect(glow_tex(), Rect2(g - Vector2(w, h) * 0.5, Vector2(w, h)), false, glow_color(kind, t))


## Steam puffs rising from machine tops; tops[m] = screen point above machine m.
func draw_steam(ci: CanvasItem, tops: PackedVector2Array, s: float) -> void:
	if not enabled:
		return
	for i in STEAM_N:
		if _mid[i] < 0 or _mid[i] >= tops.size():
			continue
		var u := _age[i] / STEAM_LIFE
		var p := tops[_mid[i]] + Vector2(_ox[i] + 8.0 * sin(_age[i] * 2.0 + float(i)), -46.0 * u) * s
		ci.draw_circle(p, (4.0 + 7.0 * u) * s, Color(0.85, 0.87, 0.9, 0.22 * (1.0 - u)))


## Flicker factor 0.85..1 (sum of slow sines, deterministic).
static func flicker(t: float) -> float:
	return 0.925 + 0.045 * sin(t * 7.3) + 0.03 * sin(t * 17.1 + 1.3)


## Hanging lamp: cord, shade and a light pool on the floor. g = ground under the lamp.
func draw_lamp(ci: CanvasItem, g: Vector2, s: float, t: float, clip: Rect2) -> void:
	if not enabled:
		return
	var f := flicker(t)
	var top := g + Vector2(0, -210.0) * s
	var lamp := g + Vector2(0, -172.0) * s
	if not clip.has_point(top) or not clip.has_point(g):
		return
	var pw := 360.0 * s
	var ph := 200.0 * s
	ci.draw_texture_rect(glow_tex(), Rect2(g - Vector2(pw, ph) * 0.5, Vector2(pw, ph)), false, Color(1.0, 0.92, 0.7, 0.16 * f))
	ci.draw_line(top, lamp - Vector2(0, 8.0 * s), UiTheme.LINE, maxf(1.0, 2.0 * s))
	ci.draw_colored_polygon(PackedVector2Array([lamp + Vector2(-14, 0) * s, lamp + Vector2(14, 0) * s, lamp + Vector2(7, -9) * s, lamp + Vector2(-7, -9) * s]), UiTheme.TEXT_DIM)
	ci.draw_circle(lamp + Vector2(0, 3.0 * s), 5.0 * s, Color(1.0, 0.93, 0.75, f))
	ci.draw_texture_rect(glow_tex(), Rect2(lamp + Vector2(-26, -22) * s, Vector2(52, 52) * s), false, Color(1.0, 0.92, 0.7, 0.35 * f))


## Slow dust motes drifting in the lamp's light pool, clamped inside the floor area.
func draw_dust(ci: CanvasItem, pool: Vector2, s: float, t: float, clip: Rect2) -> void:
	if not enabled:
		return
	for i in DUST_N:
		var ph := float(i) * 1.7
		var p := pool + Vector2(150.0 * sin(t * 0.13 + ph * 2.1), 70.0 * sin(t * 0.17 + ph) - 25.0 * fposmod(t * 0.2 + float(i) * 0.31, 1.0)) * s
		if clip.has_point(p):
			ci.draw_circle(p, maxf(1.0, 1.6 * s), Color(1.0, 0.95, 0.8, 0.18 + 0.12 * sin(t * 0.9 + ph)))


## Soft dark edges over the floor area (polygons rebuilt only when the area changes).
func draw_vignette(ci: CanvasItem, area: Rect2) -> void:
	if not enabled:
		return
	if area != _vig_area:
		_vig_area = area
		_vig.clear()
		var k := minf(area.size.x, area.size.y) * 0.16
		var a := area.position
		var b := area.end
		_vig.append(PackedVector2Array([Vector2(a.x, a.y), Vector2(b.x, a.y), Vector2(b.x, a.y + k), Vector2(a.x, a.y + k)]))
		_vig.append(PackedVector2Array([Vector2(a.x, b.y), Vector2(b.x, b.y), Vector2(b.x, b.y - k), Vector2(a.x, b.y - k)]))
		_vig.append(PackedVector2Array([Vector2(a.x, a.y), Vector2(a.x, b.y), Vector2(a.x + k, b.y), Vector2(a.x + k, a.y)]))
		_vig.append(PackedVector2Array([Vector2(b.x, a.y), Vector2(b.x, b.y), Vector2(b.x - k, b.y), Vector2(b.x - k, a.y)]))
	for q in _vig:
		ci.draw_polygon(q, _vig_col)


## Moving stripes on a belt tile. flow phase 0..1; edges is the tile's edge-name set.
static func draw_belt_motion(ci: CanvasItem, g: Vector2, edges: Dictionary, s: float, phase: float) -> void:
	if edges.size() != 2:
		return
	var names: Array = edges.keys()
	names.sort()
	var a := _edge_pt(String(names[0]))  # entry (ne/nw first), exit second
	var b := _edge_pt(String(names[1]))
	var mid := Vector2.ZERO
	for k in 3:
		var u := fposmod(phase + float(k) / 3.0, 1.0)  # 0..1 along entry -> centre -> exit
		var p := a.lerp(mid, u * 2.0) if u < 0.5 else mid.lerp(b, u * 2.0 - 1.0)
		ci.draw_circle(g + p * s, maxf(1.5, 3.0 * s), Color(1.0, 1.0, 1.0, 0.16))


static func _edge_pt(n: String) -> Vector2:
	match n:
		"se":
			return Vector2(IsoFloor.HW, IsoFloor.HH) * 0.5
		"sw":
			return Vector2(-IsoFloor.HW, IsoFloor.HH) * 0.5
		"nw":
			return Vector2(-IsoFloor.HW, -IsoFloor.HH) * 0.5
	return Vector2(IsoFloor.HW, -IsoFloor.HH) * 0.5
