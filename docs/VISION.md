# Prototype Vision

> Your coworkers are AI. They're terrible. Hit your target anyway.

The goal: a complete, polished-feeling **mobile prototype** that proves the game is fun and sticky, built by an automated chain with minimal input from Jason.

Each milestone ends with a **checkpoint** (see `docs/CHAIN.md`): quality gates, a report in `docs/checkpoints/`, a git tag, and planning of the next milestone. Milestones after the next one are **intentions, not specs**. The checkpoint that plans them may adjust them based on metrics and playtest notes, recording changes here.

## The game at the end of the prototype
You're the one human on a factory floor of cheerful, incompetent robots. Your job is **quality control**: every product crosses your desk. Bots keep making mistakes (jams, overclocks, misroutes, junk, sloppy work), and each one pulls you away from the desk while the queue piles up. The Foreman sets daily targets; miss twice and you're fired. Between days you train bots. Train them well enough and you're "automated" (promoted to a harder factory). While you're away, the bots run a night shift, badly.

## Milestones

### M2 — The QA Desk *(done — see `docs/checkpoints/M2.md`)*
The worker's own job, so there's no idle time. Every product queues at your desk; swipe to ship or reject; defects come from sloppy bots; a backlog builds while you fix machines; a full queue backs up the line. Only defects you ship reach customers (complaints). **Gate:** idle time < 30% for the greedy autoplayer; career targets still hold.

### M3 — Two Rooms *(done — see `docs/checkpoints/M3.md`; replanned at checkpoint M2 from playtests #35, #36)*
Changed from "A Living Floor": one screen with factory + desk was sensory overload (#36), and players couldn't tell what a good product looks like (#35).
- **Spec card:** a reference picture of the perfect product next to the pad; on a wrong call, flash why ("Missed: CRACK" / "That was fine — just a scuff"); the review lists missed defect types.
- **Two screens instead of a walking worker:** the calm **QA office** (default: desk, spec card, queue, ✖/✔) and the **factory floor** (full screen, fix machines). Going between them costs `transition_seconds` (~0.8 s); the worker is "away from desk" on the floor and in transit. Sim gains worker location `office|floor|transit`.
- **Wall monitor** in the office: one light per machine (green / amber / red) with the bot's name; tap → floor. A new red problem flashes and the bot "calls in" with a line.
- **Wheeled robots + juice** on the floor: bots roll around their machine and to the scrap bin (cosmetic; bob/tilt/squash), fix particles, pulses, screen-slide transition.
- **Sprite loader with fallback** (agreed file names, so Jason can draw against them) and **procedural sound** with a mute toggle.
- Later (M4 candidates): Foreman changes the spec mid-career; a "radio" upgrade to fix one simple fault from the office.

### M4 — Career Depth *(done — see `docs/checkpoints/M4.md`; specced as issues #53–#58 at checkpoint M3)*
Main aim: **player choices matter** (careful ≈ greedy since M2). Target by the end: careful career median ≥ greedy + 2.
- **M4-01 Floor walking with real travel time** (#53, from Jason): distance between machines costs time; optional queued fix; the order of fixes matters.
- **M4-02 Shift twists** (#54): one per day from day 3 (heatwave, rush order, inspection day, power flicker), data in `twists.json`.
- **M4-03 QA depth** (#55): the Foreman changes the spec mid-career (M3 candidate); subtle defects in later days. Aim: careers stop ending almost only on `sloppy`.
- **M4-04 Rookie bots + bot learning** (#56): rookies join mid-career (roster ~8); fixing the same mistake N times may teach a bot.
- **M4-05 New offers + balance** (#57): radio (fix a jam from the office, M3 candidate), supervise, auto-inspector (which errs); full career balance.
- Deferred to M5 or later: flip-to-check-back products, X-ray lamp.

### M5 — Meta & Prestige *(specced as issues #84–#89 at checkpoint M4)*
Main aim: **a lost career still moves you forward**, and long-term training pays off in a win.
- **M5-01 Save system** (#84): versioned `user://save.json`, atomic write, corrupt fallback, migrates the local stats from #72.
- **M5-02 Commendations + Home screen** (#85): points earned per career; a Home screen between careers.
- **M5-03 Perks** (#86): spend commendations on small permanent starting bonuses (`data/perks.json`); sim measures them.
- **M5-04 Train your replacement** (#87): bots get "trained"; all trained → the Foreman automates you (the win, DECISIONS #22).
- **M5-05 Factory tiers** (#88): layouts as data; automation unlocks tier 2 (more machines, a second branch).
- Checkpoint M5 (#89). Stats screen already exists (#72/#80); a funniest-bot award can be added there later.
- Planning notes (M4 checkpoint): perks must not make `none` viable; automation must be reachable for `human_careful` (5–30%) but rare for `greedy`. Deferred again to M6 with onboarding: flip-to-check-back, X-ray lamp, bigger desk/quick-eye rework.

### CORE — Calm Core *(current; issues #161 onward; see decision #30)*
Design reset: the game felt too busy. Strip to a tiny factory (Hopper → Machine → QA → Shipping, 2 bots, Kenney Factory Kit art), three mistake types (jam, overheat, sloppy), obvious QA defects, and day phases (clock-in, shift, end of day). M2–M5 systems stay in code, switched off by data, and return later as career unlocks. M6/M7 are paused until the core is proven fun.

### M6 — Night Shift & Daily
- **Twist yardstick fix (#101):** twists optional from day 3 (`twist_chance`), compared with non-twist days of the same day number.
- **Night shift (#100):** offline earnings estimated from bot levels and mistake rates (capped, clock-safe), a funny Foreman report on return, plus a mess to clean up at the start of the next day.
- **Daily career (#99):** the same date-derived seed for everyone that day (no networking); a local best per daily.
- **Teach-me tools (#98):** flip-to-check-back and X-ray lamp (deferred from M4).
- **Onboarding (#97):** day 1 as a guided, skippable tutorial (first jam, first queue, first training, the new tools).
- Planning notes (M5 checkpoint): human-paced players rarely get automated, so M5's tier 2 is out of reach for them; watch this in playtests before M7. The bigger desk / quick-eye rework moves to the M7 backlog.

### M7 — Mobile Ready
- **Android debug APK** built in CI as an artifact (needs Jason's approval if it adds dependencies, which is a stop condition).
- **Touch tuning:** hit areas, swipe thresholds, safe areas, phone aspect ratios. Performance pass. Settings screen.
- **Prototype complete:** final checkpoint report with a recommendation (continue to production art and store, or change).

## Out of scope for the prototype
Monetisation, ads, accounts, backend, multiplayer, final art (Jason may supply art any time via the sprite loader), iOS builds.
