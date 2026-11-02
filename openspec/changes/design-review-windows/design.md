# Design

## Context

`DocumentWindowController.rebuildToolbar()` makes a new `NSToolbar` each time the document's commands change, with identifiers `[toggleSidebar?, openWith, edit?, flexibleSpace, command.N…]`, where `DocumentViewController.showsInToolbar` drops edit tools outside Edit mode. All commands land in one run, so the system draws them on one piece of glass (W3), and since the menus change added the sidebar button, a PDF in Edit mode (11 items) overflows at the default 960-point width.

When a file opens, `DocumentViewController.show(_:)` calls `setCommands`, which fires `onCommandsChanged`, and the window rebuilds its toolbar in the same main-actor turn, before `markReady` paints. The 2026-11-02 benchmarks (15 launches, interleaved) put that rebuild at about 5 ms per open for plugins with commands, whatever the extra item was; Markdown, whose commands don't change on open, wasn't affected. `onReady` belongs to the benchmark (`BenchRunner` sets it through `onDocument`), so the window can't hook it.

The window (`init`) sets a frame autosave name but no `contentMinSize` (W4) and isn't restorable (W5). `AppDelegate.applicationDidFinishLaunching` restores crash-recovery records, then opens Settings when `showsSettingsAtLaunch(openedWindows:atLogin:)` says so; `launchedAtLogin` comes from the launch Apple event. `openInWindow` brings an existing window for the same URL forward instead of opening another, which would silently skip a recovery record if a restored window got there first.

The no-plugin alert in `openInWindow` (W6) and `DocumentWindowController.report`, `showMessage` and `save` (W7) put whole sentences in `messageText`.

## Goals / Non-Goals

**Goals:**
- W3 to W7 and the toolbar timing as this change's specs describe.
- No new work in the timed part of an open; the toolbar build leaves it.

**Non-Goals:**
- Restoring Edit mode, zoom or scroll position (the maintainer chose file, plugin, frame and tabs).
- Restoring the Settings window or the Peek panel.
- The Peek panel's speed against Quick Look (stays in the backlog).
- Customizable toolbars.

## Decisions

**Menu-only commands are a flag on the command.** `CommandSpec` gains `showsInToolbar: Bool` (default true) in its initializer; `DocumentViewController.showsInToolbar` also requires it. Image marks Zoom In, Zoom Out, Zoom to Fit and Actual Size; PDF and text mark Zoom In and Zoom Out. The host still knows no formats: it never looks at ids or shortcuts. The menus are unchanged, since View lists every command that isn't an edit tool.

**Two groups, separated by a space.** `toolbarDefaultItemIdentifiers` returns `[toggleSidebar?, openWith, edit?, flexibleSpace] + view commands + (both groups non-empty ? [.space] : []) + edit tools`. A `.space` between runs is what makes the system draw them on separate glass; it's the review's suggested fix and needs nothing else.

**The command buttons wait for the first paint.** `DocumentViewController` gains `onContentShown`, called once from `markReady` right after `onReady` (so the benchmark's timing has already been taken). In `show(with:)` the window builds its first toolbar without commands, as today. When `onCommandsChanged` arrives before the document has shown its content, the window notes it and rebuilds when `onContentShown` fires; after that, commands changes rebuild at once as today (Edit mode, reloads, replacements). The sidebar button and Open With are in the first toolbar, so only command buttons arrive a frame later.

**Minimum size.** `window.contentMinSize = NSSize(width: 480, height: 320)` in `init`.

**Restoration through AppKit, with a bookmark and the plugin id.** The document window sets `isRestorable = true`, `identifier = "document"` and `restorationClass = DocumentWindowRestoration.self`. `DocumentWindowController.encodeRestorableState(with:)` stores a bookmark to the file (`url.bookmarkData()`) and the current plugin id; `invalidateRestorableState()` is called after each `show(with:)` so a switch through Open With is kept. `DocumentWindowRestoration.restoreWindow(withIdentifier:state:completionHandler:)` resolves the bookmark (which follows moves and renames), and hands the URL and plugin id to `AppDelegate.restoreWindow(_:pluginID:)`, which returns the new window controller's window or nil. It gives nil, so AppKit restores nothing for that window, when:
- Peeker launched at login (the app delegate also answers `application(_:shouldRestoreSecureApplicationState:)` with false then, so AppKit doesn't try; the per-window check covers a race);
- the bookmark doesn't resolve or the file is gone;
- a crash-recovery record exists for the file: recovery reopens it with its edits, and a restored window would make `openInWindow` skip the record.
The plugin is the recorded one if it's still enabled, else the file's owner, as recovery already does (`plugin(for:restoring:)`). The app delegate returns true from `applicationSupportsSecureRestorableState`. AppKit restores windows before `applicationDidFinishLaunching`, so `showsSettingsAtLaunch` already counts them and Settings stays closed; frames and tab groups come back through AppKit. The system's "Close windows when quitting" setting makes AppKit skip restoration on its own.

**The no-plugin alert opens Settings.** In `openInWindow`, the alert's title is "No enabled plugin opens “name”", its message "Add its extension to a plugin in Settings, or turn on the plugin that has it.", buttons Open Settings and OK. `AppDelegate.settingsPane(forUnopenable:)` (a pure function over the catalog and config, so it's testable) picks the first turned-off plugin whose effective list has the extension, else `text`; Open Settings calls `showSettings` and selects that pane.

**Alert titles.** `showMessage(_ title:, _ detail:)` sets both. Recovery notices: "Recovered edits for “name”" with the existing sentences as detail; save failures: "Couldn't save “name”" with the plugin's message as detail. The overwrite and recreate confirmations already have a title and detail and stay.

**Screen tests.** pdf-pages presses Rotate Right and Delete Page in the toolbar again (the Tools workaround goes) and checks the toolbar has no Zoom In button. A new step in the flows run opens `notes.md` and `photo.png`, switches `notes.md` to Plain Text, quits with Cmd+Q, relaunches with the same throwaway config and checks both windows and the plugin; the run first sets the domain's `NSQuitAlwaysKeepsWindows` to true for the build under test so the system setting doesn't skip it, and restores the user's value with the other preferences (`common.sh`). The no-plugin step opens `movie.mp4`, presses Open Settings and checks the Plain Text pane shows. The viewer flow shrinks a window with System Events and checks its size stops at the minimum.

## Risks / Trade-offs

- [Command buttons appear one frame after the content.] → Accepted by the maintainer for the ~5 ms; the toolbar's first items (sidebar, Open With, Edit) don't move.
- [AppKit restores windows before `applicationDidFinishLaunching` — if it ever runs after, Settings could open beside restored windows.] → A screen step relaunches and checks Settings stays closed.
- [The restored tabs and frames come from AppKit's own state, which the tests can't easily inspect.] → The screen step checks windows come back; tabs are checked by eye in its screenshot.
- [Restoration state from a build before this change.] → None exists (windows weren't restorable), so nothing to migrate.
- [Writing `NSQuitAlwaysKeepsWindows` in the shared preferences domain from a screen run.] → It's saved and restored with the sidebar and Settings keys, so the user's value comes back.
