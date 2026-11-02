# CLAUDE.md

Human Error: portrait mobile factory game, Godot 4.7.2 + GDScript. Design: `docs/GAME_DESIGN.md`. Decisions: `docs/DECISIONS.md` (don't re-argue them).

## How work arrives
- One GitHub issue = one session = one PR. Implement **only** that issue.
- Chain sessions also follow `docs/CHAIN.md` (pause check, handoff, checkpoints). Big picture: `docs/VISION.md`.
- Read the issue, this file, and only the files the issue names or you must touch. Don't explore the whole repo.
- If the issue is ambiguous or blocked, stop and comment on the issue instead of guessing big.
- Before starting, check the issue's "Depends on" issues are closed. If not, stop and say so.
- Branch: `issue-<N>-<short-name>`. PR title: `#<N> <title>`. PR body: what changed, how to test, sim/test output summary, `Closes #<N>`.

## Merging (you merge your own PR — Jason doesn't review every PR)
Squash-merge your PR yourself when ALL are true:
1. Every **Accept** item in the issue is met, and the PR body shows the evidence (test/sim output).
2. Tests pass locally, and CI checks on the PR are green (once CI exists, #2). Never skip, disable or weaken a test to get green.
3. The PR touches only what the issue asks for.
4. None of the stop conditions below apply.

**Stop — don't merge, comment on the PR and leave it for Jason — if the PR:**
- adds a dependency, addon, third-party action, backend, networking, ads or monetisation;
- changes `CLAUDE.md`, `docs/DECISIONS.md` or the design in `docs/GAME_DESIGN.md`;
- deletes or weakens existing tests;
- can't meet an Accept item, or needed a judgement call the issue didn't cover.

After merging: delete the branch; if the merge broke `main`, revert immediately.

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
- World visuals are built in code. Screen UI uses Control/Container/anchor `.tscn` scenes editable in the Godot editor (decision #28). The game is 2D isometric with a 2D camera, never 3D (`docs/UI_STYLE.md`).
- Don't take screenshots unless the issue asks (credit cost); verify headlessly.
- Use static typing in GDScript. Keep files small and single-purpose.
- No new dependencies, addons, backend, networking, ads or monetisation without approval.
- No unrelated refactors. Update docs only when architecture/decisions change.

## Commands
```
godot --headless --path game -s res://tests/run_tests.gd          # tests (must pass before PR)
godot --headless --path game -s res://tools/ui_check.gd                # UI smoke check (CI runs it)
godot --headless --path game -s res://tools/sim_runner.gd -- --seed 1 --runs 50     # sim stats
```
If `godot` is missing: `bash tools/cloud_setup.sh`.

## Token discipline
- Don't re-read files you just wrote. Don't print large files or full logs; show failing lines only.
- Test output: summary + failures only.
- Keep PR descriptions short; the user reviews on a phone.
