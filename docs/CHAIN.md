# Automated chain protocol

The prototype is built by a chain of cloud sessions, one per GitHub issue. Each session reads this file.

## Every chain session
1. Read `CLAUDE.md`, this file, and your issue. Implement only your issue.
2. **Pause check first:** if any open issue has the label `pause` or is titled `PAUSE`, do nothing. Comment on your issue "Chain paused by Jason" and end.
3. Godot: if missing, `bash tools/cloud_setup.sh`, then `godot --headless --path game --import` once.
4. Before a PR: `run_tests.gd` and `tools/ui_check.gd` must both pass.
5. Waiting for CI: subscribe to your PR's activity and end your turn; don't poll.
6. **STRICT:** any unmet Accept item or target means don't merge. That's a stop condition. Comment on the PR with the numbers and what's blocking.
7. After your PR merges (or, for checkpoints, after your work is pushed), start the next session (see "Handoff"). Don't try to delete remote branches (blocked in cloud sessions; harmless to leave).
8. Stop and don't hand off if: you hit a CLAUDE.md stop condition, you fail the same thing twice, or your issue says `Next: none`. Comment on the issue saying exactly what Jason needs to do.

## Handoff
Your issue body ends with `Next: #<N>` (or `Next: none`). Read issue #N's labels and title, then call `create_session`:
- title: `#<N> <short title> (chain)`, source_url `https://github.com/JasonHitching/human-error`
- model by label: `model:opus` → `claude-opus-5-5`, `model:haiku` → `claude-haiku-5-5`, otherwise `claude-sonnet-5-5`
- prompt: `Implement GitHub issue #<N> in JasonHitching/human-error. Follow CLAUDE.md and docs/CHAIN.md.`

Then end your turn.

## Checkpoint issues (label `checkpoint`, model:opus)
A checkpoint closes a milestone and plans the next one. The session:
1. **Gates:** pull `main`; run tests, `ui_check`, and the `sim_runner` commands the milestone's issues used. If a gate fails: open a fix issue (Sonnet, `Next: #<this checkpoint>`), hand off to it, and stop. A second failure on the same gate means stop for Jason.
2. **Report:** write `docs/checkpoints/<Mx>.md` (≤ 60 lines): what was built, metrics vs targets, known issues, risks, what to try when playing. Mark the checkpoint by pushing a **branch** (tag pushes are blocked in cloud sessions): `git push origin HEAD:refs/heads/checkpoint/<mx>` (lowercase, e.g. `checkpoint/m4`), using `main` after your docs PR merges.
3. **Feedback:** read open issues labelled `playtest` (and their comments). Fold the feedback into the plan; close each one with a comment saying what changed.
4. **Plan the next milestone** from `docs/VISION.md`, adjusting it if the metrics or feedback say so. Record design changes in `docs/VISION.md` (the milestone section) and the checkpoint report. Do **not** edit `CLAUDE.md`, `docs/GAME_DESIGN.md` or `docs/DECISIONS.md` (those stay a stop condition; Jason's call). Write 3–6 self-contained issues in the same style as previous milestones (Goal / Do / Accept / Not, "Depends on", labels `M<x>` + `model:*`), each ending `Next: #<following>`. The last one is the next checkpoint (labels `checkpoint`, `model:opus`). After M7's checkpoint there is no next milestone: write the final report and use `Next: none`.
5. Update `docs/ROADMAP.md`. Commit the docs (`docs/VISION.md`, `docs/ROADMAP.md`, `docs/checkpoints/*`) via a PR and merge it. Those files aren't covered by the CLAUDE.md stop conditions.
6. Hand off to the first new issue.

Checkpoint sessions keep context small: read the checkpoint reports and issue summaries, not the whole codebase.

## Jason's controls
- **Play:** https://jasonhitching.github.io/human-error/ is always the latest `main`.
- **Give feedback:** open an issue labelled `playtest` with bullets. The next checkpoint reads it.
- **Pause:** open an issue titled `PAUSE`. Chain sessions stop. To resume: close it and start a session with "Resume the chain: implement the lowest open chain issue. Follow CLAUDE.md and docs/CHAIN.md."
- **Roll back:** every checkpoint has a branch `checkpoint/<mx>` (tags can't be pushed from cloud sessions).
