"""Adds Factory Kit recipes (names `factory_kit/<sprite>`) to recipes.json. Idempotent.
Parts use model "fk:<glb>" = art_source/kenney_factory_kit (CC0; same camera/scale/anchors as the conveyor kit).
Same names and openings as the normal set, so IsoFloor can swap sets by prefix. Phase 1 (core.json) set only."""
import json, os
HERE = os.path.dirname(os.path.abspath(__file__))
BIG = [384, 384, 192, 292]
BELT = [256, 200, 128, 126]
CORNER_ROT = {"se_sw": 0, "ne_se": 90, "ne_nw": 180, "nw_sw": 270}  # verified in the bake preview


def p(model, rot=0, pos=None, scale=None, tint=None):
    d = {"model": "fk:" + model}
    if tint: d["tint"] = tint
    if rot: d["rot_y_deg"] = rot
    if pos: d["pos"] = pos
    if scale: d["scale"] = scale
    return d


S = {
    "belt_straight_a": {"canvas": BELT, "parts": [p("conveyor-sides")]},
    "belt_straight_b": {"canvas": BELT, "parts": [p("conveyor-sides", 90)]},
    # generator: hopper on a belt run (ne/sw)
    "machine_generator_ne_sw": {"canvas": BIG, "parts": [p("conveyor"), p("hopper-square")]},
    # assembler: machine body over the corner belt (ne + se open)
    "machine_assembler_ne_se": {"canvas": BIG, "parts": [p("conveyor-corner", 90), p("machine", 0, [-0.12, 0, -0.12], 0.7)]},
    # shipping: boxes stacked on the end of a belt run
    "machine_warehouse_ne_sw": {"canvas": BIG, "parts": [p("conveyor"), p("box-large", 0, [0, 0.4, 0], 0.8, "#9aa6cf"), p("box-small", 0, [0.1, 0.95, 0], 0.7, "#8190bd")]},
    # QA desk: all-open slab with a scanner
    "desk_hatch": {"canvas": BIG, "parts": [{"proc": "belt", "arms": ["ne", "se", "sw", "nw"]}, p("scanner-low")]},
}
# Corner belts (kit conveyor-corner), named by the game's belt_corner_<e1>_<e2> sprites.
for n, edges in {"belt_corner_ne_se": "ne_se", "belt_corner_nw_ne": "ne_nw", "belt_corner_se_sw": "se_sw", "belt_corner_sw_nw": "nw_sw"}.items():
    S[n] = {"canvas": BELT, "parts": [p("conveyor-corner", CORNER_ROT[edges])]}

# Two-edge machine facings the normal set has. Three-edge facings (split/merge lanes) and belt_split/merge
# have no good kit piece (kit T-junctions are closed tunnels), so IsoFloor falls back to the normal set for those.
OPP = {"ne": "sw", "sw": "ne", "se": "nw", "nw": "se"}


def belt_for(edges):
    if OPP[edges[0]] == edges[1]:
        return p("conveyor", 0 if "ne" in edges else 90)
    return p("conveyor-corner", CORNER_ROT["_".join(edges)])


def straight_rot(edges):
    return 0 if "ne" in edges else 90


FACINGS = {"generator": ["se_sw"], "processor": ["ne_se", "nw_sw", "nw_se"], "assembler": ["ne_sw"]}
for typ, names in FACINGS.items():
    for n in names:
        e = n.split("_")
        straight = OPP[e[0]] == e[1]
        if typ == "generator":
            top = [p("hopper-square")]
        elif typ == "processor":
            top = [p("machine-window", straight_rot(e) if straight else 0, None if straight else [-0.12, 0, -0.12], 0.7)]
        else:
            top = [p("machine", straight_rot(e) if straight else 0, None if straight else [-0.12, 0, -0.12], 0.7)]
        S[f"machine_{typ}_{n}"] = {"canvas": BIG, "parts": [belt_for(e)] + top}

path = os.path.join(HERE, "recipes.json")
R = json.load(open(path))
for n, r in S.items():
    R["sprites"]["factory_kit/" + n] = r
json.dump(R, open(path, "w"), indent=1)
