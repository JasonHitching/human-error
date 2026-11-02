class_name Sprites
extends RefCounted
## Optional PNG art from res://assets/sprites/<name>.png. Missing file = null = draw in code.
## (Named tex(), not get(): Object already has get().)

const DIR := "res://assets/sprites/"

static var _cache: Dictionary = {}  # name -> Texture2D or null
static var disabled: bool = false  # test hook: every sprite reads as missing (fallback drawing)


static func tex(sprite_name: String) -> Texture2D:
	if disabled:
		return null
	if _cache.has(sprite_name):
		return _cache[sprite_name]
	var t: Texture2D = null
	var path := DIR + sprite_name + ".png"
	if ResourceLoader.exists(path):
		t = load(path) as Texture2D
	_cache[sprite_name] = t
	return t


## Test hook: put a texture in the cache (null clears the entry to "missing").
static func inject(sprite_name: String, t: Texture2D) -> void:
	_cache[sprite_name] = t


static func clear_cache() -> void:
	_cache.clear()


## First existing sprite of the names, or null.
static func first(names: Array[String]) -> Texture2D:
	for n in names:
		var t := tex(n)
		if t != null:
			return t
	return null


## Draw t inside r, keeping aspect, centred. Returns false (drawing nothing) if t is null.
static func draw_fit(ci: CanvasItem, t: Texture2D, r: Rect2, mod: Color = Color.WHITE) -> bool:
	if t == null:
		return false
	var ts := t.get_size()
	if ts.x <= 0.0 or ts.y <= 0.0:
		return false
	var k := minf(r.size.x / ts.x, r.size.y / ts.y)
	var s := ts * k
	ci.draw_texture_rect(t, Rect2(r.position + (r.size - s) * 0.5, s), false, mod)
	return true


## Draw sprite `sprite_name` fitted into r. Returns true if it was drawn.
static func draw_named(ci: CanvasItem, sprite_name: String, r: Rect2) -> bool:
	return draw_fit(ci, tex(sprite_name), r)
