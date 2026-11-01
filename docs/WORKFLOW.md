# Workflow (for Jason)

You vibe-code from your phone and playtest on your PC (or phone) in a browser.

## The loop
```
Opus session     → plans a milestone, writes issues (rarely)
Sonnet session   → one per issue: "Implement issue #N" → PR
Sonnet session   → merges its own PR when CLAUDE.md merge criteria are met
GitHub Actions   → tests + publishes web build
You (PC browser) → playtest the Pages URL
You (phone)      → write feedback as ONE issue → back to top
```

## Starting an implementation session (claude.ai/code, phone)
1. New session → repo `human-error` → model **Sonnet** (Haiku for `model:haiku` issues).
2. Prompt:
   > Implement issue #N. Follow CLAUDE.md.
3. Leave it. It merges itself if the merge criteria in `CLAUDE.md` are met; otherwise it leaves the PR open with a comment saying why.

If a session goes sideways: close it, start a fresh one on the same issue. Don't argue with it in a long chat.
If Sonnet fails the same issue twice: start an **Opus** session on it.

## PRs
- Sessions merge their own PRs when the criteria in `CLAUDE.md` are met. You only see PRs left open for a reason (new dependency, design change, unmet criteria) — those have a comment explaining why.
- To unblock one: reply on the PR in one message, start a new session: "Address the comments on PR #M, then follow CLAUDE.md merge rules".
- Something bad merged? New session: "Revert PR #M".

## Playtesting on PC
- Open the GitHub Pages URL (set up in issue #2). Mouse click = tap.
- The window is portrait; that's intended.
- Optional: install Godot 4.7.2 on PC, `git pull`, open `game/project.godot`, press F5. Only needed for debugging.

## Writing feedback (one issue per playtest)
Title: `Playtest <date>`. Body — terse bullets:
```
- seed 1234: overheat too frequent, couldn't keep up after 2 min
- can't tell BLOCKED from STARVED
- shift felt too long
- fun moment: saving B while A was jammed
```
Label it `playtest`. An Opus session turns it into design changes + new issues.

## Models
| Label | Model | For |
|---|---|---|
| `model:opus` | Opus | design, planning, hard bugs |
| `model:sonnet` | Sonnet | most implementation |
| `model:haiku` | Haiku | tuning JSON values, small doc edits |

## One-time setup (cloud environment)
In the cloud environment settings (environment menu in a session's title bar → Edit → **Setup script**), paste:
```
bash tools/cloud_setup.sh || true
```
If the setup script runs before the repo is cloned in your environment, paste the contents of `tools/cloud_setup.sh` instead.
