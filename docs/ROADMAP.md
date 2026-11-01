# Roadmap

Targets, not commitments. Each phase ends in something playable or measurable.
Status: ☐ not started · ◐ in progress · ☑ done

## M0 — Factory Alive

| Phase | Goal | Deliverable | Issues |
|---|---|---|---|
| ☑ 0 Foundations | Tooling works end to end | Godot skeleton, headless tests, CI, playable web build URL | #1, #2 |
| ☑ 1 Simulation core | Factory runs headless | Machines, resource flow, knock-on states, `sim_runner` summary | #3 |
| ☑ 2 Faults & crew | Factory breaks; crew can fix it (in sim) | Overheat, jam, repair/vent, shift + score, bot baselines | #4 |
| ☑ 3 Playable | You can play a shift | Rendering, tap input, HUD, end screen, restart/replay | #5 |
| ☑ 4 Balance | Shifts feel tense, not hopeless | Tuned `balance.json` using sim stats | #6 |
| ☑ 5 Playtest gate | Decide: continue / change / kill | Verdict: pivot to Bad Bots (DECISIONS #17) | — |

**Rule for Phase 5:** no new features until the playtest verdict is written down in `DECISIONS.md`.

## M1 — Bad Bots

| Phase | Goal | Issues |
|---|---|---|
| ☐ 1 Bots in the sim | Roster, bots on machines, per-bot jam + overclock | M1-01 |
| ☐ 2 New mistakes | Misroute (scrap), wrong recipe (junk → clog), tap priority | M1-02 |
| ☐ 3 Career | Days, Foreman targets, strikes/fired, training offers | M1-03 |
| ☐ 4 Playable | Bots, bubbles, scrap/junk, Foreman banners, review/training/fired screens | M1-04 |
| ☐ 5 Balance | Careers last a satisfying number of days | M1-05 |
| ☐ 6 Playtest | Is it fun? Do I want another run? | — |

## After M1
Candidates in `GAME_DESIGN.md` (training your replacement, growing factory). Decide after the playtest.
