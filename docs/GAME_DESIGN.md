# Human Error — Game Design

> The factory is smart enough to run itself, but not smart enough to survive without you.

Portrait mobile game. An autonomous factory runs on its own; the player watches, predicts trouble, and intervenes with a scarce resource (their repair crew). The game is the act of correcting an autonomous system.

**Core loop:** Observe → Predict → Intervene → Recover → Improve → Repeat
**Long-term hook (M4, unproven):** Fix → Teach → Automate → Expand → New problem → Fix

**Open genre question (decide before M3):** active crisis-management game vs idle/automation game. Working assumption: *automation absorbs known problems so the player's attention moves to new ones* — the player is always needed, just for harder things.

---

## M0 — Factory Alive (current target)

**Hypothesis to test:** Is watching an autonomous factory fail, diagnosing the root cause, and choosing what to fix with limited help, fun?

### The shift
- A run is one **shift**: 180 seconds (data-driven).
- Score = **products shipped** to the warehouse. Show current score, shift target, and best score.
- Fault pressure **ramps up** over the shift so tension builds toward the end.
- End-of-shift screen: shipped / target, best, **Restart** (new seed) and **Replay** (same seed).

### Layout (default, data-driven)
```
            Generator
            ↙       ↘
   Processor A     Processor B
            ↘       ↙
            Assembler
                ↓
            Warehouse
```
Two parallel processors give redundancy: one failure slows the factory, two stop it. That makes "which do I fix first" a real question.

The Generator pushes to whichever processor has input space (alternating on ties).

### Resources
`raw` → `component` → `product`

### Machines
Each machine has (from data): input capacity, output capacity, process time, heat per second working, cool per second idle, jam chance per second.

### Machine states
Two kinds of state. **This distinction is the core of the game.**

**Root faults** — the machine is broken. Only the player can fix these.
| Fault | Cause | Readability |
|---|---|---|
| OVERHEATED | Heat reaches 100% while working | **Predictable** — heat bar visibly climbs |
| JAMMED | Random chance while working (seeded) | **Sudden** — surprise, must react |

**Knock-on states** — the machine is fine, but something upstream or downstream isn't. They clear on their own.
| State | Meaning |
|---|---|
| STARVED | No input available |
| BLOCKED | Output full, nowhere to send it |

Plus normal states: WORKING, IDLE.

A fault upstream starves everything downstream; a fault downstream backs up and blocks everything upstream. The player's skill is reading symptoms and finding the root cause.

### Player actions — one verb: tap a machine
The player has **one repair crew**. The crew does one job at a time.

| Tap on… | Action | Duration (data) |
|---|---|---|
| A faulted machine | **Repair** — clears the fault, resets heat to 0 | ~2.0 s |
| A working machine with heat ≥ 50% | **Vent** — machine pauses, heat drops fast | ~1.0 s |
| Anything while crew is busy | Rejected, with visible "crew busy" feedback | — |
| A knock-on state machine | Nothing — show a hint pointing at the cause | — |

- Repair = reactive. Vent = predictive (this is where "Predict" in the loop gets a verb).
- The crew is the scarce resource. Two problems at once means a decision.
- **Experiment:** `repair_mode` setting — `tap` (crew finishes the job on its own) vs `hold` (you hold your finger on the machine; you *are* the crew). Playtest both.
- Depth comes from decisions, not controls. If the playtest says "not enough to do", next inputs in order: **throttle** (slower, cooler), **reroute** a link, **shut down** a machine. These are also the building blocks for M4 "teach the factory" rules.

### Visuals (M0)
Ugly but readable, and **must have motion**:
- Machines: rectangles, coloured by state; label; heat bar.
- Conveyors: lines; resources as small dots moving along them.
- Faults: unmistakable (colour + icon/text). Knock-on states: muted.
- HUD: timer, shipped/target, best, crew status.
- No art, sound, particles.

### Determinism
- All randomness from one seeded RNG owned by the simulation.
- Fixed-timestep simulation (10 ticks/s), independent of frame rate.
- The same seed + same player actions at the same ticks = the same run.

### M0 success criteria
- Factory starts and runs with no input.
- Resources visibly flow; machines visibly fail.
- Root faults and knock-on states are distinguishable at a glance.
- Tapping changes the outcome; the crew limit creates choices.
- **After a shift ends, I want to play another one.**

### Kill / redesign signals
- Watching is boring.
- Faults feel random rather than understandable.
- Repairing feels like chores.
- No real decision about what to fix.
- I don't care about the score.

---

## Beyond M0 (candidates — decide after playtest, not before)

- **M1 Pressure:** more machines and branches, more fault types, power as a shared constraint.
- **M2 Intervention economy:** more crew/tools, upgrades between shifts.
- **M3 Factory intelligence:** the factory detects or handles some faults itself.
- **M4 Reverse loop:** after you fix the same fault pattern N times, the factory offers "Automate this response?" — the factory learns from you.
- **Shift variety:** career of shifts at a growing factory, shift types (rush order, heatwave).
- **Later:** daily seeded shift, shareable factory configs ("keep my terrible factory alive"), presentation pass (cute, miniature, slightly chaotic).

## Constraints that always apply
- No LLM/API calls at runtime. Deterministic simulation that *appears* intelligent.
- No backend, accounts, ads or monetisation until retention is proven.
- Content is data (JSON), so it can be tuned without code changes.
