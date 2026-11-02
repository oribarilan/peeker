# Design

## Context

`DocumentWindowController.rebuildToolbar()` makes a new `NSToolbar` each time the document's commands change, with identifiers `[toggleSidebar?, openWith, edit?, flexibleSpace, command.N…]`, where `DocumentViewController.showsInToolbar` drops edit tools outside Edit mode. All commands land in one run, so the system draws them on one piece of glass (W3), and since the menus change added the sidebar button, a PDF in Edit mode (11 items) overflows at the default 960-point width.

When a file opens, `DocumentViewController.show(_:)` calls `setCommands`, which fires `onCommandsChanged`, and the window rebuilds its toolbar in the same main-actor turn, before `markReady` paints. The 2026-11-02 benchmarks (15 launches, interleaved) put that rebuild at about 5 ms per open for plugins with commands, whatever the extra item was; Markdown, whose commands don't change on open, wasn't affected. `onReady` belongs to the benchmark (`BenchRunner` sets it through `onDocument`), so the window can't hook it.

The window (`init`) sets a frame autosave name but no `contentMinSize` (W4). W5 (windows coming back after a relaunch) was planned through AppKit's window restoration and dropped during apply: Peeker is a menu bar app (`LSUIElement`), and macOS saved no window state for it even with "keep windows" forced on. The maintainer chose to drop W5 rather than have Peeker save its own.

The no-plugin alert in `openInWindow` (W6) and `DocumentWindowController.report`, `showMessage` and `save` (W7) put whole sentences in `messageText`.

## Goals / Non-Goals

**Goals:**
- W3, W4, W6, W7 and the toolbar timing as this change's specs describe.
- No new work in the timed part of an open; the toolbar build leaves it.

**Non-Goals:**
- W5, restoring windows after a relaunch (dropped, see Context).
- The Peek panel's speed against Quick Look (stays in the backlog).
- Customizable toolbars.

## Decisions

**Menu-only commands are a flag on the command.** `CommandSpec` gains `showsInToolbar: Bool` (default true) in its initializer; `DocumentViewController.showsInToolbar` also requires it. Image marks Zoom In, Zoom Out, Zoom to Fit and Actual Size; PDF and text mark Zoom In and Zoom Out. The host still knows no formats: it never looks at ids or shortcuts. The menus are unchanged, since View lists every command that isn't an edit tool.

**Two groups, separated by a space.** `toolbarDefaultItemIdentifiers` returns `[toggleSidebar?, openWith, edit?, flexibleSpace] + view commands + (both groups non-empty ? [.space] : []) + edit tools`. A `.space` between runs is what makes the system draw them on separate glass; it's the review's suggested fix and needs nothing else.

**The command buttons wait for the first paint.** `DocumentViewController` gains `onContentShown`, called once from `markReady` right after `onReady` (so the benchmark's timing has already been taken). In `show(with:)` the window builds its first toolbar without commands, as today. When `onCommandsChanged` arrives before the document has shown its content, the window notes it and rebuilds when `onContentShown` fires; after that, commands changes rebuild at once as today (Edit mode, reloads, replacements). The sidebar button and Open With are in the first toolbar, so only command buttons arrive a frame later.

**Minimum size.** `window.contentMinSize = NSSize(width: 480, height: 320)` in `init`.

**The no-plugin alert opens Settings.** In `openInWindow`, the alert's title is "No enabled plugin opens “name”", its message "Add its extension to a plugin in Settings, or turn on the plugin that has it.", buttons Open Settings and OK. `AppDelegate.settingsPane(forUnopenable:)` (a pure function over the catalog and config, so it's testable) picks the first turned-off plugin whose effective list has the extension, else `text`; Open Settings calls `showSettings` and selects that pane.

**Alert titles.** `showMessage(_ title:, _ detail:)` sets both. Recovery notices: "Recovered edits for “name”" with the existing sentences as detail; save failures: "Couldn't save “name”" with the plugin's message as detail. The overwrite and recreate confirmations already have a title and detail and stay.

**Screen tests.** pdf-pages presses Rotate Right and Delete Page in the toolbar again (the Tools workaround goes) and checks the toolbar has no Zoom In button. The no-plugin step opens `movie.mp4`, presses Open Settings and checks the Plain Text pane shows. The viewer flow shrinks a window with System Events and checks its size stops at the minimum.

## Risks / Trade-offs

- [Command buttons appear one frame after the content.] → Accepted by the maintainer for the ~5 ms; the toolbar's first items (sidebar, Open With, Edit) don't move.
