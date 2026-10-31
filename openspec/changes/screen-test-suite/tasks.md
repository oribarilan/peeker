# Tasks

## 1. Recovery copies kept apart

- [x] 1.1 Have `RecoveryStore.shared` use `$PEEKER_RECOVERY` when set and non-empty; verify with a test that a store built from an environment with the variable writes and reads records in that folder, and one without it uses the default path
- [x] 1.2 Mention `PEEKER_RECOVERY` next to `PEEKER_CONFIG` in the run-peeker skill; verify `openspec validate --all --strict` passes with the delta spec

## 2. Unit tests in place of hand checks

- [x] 2.1 Test Reopen: a stub plugin that fails its first open and succeeds after, loaded in an off-screen window; clicking the failure view's Reopen button shows the document; verify the test fails if the button's action is removed, then passes
- [x] 2.2 Test the animation click: a synthesized mouse-down on the canvas outside Edit mode pauses the player and a second resumes it; in Edit mode a click doesn't pause; verify with `scripts/build.sh test`

## 3. Scripts move and share a preamble

- [x] 3.1 Move `drive.swift`, `pdf-tool.swift`, `e2e-routing.sh`, `record-flows.sh` and `pdf-edit-flow.sh` to `scripts/screen/` with `git mv`, fix their paths, and update the run-peeker skill and `docs/screenontest.md`; verify `grep -rn "skills/run-peeker/.*\.\(sh\|swift\)"` finds nothing outside history, and `e2e-routing.sh` passes from its new place
- [x] 3.2 Add `scripts/screen/common.sh` (tools, evidence folder, `check`, the locked-screen and other-Peeker guard, `launch` with `PEEKER_CONFIG` and `PEEKER_RECOVERY`, optional recording, the cleanup trap quitting `$APP` by path) and have both flows source it; verify `bash -n` on every script, and that a flow refuses to start with a message while another copy of Peeker runs

## 4. Waiting on state

- [x] 4.1 Add `drive wait <process> <window|sheet|menu|control> [label] [--gone] [--timeout s]` and list it in `drive.swift`'s usage header; verify by hand: it returns at once for an open window, waits for a Settings window to appear, times out with a message for a label that never shows, and `--gone` returns when a sheet closes
- [x] 4.2 Replace the fixed sleeps after launches, menu commands that open something, sheets, Settings and the Space panel in both flows with `drive wait`; verify both flows pass, run on their own

## 5. The suite

- [x] 5.1 Add `scripts/screen-test.sh [--record] [--no-build] [flow…]`: build, one run folder, routing then each flow without stopping, a summary table in the terminal and `summary.txt`, non-zero exit on any FAIL or unfinished flow; verify a full run passes and a run with a deliberately broken check reports that flow as failed and exits non-zero
- [x] 5.2 Add the recorder steps to `record-flows.sh` (only the last recorder pressed listens, ⌥⌘Z reaches its command, Space opens the panel after recording, switching to Finder stops a recorder); verify they pass in a suite run
- [x] 5.3 Check `--record`: a recorded run saves each flow's video, and an unrecorded one finishes without waiting on a recording; verify by timing both and listing the evidence folders

## 6. Rule and docs

- [x] 6.1 Add a "Screen tests" section to `AGENTS.md` (needs, when to run, the maintainer's go, the flow-step rule) and point the run-peeker skill at `scripts/screen-test.sh`; verify the commands it names run as written
- [x] 6.2 Run `scripts/build.sh test`, `scripts/check-plugin-imports.sh` and `openspec validate --all --strict`; verify all pass with no warnings

## Workflow follow-up

- Change 2: flows for PDF page edits (with the thumbnail drag), image editing and crash recovery, then delete `docs/screenontest.md` and note the aborted-run check in the run-peeker skill.
- Archive this change with `/opsx:archive` once its tasks are done.
