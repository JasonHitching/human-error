# Prototype Vision

> Your coworkers are AI. They're terrible. Hit your target anyway.

The goal: a complete, polished-feeling **mobile prototype** that proves the game is fun and sticky, built by an automated chain with minimal input from Jason.

Each milestone ends with a **checkpoint** (see `docs/CHAIN.md`): quality gates, a report in `docs/checkpoints/`, a git tag, and planning of the next milestone. Milestones after the next one are **intentions, not specs**. The checkpoint that plans them may adjust them based on metrics and playtest notes.

## The game at the end of the prototype
You're the one human on a factory floor of cheerful, incompetent robots. Your job is **quality control**: every product crosses your desk. Bots keep making mistakes (jams, overclocks, misroutes, junk, sloppy work), and each one pulls you away from the desk while the queue piles up. The Foreman sets daily targets; miss twice and you're fired. Between days you train bots. Train them well enough and you're "automated" (promoted to a harder factory). While you're away, the bots run a night shift, badly.

## Milestones

### M2 — The QA Desk *(specced as issues)*
The worker's own job, so there's no idle time. Every product queues at your desk; swipe to ship or reject; defects come from sloppy bots; a backlog builds while you fix machines; a full queue backs up the line. Only defects you ship reach customers (complaints). **Gate:** idle time < 30% for the greedy autoplayer; career targets still hold.

### M3 — A Living Floor
- Bots become **wheeled robots** that roll around their machine, to the scrap bin, and to each other (cosmetic; code-drawn bob/tilt/squash, no walk cycles).
- **The worker is visible and walks:** travel time to a machine depends on distance (gameplay: route choices). A "BRB" sign at the desk.
- **Juice:** tweens, stamp thunk, shake on rejects, pulses, streak counter, simple particles (code-drawn).
- **Sprite loader with fallback:** any PNG in `game/assets/` with an agreed name replaces its code drawing. This makes the game art-ready for Jason.
- **Procedural sound:** simple generated blips for stamp, reject, mistake and alarm (no audio files), with a mute toggle.

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
