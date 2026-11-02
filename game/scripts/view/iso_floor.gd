class_name IsoFloor
extends RefCounted
## Isometric floor layout (pure data + maths, no drawing): grid cells -> logical px, belt routing.
## Axes: gx runs screen down-right (SE), gy runs down-left (SW). One cell = 128 x 74 logical px.

const HW := 64.0
const HH := 37.0
## Baked-pixel anchors (ground cell centre) per sprite family, from docs/ART_PIPELINE.md.
const ANCHORS := {"machine_": Vector2(192, 292), "desk_hatch": Vector2(192, 292), "belt_": Vector2(128, 126), "floor_tile": Vector2(128, 74), "crate_stack": Vector2(128, 170), "crate": Vector2(64, 84), "scrap_bin": Vector2(128, 170), "reject_bin": Vector2(128, 170), "fence": Vector2(128, 126), "wall_back_plain": Vector2(96, 270), "wall_back": Vector2(160, 330), "shadow_machine": Vector2(160, 60), "press": Vector2(150, 205)}
## Belt top surface rise above the ground cell centre (baked px; measured: left/right corner row 65 vs anchor 126).
const BELT_RISE := 61.0
const DIRS := {"se": Vector2i(1, 0), "sw": Vector2i(0, 1), "nw": Vector2i(-1, 0), "ne": Vector2i(0, -1)}
const OPP := {"se": "nw", "nw": "se", "sw": "ne", "ne": "sw"}

var cells: Dictionary = {}  # machine id -> Vector2i
var types: Dictionary = {}  # machine id -> type
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
	types.clear()
	by_cell.clear()
	edges.clear()
	paths.clear()
	for md: Dictionary in machines:
		var c := Vector2i(int(md.get("gx", 0)), int(md.get("gy", 0)))
		cells[String(md["id"])] = c
		types[String(md["id"])] = String(md.get("type", ""))
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
		var stub := _press_stub(String(l["from"]), a, b)
		if stub != Vector2i.ZERO:
			path = [a]
			path.append_array(route(a + stub, b))
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


## Logical px below the machine's ground centre where the worker stands (still inside its own cell).
const WORKER_STOP := Vector2(0, 34)
## Candidate bot spots around a machine, front-right first (gx runs down-right, gy down-left).
const STAND_ORDER: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, -1)]


## True when cell c is free floor: inside the grid, no machine, belt, scrap bin or stairs on it.
func is_free_floor(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= grid.x or c.y >= grid.y:
		return false
	return not by_cell.has(c) and not edges.has(c) and c != scrap_cell and Vector2(c) != stairs_cell


## Cell where the machine's bot stands: first free cell adjacent to the machine, front-right first;
## then the same search two cells out; finally the machine's own front-right neighbour (deterministic).
func stand_cell(id: String) -> Vector2i:
	var m: Vector2i = cells.get(id, Vector2i.ZERO)
	for r in [1, 2]:
		for d in STAND_ORDER:
			if is_free_floor(m + d * r):
				return m + d * r
	return m + STAND_ORDER[0]


## True when logical-px point p (local space, see to_local) lies inside cell c's diamond.
static func in_cell(p: Vector2, c: Vector2i) -> bool:
	var q := p - to_local(Vector2(c))
	return absf(q.x) / HW + absf(q.y) / HH <= 1.0


func _edge(c: Vector2i, e: String) -> void:
	if not edges.has(c):
		edges[c] = {}
	edges[c][e] = true


## Cells from a to b inclusive: along gx then gy; the other order if a machine is in the way.
## Processors use the press sprite, whose belt runs straight through: the output leaves on the side
## opposite the input (one cell straight on) and any bend is on the belt cell after it.
## Returns that first step (Vector2i.ZERO = not a processor, no input yet, or the cell is taken).
func _press_stub(from_id: String, a: Vector2i, b: Vector2i) -> Vector2i:
	if types.get(from_id, "") != "processor":
		return Vector2i.ZERO
	for key: String in paths:
		var p: Array = paths[key]
		if key.ends_with(">" + from_id) and p.size() >= 2:
			var d: Vector2i = p[p.size() - 1] - p[p.size() - 2]
			if a + d == b or by_cell.has(a + d):
				return Vector2i.ZERO
			return d
	return Vector2i.ZERO


## Axis of processor `id`'s press sprite belt: "gy" (SW-NE, as drawn), "gx" (SE-NW, drawn flipped),
## or "" when its belts don't run straight through (static facing sprite instead).
func press_axis(id: String) -> String:
	if types.get(id, "") != "processor":
		return ""
	var o := machine_openings(id)
	if o == ["ne", "sw"]:
		return "gy"
	if o == ["nw", "se"]:
		return "gx"
	return ""


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


## Edge names where belts attach to machine `id`: {"in": [edge, ...], "out": [edge, ...]} (screen edge names).
func machine_ports(id: String) -> Dictionary:
	var ports := {"in": [], "out": []}
	for key: String in paths:
		var ids := key.split(">")
		var p: Array = paths[key]
		if p.size() < 2:
			continue
		if ids[0] == id:
			ports["out"].append(_dir_name(p[1] - p[0]))
		if ids[1] == id:
			ports["in"].append(OPP[_dir_name(p[p.size() - 1] - p[p.size() - 2])])
	return ports


## Distinct belt edges at machine `id`, sorted (ne, nw, se, sw order).
func machine_edges(id: String) -> Array[String]:
	var ports := machine_ports(id)
	var out: Array[String] = []
	for e: String in (ports["in"] as Array) + (ports["out"] as Array):
		if not out.has(e):
			out.append(e)
	out.sort()
	return out


## Edges a machine's sprite is open on: a lone belt gets a straight tunnel (edge + opposite),
## two belts an opposite pair (tunnel) or adjacent pair (corner), three or more an open base.
func machine_openings(id: String) -> Array[String]:
	var e := machine_edges(id)
	if e.size() == 1:
		e.append(OPP[e[0]])
		e.sort()
	return e


## Facing-variant sprite name for a machine, e.g. machine_processor_ne_se (base name if it has no belts).
func machine_sprite(id: String, type: String) -> String:
	var o := machine_openings(id)
	var base := "machine_" + type
	return base if o.is_empty() else base + "_" + "_".join(PackedStringArray(o))


## Layout problems: a belt meeting a machine on a side its sprite variant is closed on.
func facing_mismatches() -> Array[String]:
	var out: Array[String] = []
	for id: String in cells:
		if types.get(id, "qa") == "qa":
			continue  # the QA desk is a desk, not a machine sprite
		var open := machine_openings(id)
		for e: String in machine_edges(id):
			if not open.has(e):
				out.append("%s: belt on %s but sprite is open on %s" % [id, e, ",".join(PackedStringArray(open))])
	return out


static func _dir_name(d: Vector2i) -> String:
	for k: String in DIRS:
		if DIRS[k] == d:
			return k
	return ""


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
