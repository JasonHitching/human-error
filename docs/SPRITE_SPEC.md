# Sprite Spec

Fixed spec for all generated sprites. Kennedy pack = style reference only (check its license before using any pixels).

## Projection
- Fixed 30° isometric, light from top-left, identical on every sprite.
- Ground tile is a diamond **128 px wide × 74 px tall** (`HW=64`, `HH=37` in `iso_floor.gd`). Ratio ~1.73:1, not the common 2:1. If Kennedy is 2:1, don't copy its proportions.
- Every object stands on that diamond. Multi-tile objects use whole multiples of it.

## Canvas sizes and anchors
Keep the existing sizes. The anchor is the ground-contact point, in canvas px (`ANCHORS` in `game/scripts/view/iso_floor.gd`).

| Family | Canvas | Anchor |
|---|---|---|
| `floor_tile`, `floor_tile_alt` | 256×148 | (128, 74) |
| `belt_*` | 256×200 | (128, 126) |
| `machine_*`, `desk_hatch` | 384×384 | (192, 292) |
| `bot_*` (+ `_panic`), `worker` | 192×192 | none: drawn centred on a position |
| `crate` | 128×128 | (64, 84) |
| `crate_stack`, `scrap_bin`, `reject_bin` | 256×256 | (128, 170) |
| `fence` | 256×200 | (128, 126) |
| `wall_back_plain` | 192×340 | (96, 270) |
| `wall_back` | 320×420 | (160, 330) |
| `shadow_machine` | 320×120 | (160, 60) |

Sizes verified against `game/assets/sprites/` and `ANCHORS`. Don't resize a family.

## Format
- Transparent RGBA PNG, no background.
- No baked shadow, except in `shadow_*` sprites.
- Same outline weight, palette and shading steps across all sprites.
- Names keep the existing prefixes (`machine_`, `belt_`, `bot_`, ...) so the anchor lookup works. Bots also have a `_panic` variant.
- Files go in `game/assets/sprites/`.

## Cleanup checklist
1. Trim stray pixels and semi-transparent fringes.
2. Footprint sits on the 128×74 diamond and the anchor point matches the table.
3. Place on a test tile and check y-sort and overlap with neighbours.
4. Verify headlessly (no screenshots, per CLAUDE.md).

## Changing the ratio
Switching to 2:1 means changing `HW`/`HH`, all anchors and the tile art. That is a separate issue and may touch the isometric decisions in `docs/DECISIONS.md`, so it needs Jason's approval first.
