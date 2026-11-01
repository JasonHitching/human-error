# Prototype Vision

> Your coworkers are AI. They're terrible. Hit your target anyway.

The goal: a complete, polished-feeling **mobile prototype** that proves the game is fun and sticky, built by an automated chain with minimal input from Jason.

Each milestone ends with a **checkpoint** (see `docs/CHAIN.md`): quality gates, a report in `docs/checkpoints/`, a git tag, and planning of the next milestone. Milestones after the next one are **intentions, not specs**. The checkpoint that plans them may adjust them based on metrics and playtest notes, recording changes here.

## The game at the end of the prototype
You're the one human on a factory floor of cheerful, incompetent robots. Your job is **quality control**: every product crosses your desk. Bots keep making mistakes (jams, overclocks, misroutes, junk, sloppy work), and each one pulls you away from the desk while the queue piles up. The Foreman sets daily targets; miss twice and you're fired. Between days you train bots. Train them well enough and you're "automated" (promoted to a harder factory). While you're away, the bots run a night shift, badly.

## Milestones

### M2 — The QA Desk *(done — see `docs/checkpoints/M2.md`)*
The worker's own job, so there's no idle time. Every product queues at your desk; swipe to ship or reject; defects come from sloppy bots; a backlog builds while you fix machines; a full queue backs up the line. Only defects you ship reach customers (complaints). **Gate:** idle time < 30% for the greedy autoplayer; career targets still hold.

### M3 — Two Rooms *(specced as issues; replanned at checkpoint M2 from playtests #35, #36)*
Changed from "A Living Floor": one screen with factory + desk was sensory overload (#36), and players couldn't tell what a good product looks like (#35).
- **Spec card:** a reference picture of the perfect product next to the pad; on a wrong call, flash why ("Missed: CRACK" / "That was fine — just a scuff"); the review lists missed defect types.
- **Two screens instead of a walking worker:** the calm **QA office** (default: desk, spec card, queue, ✖/✔) and the **factory floor** (full screen, fix machines). Going between them costs `transition_seconds` (~0.8 s); the worker is "away from desk" on the floor and in transit. Sim gains worker location `office|floor|transit`.
- **Wall monitor** in the office: one light per machine (green / amber / red) with the bot's name; tap → floor. A new red problem flashes and the bot "calls in" with a line.
- **Wheeled robots + juice** on the floor: bots roll around their machine and to the scrap bin (cosmetic; bob/tilt/squash), fix particles, pulses, screen-slide transition.
- **Sprite loader with fallback** (agreed file names, so Jason can draw against them) and **procedural sound** with a mute toggle.
- Later (M4 candidates): Foreman changes the spec mid-career; a "radio" upgrade to fix one simple fault from the office.

### M4 — Career Depth
- **Shift twists:** one per day from day 3 (heatwave, rush order, inspection day, power flicker).
- **Rookie bots** join mid-career (untrained, new personalities); roster grows to about 8 bots.
- **Bot learning:** fix the same mistake on a bot N times and it may learn ("Noted. Will not do that again.").
- **QA depth:** subtle defects and decoys in later days; flip-to-check-back products; X-ray lamp upgrade.
- **More offers:** bigger desk, quick eye, supervise (a watched bot errs less), auto-inspector bot (which errs).

### M5 — Meta & Prestige
- **Save system** (`user://save.json`).
- **Home factory:** a persistent layer between careers. Earn "commendations" to unlock bots, starting perks and cosmetics.
- **Training your replacement:** if all bots reach a training threshold, the Foreman "automates" you, a win. You're promoted to the next factory **tier** (a new layout with more machines and branches; layouts as data).
- **Stats screen:** best days, careers, automations, a funniest-bot award.

### M6 — Night Shift & Daily
- **Night shift:** offline earnings estimated from bot levels and mistake rates (capped), and a funny Foreman report on return, plus a mess to clean up at the start of the next day.
- **Daily career:** the same seed for everyone that day; a local best per daily.
- **Onboarding:** day 1 as a guided tutorial (first jam, first queue, first training).

### M7 — Mobile Ready
- **Android debug APK** built in CI as an artifact (needs Jason's approval if it adds dependencies, which is a stop condition).
- **Touch tuning:** hit areas, swipe thresholds, safe areas, phone aspect ratios. Performance pass. Settings screen.
- **Prototype complete:** final checkpoint report with a recommendation (continue to production art and store, or change).

## Out of scope for the prototype
Monetisation, ads, accounts, backend, multiplayer, final art (Jason may supply art any time via the sprite loader), iOS builds.
