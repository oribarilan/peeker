# Proposal

## Why

The checks that need the real app on screen are two flow scripts plus a hand-run checklist (`docs/screenontest.md`) that an agent drives from prose. The 2026-10-31 run showed the cost: the hand checks weren't repeatable, two of them were set up wrong, a fixed sleep let a click land on an open menu, and the flows' cleanup never stopped the screen recorder. This change turns the screen checks into one deterministic suite that people and agents run the same way. It is the first of two changes; the second adds flows for PDF page edits, image editing and crash recovery, and retires the checklist. Decided on 2026-10-31.

## What Changes

- **One suite:** `scripts/screen-test.sh` runs the routing check and every flow, keeps going after a failure, prints one ok/FAIL summary per flow, and exits non-zero when any check failed. Each flow's evidence goes in its own folder under one run folder in `build/evidence/`.
- **Scripts move:** the flow scripts, `drive.swift`, `pdf-tool.swift` and `e2e-routing.sh` move from `.claude/skills/run-peeker/` to `scripts/screen/`, and the run-peeker skill points at them.
- **Video only when asked:** runs save screenshots and `results.txt`; `--record` adds a screen recording. A recording can't stop early and keep its file, so recorded runs take longer.
- **Waiting on state, not time:** `drive wait` waits, with a timeout, for a window, sheet, menu or labeled control to appear or go away. The flows use it after menus, sheets, launches and window opens. Short settling sleeps stay.
- **Hands off the user's Peeker:** the suite refuses to start while a Peeker other than the build under test is running, and only ever quits the build under test.
- **Recovery copies kept apart:** the app writes crash-recovery copies to `$PEEKER_RECOVERY` when it's set, the way `$PEEKER_CONFIG` moves the config. Screen runs point it at their evidence folder, so a killed run never leaves a record the user's own Peeker would restore.
- **Fewer screen checks:** two of today's hand checks become in-process tests: Reopen on the failure view, and a click on an animated image pausing and resuming it through the real mouse path.
- **Recorder check scripted:** `record-flows.sh` checks that only one shortcut recorder listens at a time and that switching apps stops it.
- **Rule:** `AGENTS.md` says to run the suite before a release and after changes to the host UI or a plugin's views, on the maintainer's go, and that a user-facing change adds or updates a flow step or says why not.
- **Not included:** running the suite in CI (hosted runners can't grant the Accessibility and Screen Recording permissions), an XCUITest target, flows for the close prompt and reloads (unit tests cover them), and converting every sleep.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `documents`: crash-recovery copies go to `$PEEKER_RECOVERY` when it's set.

## Impact

- `Sources/Host/Documents/RecoveryStore.swift`: the shared store reads `PEEKER_RECOVERY`.
- `scripts/screen/` (new): `drive.swift` (with `wait`), `pdf-tool.swift`, `e2e-routing.sh`, `record-flows.sh`, `pdf-edit-flow.sh`; `scripts/screen-test.sh` (new).
- `.claude/skills/run-peeker/SKILL.md`: points at the suite and the moved scripts.
- `Tests/`: tests for the failure view's Reopen and for a click pausing an animation.
- `AGENTS.md`: when to run the suite, and the flow-step rule.
- The app's open path and behavior are unchanged; with `PEEKER_RECOVERY` unset, recovery copies go where they go today.
