# Tasks

## 1. Placement rules

- [x] 1.1 Write failing tests for `PanelPlacement.frame(saved:screen:)` in a new `Tests/PanelPlacementTests.swift`: no saved frame on a 1440 × 2560 visible frame gives 792 × 700 centered; on a 1280 × 800 one gives 704 × 600 centered; on a 600 × 400 one never goes below 400 × 300; a saved frame inside the display comes back as is; a saved frame on another display (outside this one) whose size fits comes back that size, centered; a saved frame bigger than this display gives the default, centered; a saved frame half off this display counts as outside.
- [x] 1.2 Implement `PanelPlacement` in `Sources/Host/PeekPanel/PanelPlacement.swift`, including the default size and the 400 × 300 minimum as constants; verify the 1.1 tests pass.

## 2. The panel

- [x] 2.1 Write failing tests in `Tests/PeekPanelTests.swift` with a throwaway `UserDefaults` suite: a new panel's `contentMinSize` is 400 × 300; a frame set as if the user resized it (through the panel's move/resize handling) is saved under `peekPanelFrame`; the panel setting its own frame saves nothing; a second panel made with the same defaults places itself at the saved frame on show (screen permitting); `resetFrame()` removes the key and gives the default frame.
- [x] 2.2 Implement them in `PeekPanel`: `init(defaults:)` (default `.standard`), the minimum size, saving on user moves and resizes only, placing the panel through `PanelPlacement` with the pointer's display in `show(_:)` when it isn't visible (keeping the frame while it is), and `resetFrame()`. Update the existing `PeekPanel()` uses in tests to pass a throwaway suite. Verify the 2.1 tests and the existing panel tests pass.

## 3. Settings

- [x] 3.1 Write failing tests in `Tests/SettingsLogicTests.swift`: `hasSavedPeekPanelFrame` is false with no `peekPanelFrame` in the model's defaults and true with one; `resetPeekPanelFrame()` calls the reset closure.
- [x] 3.2 Add `hasSavedPeekPanelFrame`, the `resetPeekPanel` closure and `resetPeekPanelFrame()` to `SettingsModel`, and a Reset Panel Size button under the key in `GeneralPane`'s Peek panel section, enabled from `@AppStorage("peekPanelFrame")` on the model's defaults; wire the closure in `AppDelegate.makeSettings()` to the panel only when it has been made, else to removing the key. Verify the 3.1 tests pass and `scripts/build.sh` builds without warnings.

## 4. Screen tests and docs

- [x] 4.1 Add `peekPanelFrame` to `PREF_KEYS` in `scripts/screen/common.sh`, so a run starts from the default frame and puts the user's back.
- [x] 4.2 Add a step to `scripts/screen/record-flows.sh`: the first Space opens a panel no larger than 900 × 700 points; moving it with System Events and pressing Space again opens it at the moved spot; Settings' Reset Panel Size is enabled, and after a click it greys out and the next Space opens the default frame again. Verify with `bash -n`, and run the flow once the maintainer gives the go.
- [x] 4.3 Add a CHANGELOG line under Unreleased, drop the P1 line from `openspec/backlog.md`, and verify `openspec validate --all --strict` passes.

## 5. Checks

- [x] 5.1 Run `scripts/build.sh test`; verify everything passes with no new warnings.
- [x] 5.2 After the maintainer's go, run `bench/ppbench.py space --runs 9` and verify Peeker is still faster than Quick Look on every file, comparing with the 2026-11-04 table. (Ran 2026-11-04: faster on 9 files, about the same on 3; flows screen test passed its six panel checks.)

## Workflow follow-up

- Commit the change, then bump `MARKETING_VERSION` in `project.yml` to 0.11.0-dev in its own commit, both only when the maintainer asks.
- Mark P1 fixed in `docs/design-review-2026-11-01.md` with the commit hash.
- Archive the change with `/opsx:archive`.
