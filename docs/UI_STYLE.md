# UI style guide (cleanup pass, Nov 2026)

Source of truth for the UI-1..UI-4 issues. Visual mockups: https://claude.ai/artifact/2u7hFMhC9S6nobrRshQsdk (Jason's canvas; sessions may not be able to open it, so everything needed is written here). Implement in code (`_draw`, Controls, StyleBoxFlat) in a shared `scripts/ui/ui_theme.gd` (class `UiTheme`): **no new assets or fonts** (the default Godot font is fine; a display font may come later with Jason's OK).

## Rules
1. **Colour means "needs you".** Healthy things are neutral grey. Amber = warming up / about to need you. Red = fix now. Never paint healthy machines or bots green.
2. **One primary action per screen**, filled with the accent: Ship (office), Fix worst first (floor), Start career (home), One more career (run end). Everything else is outlined or quiet.
3. **Nothing covers the product** on the desk. Hints are one-time toasts in free space, never over the product, spec or buttons.
4. **Touch targets >= 44 px** (at 390 px wide); primary buttons 60-78 px tall.
5. **No overlapping controls.** Sound and Haptics live in a Settings overlay behind a cog in the top bar, never on the play screens.
6. **No unicode symbols** (draw icons: lines, triangles, circles). No debug text (career seed etc.) unless a debug flag is on.
7. Three text sizes per screen at most. Numbers and titles bold.

## Tokens (720 px design width = 2x the 390 px mock; scale all px by 720/390 ~ 1.85)
| Token | Hex | Use |
|---|---|---|
| bg | #14161B | screen background |
| surface | #1E2129 | cards, top-bar buttons |
| surface_2 | #23262E | inner cards (bot chips) |
| surface_dim | #191C22 | disabled / locked cards |
| line | #3A3F4B | outlines, secondary-button borders |
| track | #2A2E37 | empty bars, empty slots |
| text | #F3F1EC | primary text |
| text_dim | #A6ADBB | labels |
| text_faint | #8A91A0 | tertiary (passes 4.5:1 on bg) |
| accent | #4CC9F0 | primary buttons, quota bar, streak (text on accent: #0B1B22) |
| gold | #F7C948 | commendations, best-days bar, worker's hard hat, "Buy" (text on it: #2A2410) |
| warn | #FFB547 | amber states; warn card bg #2E2718 |
| crit | #FF5D5D | red states; crit card bg #3A1D20; crit text #FF8A8A |
| reject | outline #FF6B6B on #2A1C1F, text #FFC2C2 |

Radii (mock px): cards 14-16, buttons 18-22, chips 10-17. Spacing: 8/12/16 grid; screen side padding 16.

## Components
- **Top bar** (all play screens): left "DAY n" (11, dim) over timer (26, bold); middle "Quota" label + "14 / 24" + 8 px progress bar (accent fill); right two strike pips (12 px circles, outline #5B6271, filled crit when used); far right a 44 px Settings cog button (surface).
- **Buttons:** primary = accent fill, dark text, bold; secondary = transparent or surface with 1 px line border; danger-outline = Reject style. Icons drawn left of the label.
- **Bot chip** (wall monitor): surface_2 card; 34 px avatar circle in the bot's colour with its initial (dark text); name (12, bold); status line (11): "OK" faint, "HOT 72%" warn, "JAMMED"/"CLOGGED"/etc crit. Warn/crit chips get a 2 px border + tinted bg.
- **Machine card** (floor): surface card ~150x72 mock px, 1 px border; title = friendly name (Generator, Press A, Press B, Assembler, Warehouse; map from ids); top-right status: grey dot when OK, or a filled badge "HOT" (warn) / "JAMMED" etc (crit); bottom: bot avatar (18) + bot name, then a 4 px heat bar (grey normally, warn when hot). Crit = 3 px crit border + crit bg + "tap to fix" after the bot name.

## Screens (mock layout, top to bottom)
- **Office:** top bar · wall monitor card ("FACTORY FLOOR" + "Go down" secondary button, 4 bot chips in a row) · queue row (12 small slot pills filled for queued items, "Desk queue 5 / 12 · shelf 0 / 4" text, streak pill on the right in accent) · inspection zone (spec chip "SPEC  6 bolts · label on top · blue body" with a mini product, the big product centred, faint "Swipe left: reject / Swipe right: ship" labels under it) · action row grid 1 : 0.7 : 1 = Reject (danger outline) | Scan (secondary, small) | Ship (primary).
- **Floor (superseded by "Isometric floor" below; the diagram here is legacy, only the top bar and bottom bar still apply):** top bar · "FACTORY FLOOR" label + desk-queue pill on the right (warn style at >= 75%) · diagram with **right-angle conveyors** (vertical/horizontal 4 px belts in #343A46, items as small light dots): Generator top centre -> splits to Press A (left) / Press B (right) -> merge -> Assembler -> "UP TO QA DESK" dashed hatch -> Warehouse ("16 shipped"); small Scrap bin bottom right with a count; the worker (hard hat in gold) near its target · bottom bar grid 1 : 1.2 = "Back to desk" (secondary, up arrow) | "Fix worst first" (primary, wrench).
- **Home:** cog top right · title "HUMAN ERROR" (big, bold) with a small gold hard-hat bar, tagline "Your coworkers are AI. They're terrible." · 3 stat tiles (Best, Careers, Commendations in gold) · "Start career" primary (78 px, subtitle "Tier n · day-1 quota N") · Daily card (secondary, "Daily shift · <date>", subtitle, gold "Play" or "Done" pill) · "Perks" heading · 2-column perk cards (name, 1-2 line description, gold "Buy · 30" button if affordable, else dim "Locked · 40") showing 4, plus "All perks" · footer secondary buttons: All perks, Stats, How to play.
- **Run end (fired):** "FIRED" stamp (crit outline, slight tilt) + "You lasted N days" · Foreman quote card · breakdown card ("Missed by N" big + "score / target", rows: Complaints (-x), Rejected good, Line blocked, divider, "Biggest problem: <bot avatar> <name>, N <mistakes>") · best-days progress (gold bar, "N more to beat it") + "+N commendations" gold pill · bottom: "One more career" primary (78 px), "Replay this seed" secondary, text links Home / Stats. The day review (hit/miss) uses the same card style.

## Isometric floor (supersedes the Floor diagram above; decisions #27-#28)
The game is a **2D isometric** factory-management game. Not 3D: no 3D nodes, no 3D camera, no "moving through" an environment.

**World** (Node2D scenes, isometric tile grid, `Camera2D`): factory, machines, conveyors, items, bots/worker, production activity, problems. The world is larger than the viewport and grows as the factory expands. Never fit the whole factory on screen.
**Screen-space UI** (CanvasLayer + Control): day/progress, health, orders, alerts, selected-machine info, actions, menus. It stays fixed while the world moves under it.

**Navigation:** drag/touch-drag to pan, wheel/pinch to zoom (clamped), tap/click to select, keyboard pan (arrows/WASD) and zoom (+/-). Camera bounds follow the factory extent plus a margin.
**Camera moves** (select, "Fix worst first", alert tap): smooth tween pan, optional zoom to a sensible level, target stays clearly visible and clear of UI panels, no abrupt cuts, and the cause is obvious (the targeted machine is highlighted as the camera arrives). User input cancels a running move.
**Isometric language:** one tile/grid projection, one object scale, correct depth ordering (y-sort), floor / machines / UI clearly separate, and conveyors that are easy to follow (direction, flow, queues visible on the belt).
**Labels:** none permanent. Show a label only above selected or problem machines, drawn in world space and scaled sensibly. UI must not cover the factory unnecessarily; no info dumps.
**Read the factory visually:** flow, queues, struggling machines, bottlenecks and what needs intervention should be legible from machine/belt visuals (colour rule above still applies); UI supports this, not replaces it.
**Loop:** something is wrong -> understand -> locate -> intervene -> observe the result.

## Godot architecture for UI (decision #28)
- Screen UI = Control nodes, Containers and anchors in `.tscn` scenes under `game/scenes/ui/`, themed via `UiTheme`. Scripts attach behaviour; they do not position every element at runtime.
- Keep scenes small and readable so Jason can adjust layout, spacing, typography, panels and buttons in the editor. Code must not overwrite editor-set layout.
- Sim/gameplay, camera, selection, and UI state stay in scripts. Sim never references view/ui.
- Migrate existing code-built screens to scenes incrementally, one screen per issue.

## Verification each UI issue must do (headless first; screenshots are expensive)
- `tools/ui_check.gd`: extend with an **overlap check** (no two buttons' rects intersect on any screen; no control outside the viewport) at the usual window sizes, and a **min target** check (>= 44 mock px scaled). Add camera checks: pan/zoom clamped, focus move ends with target inside the safe (non-UI) viewport rect.
- Do **not** take screenshots by default. Only when the issue explicitly asks, take at most one per changed screen (web export + Playwright "iPhone 13", flags `--use-gl=angle --use-angle=swiftshader --enable-unsafe-swiftshader`). Never commit screenshots.
