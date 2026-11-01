# Roadmap

Targets, not commitments. Each phase ends in something playable or measurable.
Status: ☐ not started · ◐ in progress · ☑ done

## M0 — Factory Alive

| Phase | Goal | Deliverable | Issues (draft) |
|---|---|---|---|
| ☐ 0 Foundations | Tooling works end to end | Godot skeleton, headless tests, CI, playable web build URL | M0-01, M0-02 |
| ☐ 1 Simulation core | Factory runs headless | Machines, resource flow, knock-on states, `sim_runner` summary | M0-03 |
| ☐ 2 Faults & crew | Factory breaks; crew can fix it (in sim) | Overheat, jam, repair/vent, shift + score, bot baselines | M0-04 |
| ☐ 3 Playable | You can play a shift | Rendering, tap input, HUD, end screen, restart/replay | M0-05 |
| ☐ 4 Balance | Shifts feel tense, not hopeless | Tuned `balance.json` using sim stats | M0-06 |
| ☐ 5 Playtest gate | Decide: continue / change / kill | Written playtest notes → new issues | — |

**Rule for Phase 5:** no new features until the playtest verdict is written down in `DECISIONS.md`.

## After M0
Picked from the candidates in `GAME_DESIGN.md` based on what the playtest shows. Plan one milestone at a time.

## Rough calendar
- Week 1: M0 phases 0–3
- Week 2: M0 balance + playtest, then M1 planning
- Beyond: decided after the playtest
