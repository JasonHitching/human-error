# Human Error — Game Design

> Your coworkers are AI. They're terrible. Hit your target anyway.

Portrait mobile game. You are the one human worker on a factory floor run by **bots** — AI coworkers who are confident, cheerful and constantly wrong. The **Foreman** sets daily targets. You keep the line running by fixing the bots' mistakes with your one pair of hands (the "crew"). Between shifts you **train** bots so they mess up less — slowly training your own replacement.

**Core loop (moment to moment):** Notice → Diagnose → Fix → Recover
**Run loop:** Shift → Foreman review → Train a bot → Harder shift → … → Fired
**Long-term hook (M2+):** train bots so well that you get *automated* — a win that promotes you to a harder factory (prestige).

**Tone:** cute, miniature, slightly chaotic factory; bots are charming idiots; Foreman is gruff and funny. No realism, no grind.

---

## M1 — Bad Bots (current target)

**Hypothesis:** Fixing characterful bot mistakes under a Foreman's targets is fun, and training bots between shifts makes you want "one more day".

### Bots
- Each working machine (generator, both processors, assembler) is run by one **bot**. The warehouse has no bot.
- Bots come from a roster in `game/data/bots.json`. Each run deals bots to machines randomly (seeded), so every run has a different crew of idiots.
- Each bot has: `name`, `color`, rates for each mistake type (events per minute), a `level` per mistake type (starts 0), and a few short lines it says when it makes a mistake.
- Rates scale with the in-shift ramp and the day multiplier, and drop with training: `rate × train_factor^level`.

Starting roster (tune in data):
| Bot | Speciality (high rate) | Says |
|---|---|---|
| Sparky | Overclock | "MAXIMUM EFFICIENCY!" |
| Clank | Jam | "I have optimised the gears." |
| Loopy | Misroute | "Shortcut found!" |
| Dozer | Wrong recipe | "New product line!" |
| Rusty | A bit of everything | "Oops." |

### Mistakes (what bots do wrong)
Every problem is **caused by a bot** and shown with a speech bubble on that bot's machine, so you can always see *who* did *what*.

| Mistake | Effect | What you see | Fix (tap machine; crew job) |
|---|---|---|---|
| **Jam** | Machine stops (existing fault) | JAMMED | Repair |
| **Overclock** | Machine runs 30% faster but heats 3× faster → soon OVERHEATED | Pulsing "OVERCLOCK", heat bar racing | Tap: cancels overclock + vents |
| **Misroute** | Output goes to the **scrap bin** instead of downstream | Dots fly to a scrap bin at the side; downstream starves | Tap: fix route |
| **Wrong recipe** | Machine makes **junk** instead of its real output; junk travels downstream and **clogs** the next machine's input | Junk dots (different shape/colour); downstream shows CLOGGED | Tap source: fix recipe. Tap clogged machine: clear junk |
| Overheat | Existing fault when heat hits 100 | OVERHEATED | Repair |

Knock-on states (STARVED, BLOCKED) still clear on their own — diagnosis remains the skill.

**One verb:** tap a machine. The crew does the most urgent thing there, in priority order: repair fault → clear clog → fix mistake → vent. One crew job at a time.

### Foreman & career
- A run is a **career** of days. Each day is one shift (`shift_seconds`, default 120).
- Day N target = `target_base + target_per_day × (N−1)`. Mistake rates × `day_rate_mult^(N−1)`.
- Start of shift: Foreman banner, e.g. *"Day 3. 140 widgets. Don't embarrass me."*
- **Foreman review** after each shift:
  - Hit target → +1 training point (+1 bonus at ≥ 125%). Strikes don't reset.
  - Miss → +1 **strike**. At `max_strikes` (2) → **FIRED**. Game over.
- **Training** (after a successful review): pick **1 of 3** offers (seeded), e.g.
  - "Train Sparky: overclocks −40%" (that bot +1 level in that mistake)
  - "Train Loopy: misroutes −40%"
  - "Faster hands: crew jobs −15%" (player upgrade)
- Game over screen: days survived, best days, Restart (new seed) / Replay (same seed).

### Visuals (M1)
Still code-drawn, no art: bot = coloured circle with initial + name under its machine; speech bubble for ~2 s on each mistake; scrap bin drawn at the side; junk dots distinct (e.g. grey squares). Foreman = text banner with a simple icon. Bright colours only for problems that need you.

### Autoplayers (simulated players for balancing)
Renamed from "bots" to avoid confusion: `tools/autoplayers.gd` — `none`, `greedy` (fixes anything immediately, nearest-to-failure first). `sim_runner` can run whole careers and report days survived.

### M1 success criteria
- You can tell which bot did what, every time.
- Fixing a bad bot feels satisfying, sometimes funny.
- Training choices feel meaningful ("Sparky is ruining me — train him").
- After being fired, you want another run.

### Out of scope for M1
Factory growth/expansion, new machines, rookie bots arriving, being "automated", art, sound, monetisation.

---

## M0 — Factory Alive (built; base simulation for M1)

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

## Beyond M1 (candidates — decide after playtest)

- **M2 Training your replacement:** fully trained bots → the Foreman "automates" you (a win) → promotion to a bigger factory with fresh rookies (prestige loop). Rookie bots join mid-career.
- **M3 Growing factory:** bots "improve" the factory by building things — sometimes useless (unfed assemblers, loops) — and you remove/reroute them.
- **Bot learning:** fix the same mistake on a bot N times and it learns ("Noted. Will not do that again.").
- **Shift variety:** shift types (rush order, heatwave, inspection day).
- **Later:** daily seeded shift, shareable factory configs ("keep my terrible factory alive"), presentation pass (cute, miniature, slightly chaotic).

## Constraints that always apply
- No LLM/API calls at runtime. Deterministic simulation that *appears* intelligent.
- No backend, accounts, ads or monetisation until retention is proven.
- Content is data (JSON), so it can be tuned without code changes.
