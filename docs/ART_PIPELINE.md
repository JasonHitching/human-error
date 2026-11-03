# Art pipeline (isometric sprite set)

All gameplay sprites are **baked** from the CC0 Kenney Conveyor Kit (`art_source/kenney_conveyor_kit/`) plus a few procedural three.js pieces (belts, back wall, fence, bots, worker), by `tools/art_bake/`. Contact sheet: `docs/art/contact_sheet.png` (includes a 25% strip).

## Projection facts (for ART-2)
- Camera: orthographic, **yaw 45, pitch 35.264** (true isometric), light from the top-left. World axes: kit +x runs to screen **up-right (NE)**, +z to **down-right (SE)**, -x SW, -z NW.
- **One grid cell = 1 kit unit = a diamond 256 px wide x 148 px tall** at the baked resolution (128 x 74 logical px at 1x; files are baked at **2x** and scale down cleanly). Shared scale: **181.02 px per kit unit** (= 128 * sqrt 2), the same for every sprite.
- Moving one cell: NE = (+128, -74) baked px, SE = (+128, +74), SW = (-128, +74), NW = (-128, -74). Draw order: back to front by (x + z), i.e. smaller screen y first; tall sprites sort by their anchor.
- **Anchor** = the pixel that sits on the ground cell centre (draw the sprite at `cell_centre - anchor`). Heights above the ground go up from there.
- Colours: no amber or red scenery. The orange crate is the only warm item (products / moving items); bot body colours come from `game/data/bots.json`.

## Sprites
Sizes are baked pixels (2x). Machines are one cell wide; belts, floor and bins tile exactly one cell.
Belt directions use the screen edge names: `ne`/`se`/`sw`/`nw`. `belt_straight_a` joins NE-SW, `_b` joins NW-SE. `belt_corner_<e1>_<e2>` joins those two edges. `belt_split` = in NW, out SE and SW; `belt_merge` = in NW and NE, out SE (flip horizontally for the mirrored version). Open sides are dark track, closed sides have a pale rail.

| Sprite | Size px (baked 2x) | Anchor px (ground cell centre) |
|---|---|---|
| `belt_corner_ne_se` | 256x200 | 128,126 |
| `belt_corner_nw_ne` | 256x200 | 128,126 |
| `belt_corner_se_sw` | 256x200 | 128,126 |
| `belt_corner_sw_nw` | 256x200 | 128,126 |
| `belt_merge` | 256x200 | 128,126 |
| `belt_split` | 256x200 | 128,126 |
| `belt_straight_a` | 256x200 | 128,126 |
| `belt_straight_b` | 256x200 | 128,126 |
| `bot_bolt` | 192x192 | 96,150 |
| `bot_bolt_panic` | 192x192 | 96,150 |
| `bot_clank` | 192x192 | 96,150 |
| `bot_clank_panic` | 192x192 | 96,150 |
| `bot_dozer` | 192x192 | 96,150 |
| `bot_dozer_panic` | 192x192 | 96,150 |
| `bot_loopy` | 192x192 | 96,150 |
| `bot_loopy_panic` | 192x192 | 96,150 |
| `bot_nudge` | 192x192 | 96,150 |
| `bot_nudge_panic` | 192x192 | 96,150 |
| `bot_pip` | 192x192 | 96,150 |
| `bot_pip_panic` | 192x192 | 96,150 |
| `bot_rusty` | 192x192 | 96,150 |
| `bot_rusty_panic` | 192x192 | 96,150 |
| `bot_sparky` | 192x192 | 96,150 |
| `bot_sparky_panic` | 192x192 | 96,150 |
| `crate` | 128x128 | 64,84 |
| `crate_stack` | 256x256 | 128,170 |
| `desk_hatch` | 384x384 | 192,292 |
| `factory_kit/belt_corner_ne_se` | 256x200 | 128,126 |
| `factory_kit/belt_corner_nw_ne` | 256x200 | 128,126 |
| `factory_kit/belt_corner_se_sw` | 256x200 | 128,126 |
| `factory_kit/belt_corner_sw_nw` | 256x200 | 128,126 |
| `factory_kit/belt_straight_a` | 256x200 | 128,126 |
| `factory_kit/belt_straight_b` | 256x200 | 128,126 |
| `factory_kit/desk_hatch` | 384x384 | 192,292 |
| `factory_kit/machine_assembler_ne_sw` | 384x384 | 192,292 |
| `factory_kit/machine_assembler_nw_se` | 384x384 | 192,292 |
| `factory_kit/machine_generator_ne_sw` | 384x384 | 192,292 |
| `factory_kit/machine_generator_nw_se` | 384x384 | 192,292 |
| `factory_kit/machine_generator_se_sw` | 384x384 | 192,292 |
| `factory_kit/machine_processor_ne_se` | 384x384 | 192,292 |
| `factory_kit/machine_processor_ne_sw` | 384x384 | 192,292 |
| `factory_kit/machine_processor_nw_se` | 384x384 | 192,292 |
| `factory_kit/machine_processor_nw_sw` | 384x384 | 192,292 |
| `factory_kit/machine_warehouse_ne_sw` | 384x384 | 192,292 |
| `fence` | 256x200 | 128,126 |
| `floor_tile` | 256x148 | 128,74 |
| `floor_tile_alt` | 256x148 | 128,74 |
| `machine_assembler` | 384x384 | 192,292 |
| `machine_assembler_ne_nw_se` | 384x384 | 192,292 |
| `machine_assembler_ne_se` | 384x384 | 192,292 |
| `machine_assembler_ne_sw` | 384x384 | 192,292 |
| `machine_generator` | 384x384 | 192,292 |
| `machine_generator_ne_sw` | 384x384 | 192,292 |
| `machine_generator_se_sw` | 384x384 | 192,292 |
| `machine_processor` | 384x384 | 192,292 |
| `machine_processor_ne_se` | 384x384 | 192,292 |
| `machine_processor_nw_se` | 384x384 | 192,292 |
| `machine_processor_nw_sw` | 384x384 | 192,292 |
| `machine_warehouse` | 384x384 | 192,292 |
| `machine_warehouse_ne_sw` | 384x384 | 192,292 |
| `reject_bin` | 256x256 | 128,170 |
| `scrap_bin` | 256x256 | 128,170 |
| `shadow_machine` | 320x120 | 160,60 |
| `wall_back` | 320x420 | 160,330 |
| `wall_back_plain` | 192x340 | 96,270 |
| `worker` | 192x192 | 96,150 |

Notes
- **Facing variants:** `machine_<type>_<edges>` (e.g. `machine_processor_ne_se`) is open on exactly the belt edges that meet the machine (a lone belt gets a straight tunnel). `IsoFloor.machine_sprite()` picks it; the plain `machine_<type>` is the fallback. Needed set = distinct edge sets in `game/data/factories`; add a variant in `tools/art_bake/facing_recipes.py` when a layout needs one (`test_iso_floor.gd` fails if it's missing).
- **One belt per cell (FIX-5 rule):** belt tiles never sit on machine cells, so a machine sprite's baked belt is the only belt in its own cell and must run only toward sides that meet a belt tile (facing variants do). A sprite must not bake a belt arm toward a side with no belt (e.g. `machine_warehouse_ne_sw` is a dead end: belt arm `ne` only, no tunnel cover) and must not use the kit `conveyor` mesh where the layout is not a straight pass-through. `desk_hatch` uses an all-open procedural belt slab so it fits any QA belt layout. Press frames (`sprites/press/`, Meshy) have a built-in belt along SW-NE: only usable where both ends meet belts (issue #155).
- `machine_processor` is also Press A/B. `crate` is the product / moving item. `shadow_machine` is a soft ellipse (black, 35% alpha) to draw under machines.
- **No `machine_<type>_light.png`:** the kit has no obvious indicator on the cover pieces, so none was baked. ART-3 can draw a small light in code (or a procedural sphere can be added to `recipes.json`).
- `bot_<name>_panic` = same bot with red eyes and a red antenna tip. All 8 bots (5 + rookies) are baked.
- Not baked (not needed): per-state machine variants; the game tints and glows instead (ART-3).

## Current game with the new sprites dropped in
Checked on a phone-size web export (iPhone 13 viewport): the title, day intro, office and floor screens look **identical to before**. The floor is drawn as cards and a belt diagram in code, the office has no bot or bin art on screen, and the only sprite lookups in the code are `bot_<name>_panic` (floor, drawn by `BotView` only while a machine is RED, aspect-fit into a square rect, so it fits), `reject_bin` (qa desk, only when drawn) and the product overlays. I could not screenshot a RED machine in the export; the panic bot is a square-fit drop-in, expect it to look bigger and more solid than the old code bot. So nothing looks broken and nothing uses the new art yet: ART-2 rebuilds the floor around it. Things ART-2 must handle: sprites are 2x (the loader scales to fit a rect), bots are square with the figure standing at anchor (96,150), machines are 384x384 with anchor (192,292), and `reject_bin` is a solid box (reads as a crate, not a bin).

## Factory Kit (phase 1 / core)
`factory_kit/*` sprites are baked from the CC0 Kenney Factory Kit 3.0 (`art_source/kenney_factory_kit/`, recipe parts use `"model": "fk:<glb>"`; same camera, scale, anchors and 2x size as above, same names and openings as the normal set). A factory JSON picks the set with `floor.sprite_set` (`core.json` = `"factory_kit"`); `IsoFloor.resolve_sprite()` tries `factory_kit/<name>` for `machine_*`, `belt_*` and `desk_hatch`, and falls back to the normal sprite. Tier 1/2 don't set it. Recipes live in `factory_kit_recipes.py` (idempotent); after baking run `python3 kit_recolor.py ../../game/assets/sprites/factory_kit` to mute the kit's orange trim (orange/red stays for problems and products). Needed set = the distinct machine openings and belt shapes in `core.json` (`test_iso_floor.gd` checks them).

## Re-bake
```
cd tools/art_bake
npm init -y && npm install three@0.170.0          # uncommitted
ln -sfn ../../art_source/kenney_conveyor_kit/glb models
ln -sfn ../../art_source/kenney_factory_kit/glb models_factory   # Factory Kit ("fk:" parts)
python3 -m http.server 8766 &                      # from tools/art_bake
node bake.js bake_all                              # writes game/assets/sprites/*.png
node bake.js bake <outDir> <name>...               # a few sprites
python3 contact_sheet.py ../../game/assets/sprites ../../docs/art/contact_sheet.png 1600   # needs Pillow
python3 pipeline_table.py                          # regenerates the table above
```
`recipes.json` maps each sprite to parts `{model | proc, pos:[x,y,z], rot_y_deg, scale (number or [x,y,z]), tint}` and a `canvas:[w,h,anchor_x,anchor_y]`. `proc` parts: `belt` (arms), `wall`, `fence`, `bot`, `worker`. Bots are generated from `game/data/bots.json`. `game/tests/test_art_sprites.gd` checks every table row above exists with the documented size, with alpha.
