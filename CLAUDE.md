# CLAUDE.md

Human Error: portrait mobile factory game, Godot 4.7.2 + GDScript. Design: `docs/GAME_DESIGN.md`. Decisions: `docs/DECISIONS.md` (don't re-argue them).

## How work arrives
- One GitHub issue = one session = one PR. Implement **only** that issue.
- Read the issue, this file, and only the files the issue names or you must touch. Don't explore the whole repo.
- If the issue is ambiguous or blocked, stop and comment on the issue instead of guessing big.
- Branch: `issue-<N>-<short-name>`. PR title: `#<N> <title>`. PR body: what changed, how to test, sim/test output summary, `Closes #<N>`.

## Layout
```
game/                 Godot project (open game/project.godot)
  data/               JSON content + tuning
  scripts/sim/        simulation: pure RefCounted, NO Nodes, NO rendering, NO Input
  scripts/view/       drawing (Node2D/_draw), reads sim state only
  scripts/ui/         HUD, screens
  tests/              test_*.gd files + run_tests.gd (excluded from export)
  tools/              headless dev scripts, e.g. sim_runner.gd (excluded from export)
tools/                cloud_setup.sh
docs/                 design, roadmap, decisions
```

## Rules
- Sim never references view/ui. View calls sim only via its public API.
- All randomness via the sim's seeded RNG. Fixed timestep. No `randf()`/`randi()` globals.
- Tuning numbers live in `game/data/*.json`, not in code.
- Build visuals in code; keep `.tscn` files minimal.
- Use static typing in GDScript. Keep files small and single-purpose.
- No new dependencies, addons, backend, networking, ads or monetisation without approval.
- No unrelated refactors. Update docs only when architecture/decisions change.

## Commands
```
godot --headless --path game -s res://tests/run_tests.gd          # tests (must pass before PR)
godot --headless --path game -s res://tools/sim_runner.gd -- --seed 1 --runs 50     # sim stats
```
If `godot` is missing: `bash tools/cloud_setup.sh`.

## Token discipline
- Don't re-read files you just wrote. Don't print large files or full logs; show failing lines only.
- Test output: summary + failures only.
- Keep PR descriptions short; the user reviews on a phone.
