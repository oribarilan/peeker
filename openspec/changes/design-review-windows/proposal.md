# Proposal

## Why

The design review (`docs/design-review-2026-11-01.md`) found the document windows rough: every plugin command sits on one piece of glass (W3), windows can shrink until nothing fits (W4), open windows don't come back after a relaunch (W5, dropped: see below), the no-plugin alert points at the config file instead of Settings (W6), and recovery and save alerts put whole sentences in their titles (W7). Since the menus change, a PDF in Edit mode also overflows the toolbar at the default width, and the 2026-11-02 benchmarks showed rebuilding the toolbar while a file opens costs about 5 ms per window. This change fixes all of these except W5, the Windows and toolbar theme agreed with the maintainer. W5 is dropped: Peeker is a menu bar app (`LSUIElement`), for which macOS keeps no window state, and the maintainer chose not to build Peeker's own.

## What Changes

- The toolbar puts view commands and edit tools on separate pieces of glass (W3).
- A plugin can keep a command out of the toolbar; every zoom command (Zoom In, Zoom Out, Zoom to Fit, Actual Size) stays in the View menu only, so a PDF in Edit mode fits at the default width.
- A file's command buttons join the toolbar right after its content shows, so building them no longer delays the first paint; Open With, the sidebar button and Edit are there from the start.
- Document windows have a minimum size, about 480 × 320 (W4).
- When no enabled plugin opens a file, the alert points at Settings and offers Open Settings, which shows the pane of a turned-off plugin that lists the extension, or else the Plain Text pane (W6).
- Recovery and save alerts get a short title and the reason as their message (W7).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `plugin-host`: toolbar grouping, commands kept out of the toolbar, command buttons added after the content shows.
- `documents`: a minimum window size.
- `routing-and-config`: the no-plugin alert offers Open Settings.

## Impact

- Host: `Sources/Host/Documents/DocumentWindowController.swift` (toolbar groups, deferred command items, minimum size, alert wording), `DocumentViewController.swift` (telling the window when content is on screen), `Sources/Host/App/AppDelegate.swift` (no-plugin alert with Open Settings).
- Plugin contract: `CommandSpec` gains an option to stay out of the toolbar (`Sources/PeekerKit/Plugin.swift`); the image, PDF and text plugins mark their zoom commands.
- Tests: toolbar identifiers and timing, the alert's pane choice, alert texts, the minimum size.
- Screen flows: pdf-pages presses Rotate Right and Delete Page in the toolbar again; new steps for the no-plugin alert's Open Settings and the minimum size.
- No new dependencies. Opening gets about 5 ms faster for files whose plugin has commands.
