# Workflow (for Jason)

You vibe-code from your phone and playtest on your PC (or phone) in a browser.

## The loop
```
Opus session     → plans a milestone, writes issues (rarely)
Sonnet session   → one per issue: "Implement issue #N" → PR
You (phone)      → skim PR, merge
GitHub Actions   → tests + publishes web build
You (PC browser) → playtest the Pages URL
You (phone)      → write feedback as ONE issue → back to top
```

## Starting an implementation session (claude.ai/code, phone)
1. New session → repo `human-error` → model **Sonnet** (Haiku for `model:haiku` issues).
2. Prompt:
   > Implement issue #N. Follow CLAUDE.md. Open a PR when tests pass.
3. Leave it. Come back to a PR.

If a session goes sideways: close it, start a fresh one on the same issue. Don't argue with it in a long chat.
If Sonnet fails the same issue twice: start an **Opus** session on it.

## Reviewing a PR on your phone
- Read the PR description (what changed, how to test, test/sim summary).
- Tests green → merge. You don't need to read every line of code.
- Something looks off → comment on the PR in one message, start a new session: "Address review comments on PR #M".

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
