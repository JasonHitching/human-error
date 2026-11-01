# M0 issue drafts

Drafts to review before they become GitHub issues. Each is self-contained for a fresh session.
All: milestone `M0`. Do in order; each depends on the previous one.

---

## M0-01 Godot project skeleton + headless test runner
Labels: `model:sonnet`

**Goal:** an empty, correctly configured Godot project with a working headless test command.

**Do**
- `game/project.godot`: name "Human Error"; viewport 720×1280; stretch mode `canvas_items`, aspect `expand`; handheld orientation portrait; renderer `gl_compatibility` (web/mobile); main scene `res://main.tscn`. On desktop, window size 405×720.
- `game/main.tscn` (minimal) + `game/scripts/main.gd`: shows a centred "Human Error" label, built in code.
- `game/tests/run_tests.gd` (extends `SceneTree`): finds every `res://tests/test_*.gd`, runs each method starting with `test_`, prints one line per failure plus a summary `N passed, M failed`, exits with code 0/1. Provide assertion helpers (`assert_eq`, `assert_true`, `assert_near`) in `game/tests/test_case.gd` that test files extend.
- `game/tests/test_smoke.gd` with one passing test.
- `.gitignore` for Godot 4 (`.godot/`, export output). Keep `*.import` and `*.uid` files tracked.
- Create empty dirs with `.gdkeep`: `scripts/sim`, `scripts/view`, `scripts/ui`, `data`, `tools`.

**Accept:** `godot --headless --path game -s res://tests/run_tests.gd` prints `1 passed, 0 failed` and exits 0; a deliberately failing test makes it exit 1 (verify, then remove it). Project opens in the editor without errors (`godot --headless --path game --quit` has no errors).

**Not:** any game logic, CI, export presets.

---

## M0-02 CI: tests on PRs + web build to GitHub Pages
Labels: `model:sonnet`

**Goal:** every PR runs tests; every push to `main` publishes a playable web build.

**Do**
- `.github/workflows/ci.yml`: on `pull_request` and `push` to `main`: install Godot 4.7.2 headless (same URL as `tools/cloud_setup.sh`), run tests.
- On push to `main` only (after tests pass): download Godot 4.7.2 export templates (cache them with `actions/cache`), export the `Web` preset, deploy with `actions/upload-pages-artifact` + `actions/deploy-pages`.
- `game/export_presets.cfg` with a `Web` preset: **thread support off** (so GitHub Pages works without special headers), exclude `tests/*` and `tools/*`.
- Approved dependencies: official `actions/*` only. No third-party actions or Docker images.
- Add the Pages URL to `README.md` and `docs/WORKFLOW.md`.

**Accept:** workflow YAML is valid; the export command works locally in the cloud session (export templates downloaded to `~/.local/share/godot/export_templates/4.7.2.stable/`); PR body lists the one manual step for Jason: *Settings → Pages → Source: GitHub Actions*.

**Not:** Android/iOS exports.

---

## M0-03 Simulation core: machines, flow, knock-on states
Labels: `model:sonnet`

**Goal:** the factory runs headless and moves resources through the chain. No faults yet.
Read `docs/GAME_DESIGN.md` § M0 (Layout, Resources, Machines, Machine states, Determinism).

**Do** (all in `game/scripts/sim/`, pure `RefCounted`, static typing)
- `game/data/factory_m0.json`: machines (id, type, position hint 0..1 x/y for the view, input/output resource, capacities, process_time), and links (from, to, transit_time).
- `game/data/balance.json`: `tick_rate: 10`, shift length, plus fields later issues add.
- `sim_config.gd`: loads + validates both JSON files into typed data; clear error on bad data.
- `machine.gd`: id, type, input/output buffers, progress, state (`WORKING, IDLE, STARVED, BLOCKED`; leave room for faults).
- `factory.gd` public API (the view and tests use only this):
  - `func _init(config: SimConfig, seed: int)`
  - `func step() -> void` — one fixed tick
  - `var tick: int`, `var shipped: int`, `var machines: Array[Machine]`
  - `func get_machine(id: String) -> Machine`
  - `func items_in_transit() -> Array` — `{from, to, progress: float}` so the view can draw moving dots
- Generator produces `raw`; pushes to whichever linked processor has input space, alternating on ties. Warehouse increments `shipped`.
- Single `RandomNumberGenerator` owned by `Factory`, seeded in `_init` (unused until M0-04 but in place).
- `game/tools/sim_runner.gd` (extends `SceneTree`): args `--seed N --runs N --shift-seconds N`; runs headless and prints a compact summary: shipped (mean/min/max), % of ticks each machine spent in each state.
- Tests: flow reaches warehouse; STARVED when no input; BLOCKED when downstream full; same seed ⇒ identical state after N ticks.

**Accept:** tests pass; `sim_runner` output pasted (short) in PR body.

**Not:** faults, crew, rendering.

---

## M0-04 Faults, repair crew, shift + score
Labels: `model:sonnet`

**Goal:** the factory breaks on its own, and a crew can fix it, all in the sim.
Read `docs/GAME_DESIGN.md` § M0 (Root faults, Player actions, The shift).

**Do**
- Machine heat (0–100): rises while WORKING (`heat_per_sec`), falls otherwise (`cool_per_sec`). At 100 → `OVERHEATED`.
- `JAMMED`: per-tick chance while WORKING (`jam_chance_per_sec` × ramp), using the factory RNG.
- Ramp: fault pressure multiplier rises linearly from `ramp_start` to `ramp_end` over the shift (in `balance.json`).
- Crew: one crew. `func request_action(machine_id: String) -> int` returns an enum `ActionResult { STARTED_REPAIR, STARTED_VENT, CREW_BUSY, NOTHING_TO_DO }`.
  - Repair a faulted machine: takes `repair_seconds`; then clears fault, heat → 0.
  - Vent a WORKING machine with heat ≥ `vent_min_heat`: machine pauses `vent_seconds`, heat drops at `vent_cool_per_sec`.
  - Expose `crew_busy: bool`, `crew_target: String`, `crew_progress: float`.
  - `repair_mode` in `balance.json`: `"tap"` (default — action runs to completion) or `"hold"` (action progresses only while held; `func release_action() -> void` cancels it and progress resets). Bots act as if holding.
- Shift: `func is_over() -> bool` after `shift_seconds`; `var target: int` from balance.
- Faulted machines don't process; knock-on states propagate naturally from M0-03 logic.
- Record actions as `(tick, machine_id)` so a run can be replayed exactly: `func replay(actions: Array) ` or constructor option.
- Bots in `game/tools/bots.gd`: `none` (never acts), `greedy` (repairs any fault immediately, else vents hottest machine ≥ 80 heat). `sim_runner --bot none|greedy` reports shipped stats, faults per shift by type, mean seconds machines spent faulted, % of runs with 2+ simultaneous faults.
- All new numbers in `balance.json` / `factory_m0.json`.
- Tests: overheat triggers at 100; vent reduces heat; crew busy rejects second action; repair clears fault; hold mode: release cancels and resets progress; same seed + same actions ⇒ same result.

**Accept:** tests pass; `sim_runner` output for both bots (seed 1, 50 runs) in PR body. Values don't need to be balanced yet.

**Not:** rendering, input.

---

## M0-05 Playable: rendering, tap input, HUD, end screen
Labels: `model:sonnet`

**Goal:** you can play a shift in the browser.
Read `docs/GAME_DESIGN.md` § M0 (Player actions, Visuals).

**Do**
- `scripts/view/factory_view.gd` (Node2D, `_draw`): machines as rounded rects at their position hints; colour by state (faults bright red/orange with text "JAMMED"/"OVERHEAT"; STARVED/BLOCKED muted grey-blue with small text; WORKING green; IDLE neutral); heat bar on each; links as lines; moving dots from `items_in_transit()`; crew progress ring/bar on the target machine.
- `main.gd`: owns the `Factory`, steps it at fixed `tick_rate` using an accumulator in `_process`; view interpolates between ticks for smooth motion.
- Tap/click on a machine → `request_action`. In `hold` repair mode, call `release_action()` when the finger/mouse is released or leaves the machine. Feedback: brief flash/text for `CREW_BUSY` ("Crew busy") and `NOTHING_TO_DO` on a knock-on machine ("Not broken — look upstream/downstream").
- `scripts/ui/hud.gd`: time left, shipped / target, best (saved to `user://best.json`), crew status.
- End-of-shift overlay: shipped / target, best, **Restart** (new seed) and **Replay** (same seed). Show seed small in a corner.
- All built in code; `main.tscn` stays minimal. Works with mouse and touch.

**Accept:** tests still pass; describe in the PR how you verified (e.g., headless run of main scene for N frames with no errors). Jason playtests via Pages after merge.

**Not:** art, sound, particles, menus beyond the end overlay.

---

## M0-06 Balance pass
Labels: `model:haiku` (escalate to sonnet if code changes are needed)

**Goal:** a shift is tense but winnable. Only edit `game/data/*.json`.

**Targets** (seed 1, 100 runs):
- `none` bot ships 25–40% of target.
- `greedy` bot ships 90–110% of target (a thoughtful human — venting early, prioritising — should beat it).
- 8–15 root faults per shift, with at least one moment where 2+ faults overlap in most runs.
- Overheat ≈ 40–60% of faults (predictable vs sudden balance).

**Do:** iterate values with `sim_runner`, then report a before/after table in the PR.

**Not:** code changes.
