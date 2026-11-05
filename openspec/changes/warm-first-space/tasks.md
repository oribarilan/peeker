# Tasks

## 1. Warm-up

- [x] 1.1 Add `HotkeyMonitor.warmUp()` and `AppDelegate.warmUpPeekPanel()`, run a second after launch: make the panel, warm Accessibility, and ask Finder for its selection only when `finderStatus(asking: false)` is granted; verify `scripts/build.sh test` passes without warnings.
- [x] 1.2 Let `bench/spacebench.swift` print the warm-up press with `SPACEBENCH_FIRST=1`.

## 2. Checks

- [x] 2.1 Relaunch the app five times and time the first Space with `SPACEBENCH_FIRST=1 build/bench-tools/spacebench bench/fixtures/small.md 1`, before and after; verify the median first press is under 60 ms. (2026-11-04: before 90-100 ms; after 40-49 ms, one run 80 ms; second presses 17-34 ms. Showing the panel off screen at zero opacity as well didn't help, so it's not in.)
- [x] 2.2 Run the `flows` screen test; verify nothing changes beyond the known Option-Space failures.
- [x] 2.3 Add a CHANGELOG line under Unreleased and verify `openspec validate --all --strict`.

## Workflow follow-up

- Commit the change, then bump the patch version in its own commit, both when the maintainer asks; archive.
