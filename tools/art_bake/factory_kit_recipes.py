"""Adds Factory Kit recipes (names `factory_kit/<sprite>`) to recipes.json. Idempotent.
Parts use model "fk:<glb>" = art_source/kenney_factory_kit (CC0; same camera/scale/anchors as the conveyor kit).
Same names and openings as the normal set, so IsoFloor can swap sets by prefix.

Style rules (so belts and machines read as one system):
- Every belt cell and every machine base is the kit's pale `conveyor-sides` family (corner = `conveyor-corner`).
- Machines are straight-through: the belt enters one face and leaves the opposite one, so the body's opening
  faces the exit belt. Elbows are belt cells, never inside a machine (see floor.vias in core.json).
Kit axes: +x = ne, +z = se, -x = sw, -z = nw. `machine` has one door on +z at rot 0; rot 270 puts it on sw."""
import json, os
HERE = os.path.dirname(os.path.abspath(__file__))
BIG = [384, 384, 192, 292]
BELT = [256, 200, 128, 126]
CORNER_ROT = {"se_sw": 0, "ne_se": 90, "ne_nw": 180, "nw_sw": 270}  # verified in the bake preview
OPP = {"ne": "sw", "sw": "ne", "se": "nw", "nw": "se"}
DOOR_ROT = {"se": 0, "sw": 270, "nw": 180, "ne": 90}  # machine door faces this exit edge at this rot


def p(model, rot=0, pos=None, scale=None, tint=None):
    d = {"model": "fk:" + model}
    if tint: d["tint"] = tint
    if rot: d["rot_y_deg"] = rot
    if pos: d["pos"] = pos
    if scale: d["scale"] = scale
    return d


def straight_rot(edges):
    return 0 if "ne" in edges else 90


def belt_for(edges):
    if OPP[edges[0]] == edges[1]:
        return p("conveyor-sides", straight_rot(edges))
    return p("conveyor-corner", CORNER_ROT["_".join(edges)])


S = {
    "belt_straight_a": {"canvas": BELT, "parts": [p("conveyor-sides")]},
    "belt_straight_b": {"canvas": BELT, "parts": [p("conveyor-sides", 90)]},
    "belt_corner_ne_se": {"canvas": BELT, "parts": [p("conveyor-corner", CORNER_ROT["ne_se"])]},
    "belt_corner_nw_ne": {"canvas": BELT, "parts": [p("conveyor-corner", CORNER_ROT["ne_nw"])]},
    "belt_corner_se_sw": {"canvas": BELT, "parts": [p("conveyor-corner", CORNER_ROT["se_sw"])]},
    "belt_corner_sw_nw": {"canvas": BELT, "parts": [p("conveyor-corner", CORNER_ROT["nw_sw"])]},
    # shipping: boxes stacked on the end of a belt run
    "machine_warehouse_ne_sw": {"canvas": BIG, "parts": [p("conveyor-sides"), p("box-large", 0, [0, 0.4, 0], 0.8, "#9aa6cf"), p("box-small", 0, [0.1, 0.95, 0], 0.7, "#8190bd")]},
    # QA desk: straight run along nw/se with a scanner arch straddling the belt (the game's QA desk is always nw -> se)
    "desk_hatch": {"canvas": BIG, "parts": [p("conveyor-sides", 90), p("scanner-low", 90)]},
}

# Machine facings. Straight-through ones are the real layouts; elbows are kept for other layouts.
FACINGS = {
    "generator": ["ne_sw", "nw_se", "se_sw"],
    "processor": ["ne_sw", "nw_se", "ne_se", "nw_sw"],
    "assembler": ["ne_sw", "nw_se"],
}
for typ, names in FACINGS.items():
    for n in names:
        e = n.split("_")
        straight = OPP[e[0]] == e[1]
        if typ == "generator":
            top = [p("hopper-square")]
        else:
            model = "machine" if typ == "assembler" else "machine-window"
            if straight:
                exit_edge = "sw" if "sw" in e else "se"  # belts flow ne->sw and nw->se through the screen
                top = [p(model, DOOR_ROT[exit_edge], None, 0.7)]
            else:
                top = [p(model, 0, [-0.12, 0, -0.12], 0.7)]
        S[f"machine_{typ}_{n}"] = {"canvas": BIG, "parts": [belt_for(e)] + top}

path = os.path.join(HERE, "recipes.json")
R = json.load(open(path))
for k in [k for k in R["sprites"] if k.startswith("factory_kit/")]:
    del R["sprites"][k]  # regenerate the whole kit family so removed recipes don't linger
for n, r in S.items():
    R["sprites"]["factory_kit/" + n] = r
json.dump(R, open(path, "w"), indent=1)
