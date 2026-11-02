"""Adds machine facing-variant recipes (machine_<type>_<edges>) to recipes.json. Idempotent.
Edges are screen edges: kit +x = ne, +z = se, -x = sw, -z = nw. The kit covers are tunnels
(open on two opposite faces: rot 0 = ne/sw, rot 90 = nw/se) or corners (cover-corner opens on
two adjacent faces: rot 0 = se+sw, 90 = ne+se, 180 = ne+nw, 270 = nw+sw).
Variants needed = every distinct belt-edge set in game/data/factories (see test_iso_floor.gd)."""
import json, os
HERE = os.path.dirname(os.path.abspath(__file__))
VARIANTS = {
    "generator": ["se_sw"],
    "processor": ["ne_se", "nw_sw", "nw_se"],
    "assembler": ["ne_nw_se", "ne_se", "ne_sw"],
    "warehouse": ["ne_sw"],
}
VEC = {"ne": (1, 0, 0), "se": (0, 0, 1), "sw": (-1, 0, 0), "nw": (0, 0, -1)}
OPP = {"ne": "sw", "sw": "ne", "se": "nw", "nw": "se"}
CORNER_ROT = {"se_sw": 0, "ne_se": 90, "ne_nw": 180, "nw_sw": 270}
CANVAS = [384, 384, 192, 292]
COVER = {"generator": ("cover-hopper", "#8f9bc4"), "processor": ("cover-window", None), "warehouse": ("cover", None)}


def part(model, rot=0, tint=None, pos=None, scale=None):
    p = {"model": model}
    if rot: p["rot_y_deg"] = rot
    if tint: p["tint"] = tint
    if pos: p["pos"] = pos
    if scale: p["scale"] = scale
    return p


def recipe(typ, name):
    edges = name.split("_")
    straight = len(edges) == 2 and OPP[edges[0]] == edges[1]
    rot = 0 if "ne" in edges else 90  # straight tunnel: ne/sw = 0, nw/se = 90
    parts = [part("conveyor", rot)] if straight else [{"proc": "belt", "arms": edges}]
    if typ == "assembler":
        free = [e for e in ("sw", "nw", "ne", "se") if e not in edges][:2]
        for i, e in enumerate(free):
            v = VEC[e]
            parts.append(part("robot-arm-a" if i == 0 else "robot-arm-b", 90 if v[0] else 0,
                              pos=[v[0] * 0.55, 0, v[2] * 0.55], scale=0.4))
    else:
        model, tint = COVER[typ]
        if straight:
            parts.append(part(model, rot, tint))
        else:
            parts.append(part("cover-corner", CORNER_ROT[name], tint))
    return {"canvas": CANVAS, "parts": parts}


path = os.path.join(HERE, "recipes.json")
R = json.load(open(path))
for typ, names in VARIANTS.items():
    for n in names:
        R["sprites"][f"machine_{typ}_{n}"] = recipe(typ, n)
json.dump(R, open(path, "w"), indent=1)
