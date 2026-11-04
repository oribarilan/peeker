# Tasks

## 1. Config

- [x] 1.1 Write failing tests in `Tests/ConfigTests.swift` and `Tests/ConfigSchemaTests.swift`: no file gives `automatic` `"check"` and `showWhatsNew` true; `"off"`, `"download"` and `false` read through; `"daily"` and a non-bool `showWhatsNew` are problems at `updates.automatic` and `updates.showWhatsNew`; `{"updates": {"check": false}}` is an unknown key and leaves the default; rendering writes both keys; the schema lists both with their defaults.
- [x] 1.2 Replace `checkForUpdates` in `Config.swift`, `ConfigRendering.swift` and `ConfigSchema.swift` with `automaticUpdates` (one of `Config.automaticUpdateModes`) and `showWhatsNew`; fix the callers so it builds. Verify the 1.1 tests pass.

## 2. Updater modes and the reminder

- [x] 2.1 Write failing tests in `Tests/UpdaterTests.swift`: each mode maps to the two Sparkle settings (`off` → no checks, no downloads; `check` → checks only; `download` → both); `shouldShowScheduledUpdate` is true only while the app is active; a background update calls `onUpdateAvailable` with its version and the clearing callbacks call it with nil.
- [x] 2.2 Implement them in `Updater`: apply both settings from the config, pass `self` as the user driver delegate with gentle reminders on, and expose `onUpdateAvailable`. Remove `SUAllowsAutomaticUpdates` from `project.yml`. Verify the 2.1 tests pass and `scripts/build.sh` builds without warnings.

## 3. Menu bar

- [x] 3.1 Write failing tests for `MenuBarItem.State`: an update alone gives an indigo dot and the line "Update to 0.3.0…" first in the menu; with a config problem or missing Accessibility the dot is red and both lines show; no update and no problems hides the dot; the accessibility label mentions the update.
- [x] 3.2 Add `updateVersion` and the dot color to `State`, the update line to the menu (action `checkForUpdates(_:)`), and wire `updater.onUpdateAvailable` into `AppDelegate.updateMenuBar()`. Verify the 3.1 tests pass.

## 4. Quiet installs

- [x] 4.1 Write failing tests: with an install pending, `installIfIdle()` runs the install block only when `isIdle` says so; returning from `willInstallUpdateOnQuit` is true and installs at once when already idle; installing records the quiet-install mark in the given `UserDefaults`; nothing runs without a pending block.
- [x] 4.2 Implement them in `Updater` as its updater delegate, and in `AppDelegate` set `isIdle` (no Editor windows, no Settings window, Peek panel hidden) and call `installIfIdle()` when an Editor window closes, Settings closes and the Peek panel dismisses. Verify the 4.1 tests pass.

## 5. What's new

- [x] 5.1 Write failing tests for a `Changelog` reader: from a sample changelog with Unreleased, 0.4.0, 0.3.0 and 0.2.0, the notes after 0.2.0 up to 0.4.0 are 0.4.0 then 0.3.0; versions compare as numbers (0.10.0 after 0.9.0); a missing version is skipped; Unreleased is never shown; an empty result for a range with no sections.
- [x] 5.2 Write failing tests for the launch decision: no last version → nothing; same or older → nothing; `-dev` → nothing; `showWhatsNew` false → nothing; newer after a user install or a launch by hand → show now; newer after a quiet install or at login → show with the first window. And for `showsSettingsAtLaunch`: false after an update relaunch or a quiet install.
- [x] 5.3 Implement the reader and the decision, bundle `CHANGELOG.md` as an app resource in `project.yml`, record `lastRunVersion` at launch, set the relaunch mark in `updaterWillRelaunchApplication`, and extend `showsSettingsAtLaunch`. Verify the 5.1 and 5.2 tests pass and the built app contains `CHANGELOG.md`.
- [x] 5.4 Write a failing test that the what's-new window's title is "Updated to Peeker 0.4.0" and it lists 0.4.0 before 0.3.0 with a Done button that closes it; then build it (SwiftUI in an `NSWindow`, inline Markdown per line, scroll height capped) and show it from `AppDelegate` at launch or with the first Editor or Settings window, once. Verify the test passes.

## 6. Settings

- [x] 6.1 Write failing tests in `Tests/SettingsLogicTests.swift`: picking each Automatic updates choice writes `updates.automatic`; clearing "Show what's new after updating" writes `"showWhatsNew": false`.
- [x] 6.2 Replace the checkbox in `GeneralPane.swift` with the pop-up (Off, Check and Ask, Download and Install) and add the checkbox, backed by `SettingsModel`; update the footer text to match the mode. Verify the 6.1 tests pass.

## 7. Docs, screen flow, checks

- [x] 7.1 Update README's config section (`updates.automatic`, `updates.showWhatsNew`), add a CHANGELOG line under Unreleased, and replace `updates.check` in `scripts/screen/record-flows.sh` and any other script; verify `grep -rn "updates.check\|checkForUpdates" Sources Tests scripts README.md` finds nothing stale.
- [x] 7.2 Add a screen-flow step in `scripts/screen/record-flows.sh` that picks Download and Install in Settings > General and checks the config, and one that the menu bar menu has no update line; verify with `bash -n`, and run the flow once the maintainer gives the go.
- [x] 7.3 Add to `.local/screen-queue.md`: an end-to-end update against a local feed signed with a throwaway key (gentle reminder while another app is active, download mode's quiet relaunch, the what's-new window), and the 7.2 flow.
- [x] 7.4 Run `scripts/build.sh test` and `openspec validate --all --strict`; verify both pass with no new warnings.

## Workflow follow-up

- Commit the change, then bump `MARKETING_VERSION` in `project.yml` to 0.10.0-dev in its own commit, both only when the maintainer asks.
- Archive the change with `/opsx:archive` after the screen checks.
