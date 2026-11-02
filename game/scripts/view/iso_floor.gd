class_name IsoFloor
extends RefCounted
## Isometric floor layout (pure data + maths, no drawing): grid cells -> logical px, belt routing.
## Axes: gx runs screen down-right (SE), gy runs down-left (SW). One cell = 128 x 74 logical px.

const HW := 64.0
const HH := 37.0
## Baked-pixel anchors (ground cell centre) per sprite family, from docs/ART_PIPELINE.md.
const ANCHORS := {"machine_": Vector2(192, 292), "desk_hatch": Vector2(192, 292), "belt_": Vector2(128, 126), "floor_tile": Vector2(128, 74), "crate_stack": Vector2(128, 170), "crate": Vector2(64, 84), "scrap_bin": Vector2(128, 170), "reject_bin": Vector2(128, 170), "fence": Vector2(128, 126), "wall_back_plain": Vector2(96, 270), "wall_back": Vector2(160, 330), "shadow_machine": Vector2(160, 60)}
## Belt top surface rise above the ground cell centre (baked px; measured: left/right corner row 65 vs anchor 126).
const BELT_RISE := 61.0
const DIRS := {"se": Vector2i(1, 0), "sw": Vector2i(0, 1), "nw": Vector2i(-1, 0), "ne": Vector2i(0, -1)}
const OPP := {"se": "nw", "nw": "se", "sw": "ne", "ne": "sw"}

var cells: Dictionary = {}  # machine id -> Vector2i
var by_cell: Dictionary = {}  # Vector2i -> machine id
var edges: Dictionary = {}  # belt cell -> {edge name: true}
var paths: Dictionary = {}  # "from>to" -> Array[Vector2i] (machine cell, belt cells, machine cell)
var props: Array = []
var grid := Vector2i(5, 5)
var scrap_cell := Vector2i(0, 0)
var stairs_cell := Vector2(-1, 1)


static func to_local(g: Vector2) -> Vector2:
	return Vector2((g.x - g.y) * HW, (g.x + g.y) * HH)


## Logical-px offset from a belt cell's ground point to the centre of its top surface (items ride here).
static func belt_top_offset() -> Vector2:
	return Vector2(0, -BELT_RISE * 0.5)


static func anchor(sprite_name: String) -> Vector2:
	for k: String in ANCHORS:
		if sprite_name.begins_with(k):
			return ANCHORS[k]
	return Vector2(128, 126)


func setup(machines: Array, links: Array, art: Dictionary) -> void:
	cells.clear()
	by_cell.clear()
	edges.clear()
	paths.clear()
	for md: Dictionary in machines:
		var c := Vector2i(int(md.get("gx", 0)), int(md.get("gy", 0)))
		cells[String(md["id"])] = c
		by_cell[c] = String(md["id"])
	var g: Array = art.get("grid", [5, 5])
	grid = Vector2i(int(g[0]), int(g[1]))
	var sc: Array = art.get("scrap_g", [grid.x - 1, 0])
	scrap_cell = Vector2i(int(sc[0]), int(sc[1]))
	var st: Array = art.get("stairs_g", [-1, 1])
	stairs_cell = Vector2(float(st[0]), float(st[1]))
	props = art.get("props", [])
	for l: Dictionary in links:
		var key := "%s>%s" % [l["from"], l["to"]]
		var a: Vector2i = cells.get(String(l["from"]), Vector2i.ZERO)
		var b: Vector2i = cells.get(String(l["to"]), Vector2i.ZERO)
		var path := route(a, b)
		paths[key] = path
		for i in range(1, path.size()):
			var d := path[i] - path[i - 1]
			var en := ""
			for k: String in DIRS:
				if DIRS[k] == d:
					en = k
			if en == "":
				continue
			if not by_cell.has(path[i - 1]):
				_edge(path[i - 1], en)
			if not by_cell.has(path[i]):
				_edge(path[i], OPP[en])


func _edge(c: Vector2i, e: String) -> void:
	if not edges.has(c):
		edges[c] = {}
	edges[c][e] = true


## Cells from a to b inclusive: along gx then gy; the other order if a machine is in the way.
func route(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	for gx_first in [true, false]:
		var out: Array[Vector2i] = [a]
		var p := a
		var ok := true
		var order := [0, 1] if gx_first else [1, 0]
		for axis: int in order:
			while (p.x != b.x if axis == 0 else p.y != b.y):
				p += Vector2i(signi(b.x - p.x), 0) if axis == 0 else Vector2i(0, signi(b.y - p.y))
				out.append(p)
				if p != b and by_cell.has(p):
					ok = false
		if ok or not gx_first:
			return out
	return [a, b]


## Belt sprite for a belt cell: {name, flip}. See docs/ART_PIPELINE.md for the edge conventions.
func belt_sprite(c: Vector2i) -> Dictionary:
	var e: Array = (edges.get(c, {}) as Dictionary).keys()
	e.sort()
	var key := ",".join(PackedStringArray(e))
	match key:
		"ne,sw":
			return {"name": "belt_straight_a", "flip": false}
		"nw,se":
			return {"name": "belt_straight_b", "flip": false}
		"ne,se":
			return {"name": "belt_corner_ne_se", "flip": false}
		"ne,nw":
			return {"name": "belt_corner_nw_ne", "flip": false}
		"se,sw":
			return {"name": "belt_corner_se_sw", "flip": false}
		"nw,sw":
			return {"name": "belt_corner_sw_nw", "flip": false}
		"nw,se,sw":
			return {"name": "belt_split", "flip": false}
		"ne,se,sw":
			return {"name": "belt_split", "flip": true}
		"ne,nw,se":
			return {"name": "belt_merge", "flip": false}
		"ne,nw,sw":
			return {"name": "belt_merge", "flip": true}
	return {"name": "belt_straight_a" if e.has("ne") or e.has("sw") else "belt_straight_b", "flip": false}


## Logical bounding box of everything gameplay-relevant (machines, chips, bots, bin, stairs).
func content_rect() -> Rect2:
	var r := Rect2()
	var first := true
	var pts: Array[Vector2] = []
	for id: String in cells:
		pts.append(to_local(Vector2(cells[id])))
	pts.append(to_local(Vector2(scrap_cell)))
	pts.append(to_local(stairs_cell))
	for p in pts:
		var box := Rect2(p + Vector2(-100, -150), Vector2(200, 230))
		r = box if first else r.merge(box)
		first = false
	for c: Vector2i in edges:
		r = r.merge(Rect2(to_local(Vector2(c)) - Vector2(HW, HH), Vector2(HW * 2.0, HH * 2.0)))
	return r
