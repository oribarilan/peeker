# Design

## Context

`GridView` (`Plugins/table/TableGridView.swift`) is the table's first responder and handles its keys; Edit > Copy is `copy(_:)` with no target, so it reaches `GridView` through the responder chain, which doesn't implement it today. `TableSelection` holds the selection in shown rows; `TableView.fileRow(_:)` maps a shown row to a file row through the sort order. `CSVTable` quotes edited fields with its `escaped` rule. Plugins remember choices through `PluginPreferences` (`string`, `bool`, `set`), as the PDF plugin does for its highlight color.

The Peek panel is a non-activating `NSPanel`: Finder stays the active app, so keys go to Finder, and `HotkeyMonitor`, an event tap, swallows only the panel's own keys (its shortcut, the button keys, Escape) and passes the arrows on. A click makes the panel key without activating Peeker, so after a click the panel's first responder is the clicked view. The table in the panel is the same `TableView` with editing off, and it shows a selection only after the first click. The panel's Other… already brings Peeker forward for a sheet and gives Finder the keyboard back on Cancel.

## Goals / Non-Goals

**Goals:** copy in both the Editor and the panel through one path; the format code testable without windows; no plugin knowledge in the host.

**Non-Goals:** paste; copying rich text or HTML to the clipboard; copying in the data plugin's tree (a later change can adopt the same panel routing).

## Decisions

- **`TableCopy`, a pure formatter.** `TableCopy.text(rows: [[String]], header: [String]?, format: Format)`, with `Format` being tabs, commas, semicolons and markdown. The separators reuse `CSVTable`'s quoting rule (moved to a static function both use); Markdown escapes `|` as `\|`, turns line breaks into spaces, and writes empty titles when there's no header. `TableView` gathers the cells: the selection's shown rows in order through `fileRow`, and its columns in order. Alternative: serialize a sub-`CSVTable`; it would keep the file's original quoting for unchanged rows, which is right for saving but not for a format the user picked.
- **The sheet is an `NSAlert` with an accessory view**, as the PDF password sheet is: a format pop-up, the header checkbox (only when the header row shows), and a read-only monospaced preview of the first 20 lines, updated as the choices change. Copy is the first button, so Return copies. The choices are stored as `copyFormat` and `copyHeader` in the table's preferences when the user copies. Alternative: a custom sheet window; more code for the same controls.
- **Copy in `GridView`.** `copy(_:)` asks `TableView` to copy, and `validateUserInterfaceItem` enables it while the table shows a selection, editable or not. The right-click menus (rows and titles) get Copy at the top. One cell copies at once; more than one shows the sheet on the table's window.
- **The panel routes Cmd+C by the responder chain.** `HotkeyMonitor.decide` gets a `canCopy` input, asked only for Cmd+C while the panel shows and Finder is in front; a new `.copy` decision swallows the key and calls `onCopy`. `PeekPanel.canCopy` is true when the panel is key and its first responder responds to `copy(_:)` and, where it validates user interface items, says yes for a copy item. `onCopy` sends `copy(_:)` to that first responder. This works for any plugin, and gives text views in the panel copy too. Alternative: a plugin-contract method for copying; it would add a contract member for what the responder chain already does.
- **Focus for a sheet.** The panel watches its own sheets: when one begins and Peeker isn't active, the panel makes itself key, which a non-activating panel can do without bringing Peeker forward, and the key monitor passes every key while the sheet is up, as it does while the button's menu is open. When the sheet ends and the panel is still showing, it activates Finder again. Other…'s own handling stays; on its OK the panel is already gone, so nothing is reactivated. Considered first: activating Peeker for the sheet. macOS grants an app's own request to come forward only after the user next acts in it, and a Cmd+C caught by the key monitor doesn't count, so Peeker came forward only after the sheet had closed, and Return went to Finder meanwhile. Also considered: the table activating the app itself; plugins shouldn't know they're in the panel.

## Risks / Trade-offs

- [Copying all of a 500,000-row table builds about 27 MB of text on the main thread] → It runs only when the user copies, and the preview uses the first 20 rows. Measured on `huge.csv` on an M6 (2026-11-13): gathering the cells 0.14 s, then Tabs 0.07 s, Commas 0.21 s, Markdown 0.09 s, after making the quoting check one pass over the bytes (it was 1.8 s for Tabs).
- [The event tap asks the panel for `canCopy` on every Cmd+C while it shows] → A few property reads on the main thread, only for that one key.
- [Finder stays the active app while the sheet is up, so the menu bar stays Finder's] → The sheet's buttons and keys are all it needs; the menu bar is back to normal when it closes.
- [The key monitor matches Cmd+C by its key code, as it does the panel's other keys, so on a layout that puts C elsewhere (Dvorak) Finder keeps that Cmd+C] → Same as the panel's Cmd+O and Cmd+R today; matching by character is a change for all three.
- [A text view in the panel copies on Cmd+C, which it didn't before] → Called out in the proposal for the maintainer; one line in `canCopy` limits it if they want tables only.
