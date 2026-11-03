# Art log

One line per asset source: what, where from, licence, who/what made it.

| Asset | Source | Licence | Notes |
|---|---|---|---|
| `art_source/kenney_conveyor_kit/` (61 GLB models) | Kenney, Conveyor Kit 2.0 (31-10-2023), https://kenney.nl/assets/conveyor-kit | CC0 1.0 (credit optional) | Provided by Jason; baked to 2D sprites with `tools/art_bake/` (isometric, yaw 45, pitch 35.264) |
| `game/assets/sprites/*.png` (ART-1 set) | Baked from the Kenney kit above with `tools/art_bake/` (recipes.json); belts, back wall, fence, bots and worker are procedural three.js primitives made for this project | CC0 (kit) / project-original | See `docs/ART_PIPELINE.md` |
| `game/assets/sprites/press/press_0..5.png` | Press machine on a conveyor, 6-frame animation (idle, descend, press, sparks, smoke, reset). Generated with Meshy AI by Jason; sliced from his sheet with `tools/slice_sheet.py` (white background removed, frames aligned) | Jason-provided, Meshy AI generated; check Meshy terms before release | Frames are 297x283, a straight-through belt along the SW-NE axis. Not wired into the game yet (see issue FIX-6) |
| `game/assets/sprites/factory_kit/*.png` (corner belts, machine facings) | Baked from the Kenney Factory Kit (`art_source/kenney_factory_kit/`) with `tools/art_bake/factory_kit_recipes.py` + `kit_recolor.py` (orange trim muted) | CC0 1.0 | Covers every two-edge facing and corner. belt_split/belt_merge and three-edge machine facings have no good kit piece (kit T-junctions are closed tunnels) so they fall back to the normal set |
