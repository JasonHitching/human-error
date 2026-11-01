# Autopilot (read by "conductor" sessions; Jason is asleep)

Goal: keep improving the game with no supervision, spend credits only up to the limit (never overage), and survive running out mid-way. Log: comments on issue **#75** (one short comment per cycle/checkpoint). Play: https://jasonhitching.github.io/human-error/

## Work queue (in order; playtest issues labelled `playtest` jump the queue)
0. In flight at handoff: #71 fault pacing; Hook chain #74 -> #73 -> #72.
1. Resume M4: #54 shift twists (PR #65 exists: its session must merge `main` in and re-tune to the Balance standard), #55 QA depth + Scan, #56 rookie bots + learning, #57 offers, then the M4 checkpoint #58 (plans M5).
2. Whatever the M4 checkpoint plans next (M5 meta: save + home factory; M6 night shift + daily; M7 mobile build). Each milestone ends in its own checkpoint issue per `docs/CHAIN.md`.

## Rules
- **Models:** Sonnet for everything; Haiku for data-only balance. No Opus.
- **Concurrency:** at most 2 work sessions at once; a conductor never works on code itself, it only starts/resumes sessions, merges ready PRs and logs.
- **Attempts:** 1 attempt + 1 resume per issue (resume = "continue from branch X's WIP"; see below). Then label it `parked`, log why, move on.
- **Credit guard (every cycle, first thing):** `get_session` with no id; read `external_metadata.rate_limit_info`. If `isUsingOverage` is true, or `status` is not `allowed`/`allowed_warning` -> comment "credit limit hit, autopilot paused until <resetsAt>" and stop (start nothing). If `status` is `allowed_warning` -> only finish/merge in-flight work; start nothing new.
- **Never:** push to `main` directly, weaken/skip tests, add dependencies/backend/ads/accounts, edit `CLAUDE.md` / `docs/DECISIONS.md` / `docs/GAME_DESIGN.md`, delete data. CLAUDE.md stop conditions apply to every PR.
- **Needs Jason:** log it with the exact question, skip it, continue with other queue items (never idle on one decision).
- **Accept amendments:** allowed once per issue when evidence shows the target relied on an obsolete assumption; log the numbers; never outside the Balance standard bounds.
- **Resume after a dead session:** if a session failed/idle with a pushed WIP branch and no PR, start a Sonnet session with: "Implement issue #N. RESUME: branch `<branch>` has WIP from a session that ran out of credits; check it out, merge origin/main, finish the Accept items, PR + merge per CLAUDE.md. Don't start over." After `git pull` always run `godot --headless --path game --import` once (stale class cache).

## Balance standard (overrides older issue text)
Judge balance on the human-paced players (`sim_runner --player human|human_careful`), never only the instant `greedy`/`careful`. Where an older issue gives career-median ranges for greedy/careful, apply them to `human`/`human_careful` instead:
- `human` career median 5-15, p10 >= 3; `human_careful` median >= `human` and <= 24; instant `greedy` max < 30; `none` fired by day 3 in >= 90%.
- Day-1 `human`: shipped >= target; desk queue full <= 55%; (after #71) calm >= 25% of the shift.

## Conductor cycle (cheap; end the session when done, don't wait or poll)
1. Pause check: an open issue titled `PAUSE` -> log "paused" and stop. Then the credit guard above.
2. Read the last 3 comments on #75, `gh`/GitHub open PRs, open issues and recent sessions (`list_sessions`, limit 15). Only what's needed.
3. In this order: (a) merge any PR that is green, meets its issue's Accept items (evidence in the PR) and no stop condition applies; (b) resume any dead session with a WIP branch; (c) start the next queue item whose dependencies are closed, up to 2 concurrent sessions; (d) if a PR is stuck on a target, apply the amendment rule or park it.
4. **Checkpoint** when >= 3 PRs merged since the last checkpoint, or a queue group/milestone finished: pull `main`, `godot --headless --path game --import`, run tests + `ui_check` + `sim_runner --career --player human --runs 100 --seed 1` (and `human_careful`). Gates: tests + ui_check pass; Balance standard holds. If they pass: push branch `checkpoint/auto-NN` (next number; tags are blocked) at `main`'s head and log it with the numbers. If a gate fails: open a fix issue (Sonnet) and start it; don't checkpoint.
5. Log ONE short comment on #75: what merged, what started, what's parked/needs Jason, last checkpoint, credit status. Then end.

## Morning report (when the queue is empty or credits are out)
One comment on #75 headed "Morning report": shipped (PR numbers), parked/needs Jason (with exact questions), latest checkpoint, what to playtest first.
