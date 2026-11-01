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
| ☑ 1 Bots in the sim | Roster, bots on machines, per-bot jam + overclock | M1-01 |
| ☑ 2 New mistakes | Misroute (scrap), wrong recipe (junk → clog), tap priority | M1-02 |
| ☑ 3 Career | Days, Foreman targets, strikes/fired, training offers | M1-03 |
| ☑ 4 Playable | Bots, bubbles, scrap/junk, Foreman banners, review/training/fired screens | M1-04 |
| ☑ 5 Balance | Careers last a satisfying number of days | M1-05 |
| ☑ 6 Playtest | Is it fun? | Verdict: concept good; too much idle → QA desk (DECISIONS #23) |

## M2 — The QA Desk

| Phase | Goal | Issues |
|---|---|---|
| ☑ 1 QA in the sim | Queue, defects, ship/reject, complaints, idle metric | #27 |
| ☑ 2 QA desk screen | Desk strip, product drawing, swipe, BRB, streak | #28 |
| ☑ 3 Balance | Idle < 30%, careers still 6–10 days | #29, #34 |
| ☑ Checkpoint M2 | Gates, report, plan M3 | #30 → `docs/checkpoints/M2.md` |

## M3 — Two Rooms

| Phase | Goal | Issues |
|---|---|---|
| ☑ 1 Spec card | Reference product, "why was that wrong", missed list | #38 |
| ☑ 2 Worker location | Office / floor / transit in the sim, autoplayers, balance | #39 |
| ☑ 3 Two screens | QA office + factory floor, transitions | #40 |
| ☑ 4 Wall monitor | Machine lights, bots calling in | #41 |
| ☑ 5 Living floor | Wheeled robots, juice | #42 |
| ☑ 6 Art & sound ready | Sprite loader + naming, procedural sfx, mute | #43 |
| ☑ Checkpoint M3 | Gates, report, plan M4 | #44 → `docs/checkpoints/M3.md` |

## M4 — Career Depth

| Phase | Goal | Issues |
|---|---|---|
| ☐ 1 Floor walking | Travel time on the floor; fix order matters | #53 |
| ☐ 2 Shift twists | One twist per day from day 3 | #54 |
| ☐ 3 QA depth | Spec changes, subtle defects | #55 |
| ☐ 4 Roster | Rookie bots, bot learning | #56 |
| ☐ 5 Offers + balance | Radio, supervise, auto-inspector; careful ≥ greedy + 2 | #57 |
| ☐ Checkpoint M4 | Gates, report, plan M5 | #58 |

## M5–M7
See `docs/VISION.md`. Each is planned by the previous checkpoint (`docs/CHAIN.md`).
