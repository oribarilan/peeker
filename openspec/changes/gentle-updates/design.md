# Design

## Context

`Updater` wraps `SPUStandardUpdaterController` with no delegates. It sets `automaticallyChecksForUpdates` from the config on every apply, never starts in a `-dev` build, and `checkNow()` calls `checkForUpdates`. `Info.plist` sets `SUAllowsAutomaticUpdates: false`, which makes Sparkle refuse `automaticallyDownloadsUpdates` whatever it's set to. `MenuBarItem` has one red dot layer and two hidden status lines above the commands, driven by `MenuBarItem.State`. `AppDelegate` knows the windows (`windows`, `settings`, `panel`), whether this launch came at login (`launchedAtLogin`), and shows Settings at launch when nothing opened and the launch wasn't at login. Nothing has been released, so `CHANGELOG.md` has only Unreleased, and no user has a config with `updates.check` that came from a release.

Sparkle 2.10.1 offers what the decisions need:

- Gentle reminders: `supportsGentleScheduledUpdateReminders`, `standardUserDriverShouldHandleShowingScheduledUpdate(_:andInImmediateFocus:)`, `standardUserDriverWillHandleShowingUpdate(_:forUpdate:state:)`, and `standardUserDriverDidReceiveUserAttention(forUpdate:)` and `standardUserDriverWillFinishUpdateSession()` to clear the reminder.
- `checkForUpdates()` brings an update already found to the front, so the menu item reuses it.
- Install on quit: with `automaticallyDownloadsUpdates`, a scheduled check downloads and calls `updater(_:willInstallUpdateOnQuit:immediateInstallationBlock:)`. Returning true stops further cycles, and calling the block installs and relaunches with no UI.
- `updaterWillRelaunchApplication(_:)` runs before any update relaunch.

## Goals / Non-Goals

**Goals:**
- Keep Sparkle's own windows, signature checks and install path; Peeker only decides when to show things.
- Keep the logic testable without Sparkle: timing and parsing live in small value types and static functions.

**Non-Goals:**
- A custom update window, or release notes fetched from the web.
- Delta updates, beta channels, or any change to the feed or signing.
- Showing a reminder in the Peek panel or in Editor windows.

## Decisions

**`updates.automatic` is an enum in `Config`, mapped onto two Sparkle settings.** `off` sets `automaticallyChecksForUpdates = false`; `check` sets it true with `automaticallyDownloadsUpdates = false`; `download` sets both true. The config stays the only store, as today: `apply` writes both every time. `updates.check` becomes an unknown key with no migration, because nothing released ever wrote it. Removing `SUAllowsAutomaticUpdates` from `project.yml` lets Sparkle accept automatic downloads; with checks on, Sparkle allows the option by default. Considered keeping `check` as a bool next to a new `autoInstall` bool: two keys that can contradict each other (`check: false, autoInstall: true`).

**The reminder is decided by whether Peeker is active.** `Updater` becomes the user driver delegate. `standardUserDriverShouldHandleShowingScheduledUpdate` returns `NSApp.isActive`, so Sparkle shows its window only when Peeker is in front. `standardUserDriverWillHandleShowingUpdate(false, …)` calls `onUpdateAvailable(version)`, and the two clearing callbacks call `onUpdateAvailable(nil)`. `AppDelegate` feeds that into `MenuBarItem.State`. Ignoring `immediateFocus` is deliberate: for a background app Sparkle's "not immediate" path is the alert behind other windows, which is what we're avoiding.

**`MenuBarItem.State` gains `updateVersion: String?` and the dot gets a color.** The dot is red when there are problems or a missing permission, indigo (the app's accent color asset) when only an update waits, hidden otherwise. A new line, "Update to 0.3.0…", sits first in the menu and calls `AppDelegate.checkForUpdates(_:)`, which already brings Sparkle's window forward. The accessibility label adds "update available".

**Quiet installs wait for an idle moment the app delegate defines.** `Updater` keeps the install block from `willInstallUpdateOnQuit` (returning true) and asks `isIdle: () -> Bool`, which `AppDelegate` sets to "no Editor windows, no Settings window, Peek panel not visible". Unsaved edits always live in an Editor window, so no window means no edits. If idle, it installs at once; otherwise `AppDelegate` calls `updater.installIfIdle()` when an Editor window closes, Settings closes or the Peek panel dismisses. Quit installs anyway, by Sparkle's own on-quit path. Before calling the block, `Updater` records a quiet-install mark in `UserDefaults`.

**What's new is decided at launch from three facts.** A `WhatsNew` value type takes the last version run (from `UserDefaults`, key `lastRunVersion`), the running version, whether this launch follows a quiet install (the mark, cleared once read) and whether it came at login. It answers: nothing (first run, same or older version, `-dev` build, or `showWhatsNew` false), show now, or show with the first window. `lastRunVersion` is written at every launch after the decision, so the window appears once per update even if the user never opens a window after a quiet install: the next launch sees no newer version. That's a trade-off accepted for simplicity; the notes stay on GitHub.

**An update relaunch doesn't open Settings.** `updaterWillRelaunchApplication` sets a relaunch mark in `UserDefaults`; at launch `showsSettingsAtLaunch` also returns false when the mark (cleared once read) or the quiet-install mark is set. After a user-chosen install the what's-new window takes Settings' place; after a quiet install nothing shows, as the spec requires.

**The notes come from `CHANGELOG.md` bundled in the app.** `project.yml` adds it as a resource of the app target. A `Changelog` reader parses `## [x.y.z] - date` sections and returns the ones after the last version run up to the running one, newest first, comparing versions as numbers. A version missing from the file is skipped; if none remain, nothing is shown. Considered fetching the notes from the feed: a network request on launch, and nothing offline.

**The what's-new window is a small SwiftUI view in an `NSWindow`.** Title "Updated to Peeker 0.3.0", each version's heading and its notes (inline Markdown per bullet through `AttributedString(markdown:)`), a scroll view capped in height, and Done as the default button. It brings Peeker forward but doesn't count toward the Dock icon, like the "No enabled plugin" alert, so `Presence` and its spec stay as they are.

## Risks / Trade-offs

- [The full update flow can't run in unit tests or CI] → the decisions are pure functions with tests; Sparkle callbacks are thin. An end-to-end check against a local feed signed with a throwaway key goes in the screen queue, and the first two real releases are the final check.
- [Gentle reminders depend on Sparkle calling the delegate as documented; Sparkle's documentation describes these calls but doesn't promise their order across versions] → the menu state only follows the callbacks; a missed clear leaves a stale dot until the session ends, which `standardUserDriverWillFinishUpdateSession` covers.
- [Quiet relaunch while the user is about to press Space] → the panel counts as busy while visible; a relaunch takes about a second, during which Space goes to Finder's Quick Look.
- [Someone running a pre-release build with `updates.check` in their config sees an unknown-key problem] → acceptable before the first release; the README documents the new key.

## Migration Plan

No data migration. Rollback is reverting the change; `UserDefaults` keys left behind are harmless.
