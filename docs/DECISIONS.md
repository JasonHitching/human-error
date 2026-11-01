# Decisions

One line each. Newest at the bottom. Don't re-argue settled decisions without new evidence.

| # | Decision | Why |
|---|---|---|
| 1 | Godot 4.7.2 (stable), GDScript | Free, mobile export, low friction for AI coding |
| 2 | No runtime LLM/API calls | Cost, latency, offline, determinism |
| 3 | Simulation is pure GDScript (`RefCounted`), no Nodes, no rendering | Headless tests, fast balancing, clean separation |
| 4 | Fixed timestep (10 ticks/s) + single seeded RNG | Reproducible runs, replays, future daily/shared challenges |
| 5 | Build UI/visuals in code, keep `.tscn` scenes minimal | Scene files are verbose and costly for AI to read/edit |
| 6 | Content and tuning in JSON under `game/data/` | Tune without code changes; easy diffs |
| 7 | Tests: tiny custom headless runner, no test framework | Zero dependencies; terse output |
| 8 | Root faults (player fixes) vs knock-on states (self-clearing) | Diagnosis is the skill; makes failures understandable |
| 9 | One repair crew, timed actions, in M0 | Creates a real decision in the first playtest |
| 10 | Vent action on hot machines | Gives "Predict" a verb |
| 11 | Shift-based runs with score + best | Gives a reason to care, and a reason to replay |
| 12 | Playtest via web build on GitHub Pages | Works on PC and phone without installing Godot |
| 13 | One GitHub issue → one cloud session → one PR | Small contexts, small reviews, cheap retries |
| 14 | Opus plans and writes issues; Sonnet implements; Haiku tunes data | Token cost |
| 15 | `repair_mode` tap vs hold is a data setting | Cheap A/B in playtest |
