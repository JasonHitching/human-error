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
path = os.path.join(HERE, "recipes.json")
R = json.load(open(path))
for n, r in S.items():
    R["sprites"]["factory_kit/" + n] = r
json.dump(R, open(path, "w"), indent=1)
