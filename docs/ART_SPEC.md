# Art spec (for Jason and any artist / AI tool)

Goal look: **cute, miniature, slightly chaotic industrial**. A toy-diorama factory run by cheerful, incompetent robots. Readable first, pretty second: the player must read machine state at a glance on a phone.

Game: portrait, 2D. The game already loads PNGs from `game/assets/sprites/` by exact filename (table below, and `game/assets/sprites/README.md`). A missing file falls back to the code drawing, so art can be added **one file at a time**. Wrong-size files are scaled to fit (aspect kept, centred).

## 1. Stage 1: concept art (do this first, about a weekend)
1. **Mood board:** 8-12 references + three adjectives.
2. **Palette:** 8-12 colours. The state colours below are reserved (see section 2).
3. **Three key frames at phone proportion (390x844, export 2x = 780x1688):**
   - the **office** (the QA desk room: desk, lamp, a window or monitor onto the floor),
   - the **factory floor** (generator, two presses, assembler, hatch up to the desk, warehouse, scrap bin),
   - the **run-end scene** (the Foreman and a FIRED moment).
4. **Character sheet:** the five bots (distinct silhouettes; keep each bot's colour, see `game/data/bots.json`), the worker (the only one with legs; hard hat), the Foreman.
5. **Pipeline test:** ONE machine (`machine_processor.png`) and ONE bot (`bot_sparky.png`) as final PNGs. Send them over; they get dropped into the real game and screenshotted at phone size before the rest is drawn.

Do NOT draw full sprite sets yet: tiers, rookie bots and layouts may still change the list.

## 2. Colour language (do not break)
- **Amber = warming up / about to need you; red = fix now.** No scenery, prop or bot body may use these hues at high saturation. Healthy things are neutral or cool.
- Game UI tokens are in `docs/UI_STYLE.md` (bg #14161B, accent cyan #4CC9F0, gold #F7C948, warn #FFB547, crit #FF5D5D). Art must sit well behind them: keep large areas dark/mid-value so white text and the cyan accent stay readable.
- Bot colours (from `game/data/bots.json`): Rusty teal #3FB8A0, Loopy purple #B98BFF, Sparky yellow #F2D24B, Dozer orange #FF9A4D, Clank steel grey-blue (check the file).

## 3. Production rules
- Transparent PNG. Draw at **2x** the sizes below, or export at exactly the size given. Same **light direction (top-left)** and outline weight on everything. One palette.
- Keep each future-animated thing as its **own layer** (see section 5).
- Readability test: shrink each sprite to 48 px. If you can't tell what it is or its state, simplify.
- Licensing: use tools whose terms allow commercial use; keep a note of the tool/prompt/licence for each asset in `docs/ART_LOG.md` (create it).

## 4. Asset list (exact filenames; sizes in px at 1x)
| File | What | Size |
|---|---|---|
| `bg_office.png` | office room background | 720x1280 |
| `bg_floor.png` | factory floor background (machines are placed on it) | 720x1280 |
| `bg_runend.png` (new) | run-end / Foreman scene | 720x1280 |
| `machine_generator.png`, `machine_processor.png`, `machine_assembler.png`, `machine_warehouse.png` | machines, idle/OK | 160x160 |
| `machine_<type>_<state>.png` (optional) | states: `jammed`, `overheated`, `clogged`, `blocked`, `starved` | 160x160 |
| `desk_hatch.png` | the hatch up to the QA desk, on the floor | 160x160 |
| `bot_<name>.png` | `sparky`, `dozer`, `clank`, `rusty`, `loopy` (+ rookies later) | 96x96 |
| `bot_<name>_panic.png` (optional) | when its machine is RED | 96x96 |
| `worker.png` (new) | the player's worker, standing | 96x96 |
| `foreman.png` (new) | the Foreman portrait | 256x256 |
| `product.png` | good product body (bolts/label may be drawn on top) | 256x192 |
| `defect_<type>.png` | `missing_bolt`, `crack`, `wrong_paint`, `flipped_label`, `dent` (drawn on a 256x192 canvas aligned to the product) | 256x192 |
| `decoy_<type>.png` | `scuff`, `sticker_blue`, `sticker_green` (harmless; same canvas) | 256x192 |
| `monitor.png` | wall-monitor frame in the office | 640x300 |
| `scrap_bin.png`, `reject_bin.png`, `lamp.png` | props | 128x128 |
| `icon_ship.png`, `icon_reject.png`, `icon_sound.png`, `icon_mute.png` | button icons | 96x96 |

Currently supported by the loader: everything above except `bg_runend`, `worker`, `foreman` (new names, wired up by the "art-ready" issue).

## 5. Layered animated parts (needs loader support; art-ready issue)
Draw these as separate transparent PNGs, same canvas size and registration as their parent so they stack exactly:
- Bots: `bot_<name>_body.png`, `bot_<name>_wheel.png`, `bot_<name>_eye_ok.png`, `bot_<name>_eye_panic.png`.
- Machines: `machine_<type>_body.png`, `machine_<type>_light.png` (a plain white/grey light the game tints green/amber/red), `machine_<type>_steam.png` (optional).
- Belts: `belt_tile.png` (64x64, seamless, scrolls).

## 6. Composition notes (approximate; UI may still change)
At 720x1280: keep the top ~140 px calm (the top bar sits there) and the bottom ~200 px dark and simple (the action buttons sit there). On the floor, the diagram runs top to bottom: Generator (top centre) > Press A / Press B > Assembler > hatch > Warehouse. Machine art must work as modular parts because later factory tiers rearrange and add machines; don't paint machines into the background.

## 7. What gets built on the code side (the "art-ready" issue)
Layout anchors as data (so a background defines where things sit), support for the layered names in section 5 and the three new names in section 4, state tint of `machine_*_light`, parallax and scrolling layers, belt tiles that join machines, contact shadows, floor glow by state, ambient effects (steam, sparks, dust, lamp flicker), a vertically scrolling taller floor, and a `ui_check` mode that runs with and without sprites. Until then, drop files in and they simply replace the code drawings.

## 8. Scene composition: making it a place, not sprites on a page
**Camera:** one fixed 3/4 top-down angle (a diorama look). Every machine, prop and character is drawn from that same angle, lit from the top-left. Decide this in the concept stage; it changes everything downstream. (Alternatives if you prefer: pre-rendered simple 3D models exported as 2D sprites for perfectly consistent light; or flat side-on. Don't mix.)

**Layer stack, back to front** (each its own transparent PNG or tile set):
1. `scene_wall.png` back wall (pipes, windows, sign "Days without incident: 0", the window up to the office).
2. `scene_floor_tile.png` seamless floor tile (64x64) + a few damage/decal variants (`floor_decal_<n>.png`, oil stain, hazard stripes).
3. Set dressing that sits on the floor with its own contact shadow: crates, barrels, lockers, a decorative idle conveyor loop. File names `prop_<name>.png`.
4. **Gameplay machines** (section 4) with a contact shadow each: `shadow_machine.png` (soft ellipse, black at 35% alpha, 160x60).
5. **Belts as real tiles** that join machines: `belt_straight.png`, `belt_corner.png`, `belt_split.png`, `belt_merge.png` (64x64, seamless, drawn so the game can scroll them).
6. Bots and the worker.
7. Foreground overlays: hanging lamps `fg_lamp.png`, pipes `fg_pipe_<n>.png`, steam puffs `fx_steam_<n>.png`, a vignette `fx_vignette.png` (720x1280, transparent centre).
Keep the gameplay machines visually distinct from set dressing: bigger, brighter rim light, and always the only things with a coloured status light.

**Light carries gameplay (important).** The base scene is dark and low-contrast. Healthy machines sit in a soft warm pool of light. A machine in trouble casts a coloured glow onto the floor around it: amber for hot, red for jammed/overheated (the code tints `machine_<type>_light.png` and a floor glow sprite `fx_glow.png`, a white radial gradient 256x256, tinted by state). Scenery must never use amber/red at high saturation, so the glow stays the loudest thing on screen.

**Readability budget** (Jason's feedback: the old UI was hard on the eye): background detail stays low-contrast and mid-to-dark; only gameplay things get strong contrast. Test by squinting: at 25% size you should still see exactly which machines need you.

**Ambient life** (mostly done in code from the layers above): scrolling belts, blinking status lights, steam puffs on a timer, sparks on a fix, a flickering `fg_lamp`, bots idling, dust motes drifting through the light pools, slight parallax of layers 1-3 when the floor scrolls.

**A taller floor:** the floor scene may be taller than the screen (e.g. 720x2000) and scrolls vertically; later factory tiers add machines further down. Paint backgrounds in tiles or in a long strip you can extend, not one fixed picture.

**Kit-of-parts first.** For the first hero shot, produce: wall + floor tiles, 6-8 props, the belt set, five machines, the shadow and glow sprites. That's enough for a convincing floor; expand later.
