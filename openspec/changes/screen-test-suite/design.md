# Design

## Context

Today `.claude/skills/run-peeker/` holds `drive.swift` (Accessibility and window helpers, one command per run), `pdf-tool.swift` (makes and inspects a form PDF), `e2e-routing.sh` (benchmark-mode routing check, no screen needed) and two flow scripts. Each flow compiles the tools, makes its fixtures and a throwaway config under `build/evidence/<time>/`, launches the app with `open --env PEEKER_CONFIG=…`, drives it with `drive`, writes `ok`/`FAIL` lines to `results.txt`, and cleans up in an EXIT trap. The preamble (tool build, lock check, `check()`, the cleanup trap) is copied in both flows. Waits are fixed sleeps. Both flows quit any app named Peeker, and the recovery store is always `~/Library/Application Support/<bundle id>/Recovery/`.

## Goals / Non-Goals

**Goals:**
- Any flow fails the same way every run for the same bug, and passes otherwise.
- One command for the whole suite, with one summary.
- Adding a flow (change 2 adds three) means writing only its steps.

**Non-Goals:**
- Replacing `drive.swift` with XCUITest or another framework.
- Making the suite run without Accessibility and Screen Recording for the terminal.
- Changing how the existing flows check things, beyond waits and the recorder steps.

## Decisions

**Layout.** Everything moves to `scripts/screen/`: `drive.swift`, `pdf-tool.swift`, `e2e-routing.sh`, `record-flows.sh`, `pdf-edit-flow.sh`, and a new `common.sh` that flows source. The runner is `scripts/screen-test.sh`, next to `build.sh`. The run-peeker skill keeps its how-to and points here. Considered: leaving the scripts in the skill folder. They are the project's UI tests and people run them too, so they belong with the other scripts.

**`common.sh` holds the shared preamble.** Change 2 brings three more flows, so the copied preamble would reach five copies. It provides:
- `APP`, `TOOLS`, `DRIVE`, `PDF` and building the two tools once per run, skipped when the binaries are newer than their sources.
- The flow's evidence folder: `$SCREEN_RUN/<flow>/` when the runner set `SCREEN_RUN`, else `build/evidence/<flow>-<time>/`, so a flow still runs on its own.
- `check name got want`, writing to `results.txt` as today.
- The guard: stop with exit 2 when the screen is locked, or when a Peeker runs whose executable isn't `$APP/Contents/MacOS/Peeker`.
- `launch [file]`: `open --env PEEKER_CONFIG=… --env PEEKER_RECOVERY=<evidence>/recovery -a "$APP"`, then `drive wait` for the window.
- Optional recording: when `SCREEN_RECORD=1`, start `screencapture` and, on a normal end, wait for its time limit (it can't stop early and keep the file, as found on 2026-10-31).
- The cleanup trap from `1fc76dd`, but quitting `"$APP"` by path instead of "Peeker" by name, so it can never address another copy.

**Runner.** `screen-test.sh [--record] [flow…]`:
1. Runs `scripts/build.sh` unless `--no-build`, so the suite tests the tree as it is.
2. Makes `build/evidence/run-<time>/` and exports `SCREEN_RUN` (and `SCREEN_RECORD`).
3. Runs `e2e-routing.sh`, then each flow in a fixed order (all, or the ones named), never stopping early.
4. Prints a table: flow, ok count, FAIL count, and "didn't finish" when a flow exited non-zero without FAIL lines (a guard stop, a crash in the script). Writes the same table to `summary.txt`.
5. Exits 0 only when every flow finished and no check failed.

Routing writes its own pass/fail lines; the runner reads its exit code and counts its lines.

**`drive wait`.** `drive wait <process> <kind> [label] [--gone] [--timeout seconds]`, with kinds `window` (a window whose title contains the label, or any window), `sheet`, `menu` and `control` (a button, checkbox or field with that label or placeholder, as `press` and `fill` find them). It polls every 50 ms inside one process, up to the timeout (default 5 s), and exits 1 with what it waited for when time runs out, so the flow fails at the wait, not three steps later. Menus are found as the process's windows at the pop-up menu level (101); the others through Accessibility. `drive menu` keeps its built-in wait for the menu to close. Considered: bash loops around existing commands. They relaunch `drive` and rewalk the tree each time, and every flow would repeat the loop.

Flows use `drive wait` after a launch, a menu command that opens something, a sheet, Settings, a window opening or closing, and the Space panel. Sleeps that only let a click or keystroke settle (≤0.5 s) stay.

**Which Peeker is ours.** A Peeker process is the build under test when its executable path is `$APP/Contents/MacOS/Peeker` (`pgrep -f` on that path). `common.sh` refuses to start if any other process named Peeker runs, and quits with `osascript -e 'tell application "<path>" to quit'`. `drive` addresses processes by name, which is safe because only ours runs.

**`PEEKER_RECOVERY`.** `RecoveryStore.shared` uses the environment variable's path when set and non-empty, else today's folder. The store already creates its folder with mode 0700 and validates record ids and files, so nothing else changes. The value comes from the user's own environment, like `PEEKER_CONFIG`. `open --env` applies only when the app launches, which is how the flows start it.

**Unit tests instead of screen checks.**
- Reopen: a stub plugin whose open fails once and then succeeds; load a `DocumentViewController` in an off-screen window, find the Reopen button in the failure view, `performClick`, and wait for the document.
- Animation click: open the test GIF, send the canvas a synthesized mouse-down outside Edit mode, and check the player paused; a second one resumes it. A click in Edit mode doesn't pause.

**Recorder steps.** `record-flows.sh`'s Settings section gains the steps from today's hand check: two recorders pressed, only the second listens; ⌥⌘Z goes to its command in `config.json`; Space in Finder opens the panel after recording; a recorder stops listening when Finder comes to the front.

**AGENTS.md.** A short "Screen tests" section under Build and test: what `scripts/screen-test.sh` needs (unlocked screen, permissions), when to run it (before a release, after changes to the host UI or a plugin's views), that agents ask for the maintainer's go first, and the rule that a user-facing change adds or updates a flow step or says why not in its commit or PR.

## Found while applying

- **Modifier keys stuck after `drive keys`.** A combo set its modifiers only on its own key events and never released them, so the system kept treating them as held, and later typing arrived as shortcuts. That was the PDF flow's intermittent lost typing. `drive keys` now releases the modifiers, and typing, clicks and drags send none (`917f492`).
- **`drive focus`** prints the front app, key window and focused element. It was added to find the bug above, and the PDF flow saves its output around the Name-field click.

## Risks / Trade-offs

- [Moved paths break references] → Update the skill, `docs/screenontest.md` (until change 2 deletes it) and anything `grep` finds; the review report keeps its historical paths.
- [Refusing to run while the user's Peeker is open is a small chore] → The message says which copy is running and to quit it; the user's windows are never touched.
- [A wait timeout too short on a slow or busy Mac] → 5 s default with a per-call override; a timeout names what it waited for, so it reads as a failure to investigate, not a flaky pass.
- [`drive wait` by window title depends on the title format] → Match on a substring (the file name), not the full "name – Plugin" title.
- [Without video, a failure has less evidence] → Screenshots stay at each step; `--record` reruns with video when needed.

## Migration Plan

Nothing for users: with `PEEKER_RECOVERY` unset the app behaves as before. Old evidence folders stay where they are. Rollback is reverting the change.
