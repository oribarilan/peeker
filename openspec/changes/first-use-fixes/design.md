# Design

## Context

**Highlight.** `PDFPluginDocument.perform("highlight")` covers each line of `pdfView.currentSelection` and does nothing without one. In Edit mode `PeekerPDFView` offers each mouse event to `EditController` first (Text Box placement, signatures, selecting marks); a drag no tool takes goes to PDFKit, which selects text, so selecting text already works in Edit mode. `EditController.end()` runs when Edit mode turns off.

**Shortcuts.** `Config.keys` maps `plugin.command` to a `Shortcut`; `Config.shortcut(for:of:)` falls back to the command's default. `ConfigReader.readCommands` parses `shortcut` and refuses anything else; `ConfigRendering` writes each command's effective shortcut and leaves out commands without one. The main menu and the window's command matching both ask `shortcut(for:of:)`. `PluginPane` shows each command with a `KeyRecorder` and a Reset button.

**Launch.** `applicationDidFinishLaunching` restores recovered documents and opens the files passed in, and shows nothing else; nothing handles reopening. Login launches come from the Open at Login item (`LoginItem`, `SMAppService`). `record-flows.sh` launches Peeker with no file.

## Goals / Non-Goals

**Goals:**
- Each part tested in-process; the shortcut and launch parts also on screen.

**Non-Goals:**
- A pressed state on the toolbar's Highlight button while it's armed: toolbar commands have no state in the plugin contract, and the highlighter lasts one drag.
- Highlight colors, or a highlighter that stays on.

## Decisions

**1. The highlighter lives in `EditController`.** `armHighlighter()` sets a flag; `end()`, Escape, choosing Text Box or Sign clear it. `PeekerPDFView.mouseUp`, after PDFKit has finished the drag, calls `tools?.selectionEnded()`, which, when armed and the selection isn't empty, asks the document to highlight it and disarms. The command becomes: highlight the current selection if there is one, then arm. Highlighting stays the one existing code path (each line, one undo group), now reached from two places. Considered: a drag tracked by the tool itself (duplicates PDFKit's text selection).

**2. A cleared shortcut is a set of command ids.** `Config.noShortcut: Set<String>` (same `plugin.command` keys). `readCommands` accepts `off` into it; recording a shortcut removes the id from it; Reset removes it from both. `shortcut(for:of:)` returns nil for a cleared command, so menus and matching need no change. `ConfigRendering` writes `"off"` for cleared commands, and the schema describes it. Considered: `[String: Shortcut?]` (a double optional at every lookup).

**3. The clear button sits after the recorder.** An ⓧ button (`xmark.circle.fill`, labeled "Clear shortcut") beside each command's recorder, shown while the command has a shortcut; the recorder shows "None" otherwise. Reset stays.

**4. Settings on a hand launch, decided by one function.** `AppDelegate.showsSettingsAtLaunch(openedWindows:, atLogin:)` is true when nothing opened (no file, no recovered document) and the launch wasn't a login launch; benchmark mode never gets here. A login launch is recognized from the launch Apple event, whose `keyAEPropData` is `keyAELaunchedAsLogInItem` for login items; it's read in `applicationWillFinishLaunching`, while that event is current. Reopening (`applicationShouldHandleReopen` with no visible windows) shows Settings. Both decisions get unit tests; the Apple event itself can only be checked by logging in.

**5. The main flow expects Settings.** `record-flows.sh` checks that its launch with no file shows the Settings window, then closes it before the Space checks, and adds a step that clears a shortcut and checks `config.json`. The highlighter's drag stays a unit test: synthetic drags don't select PDF text (found in the PDF editing flow).

## Risks / Trade-offs

- [The login launch isn't recognized, so Settings opens at every login] → The check uses Apple's documented login-item marker; the maintainer confirms at the next login, and the fix would be limited to that function.
- [The armed highlighter isn't visible until used] → It lasts one drag and the result shows at once; a button state can come with toolbar state in the contract.
- [`off` clashes with a key named off] → No key is named off; `Shortcut(parsing:)` never accepted it.
