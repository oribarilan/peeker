# Tasks

## 1. The text

- [x] 1.1 Write `Tests/TableCopyTests.swift` for `TableCopy.text`: each format with and without a header, quoting of separators, quotes and line breaks, Markdown's `|` escaping and line breaks as spaces, empty titles without a header. Then add `Plugins/table/TableCopy.swift`, sharing `CSVTable`'s quoting rule. Verify the tests pass.

## 2. Copy in the Editor

- [x] 2.1 Write failing tests in `Tests/TableCopyTests.swift` with an offscreen table: one selected cell copies at once to a test pasteboard; a sorted block copies in shown order; Copy is enabled in a read-only table once a cell is selected and disabled before; the right-click menus start with Copy.
- [x] 2.2 Add `copy(_:)` and its validation to `GridView`, gathering the cells in `TableView`, and Copy to the right-click menus. Verify the 2.1 tests pass.
- [x] 2.3 Write failing tests for the sheet (driven without showing it modally, through its controller): it opens with the remembered format and header, Tabs with the header the first time; the header checkbox is absent without a header row; the preview follows the format; Copy stores the choices and fills the pasteboard; Cancel leaves it. Then add `TableCopySheet.swift`. Verify the tests pass.
- [x] 2.4 Time copying every cell of a 500,000-row, five-column table in a test and record the time in the design's risk line; verify it stays under a second on this Mac or note it in the backlog.

## 3. Copy in the Peek panel

- [x] 3.1 Write failing tests in `Tests/HotkeyDecisionTests.swift`: Cmd+C with the panel showing, Finder in front and `canCopy` true decides `.copy`; with `canCopy` false, or the panel hidden, it passes; `canCopy` isn't asked for other keys. Add the decision and `onCopy`. Verify the tests pass.
- [x] 3.2 Write failing tests in `Tests/PeekPanelCopyTests.swift`: `canCopy` is false for a table before a click and true after selecting a cell; it's true for a text view with selected text; `onCopy` puts the cell on the pasteboard; a sheet beginning on the panel takes the keyboard, and its end reactivates Finder (stubbed) only while the panel shows; the key monitor passes every key while a sheet is up. Implement them in `PeekPanel.swift` and wire `onCopy` in the app delegate. Verify the tests pass.

## 4. Wrap-up

- [x] 4.1 Steps in `scripts/screen/table-edit-flow.sh`, which never touch the clipboard (the flows' rule; what's copied stays unit tests): in the Editor, select two cells, Cmd+C, check the copy sheet appears, Cancel; in the Peek panel, click a cell and Shift-click another, Cmd+C, check the sheet appears with Peeker in front, Cancel, and check Finder is in front again with the panel still up. Run with the maintainer's go (queue it in `.local/screen-queue.md` otherwise).
- [x] 4.2 CHANGELOG line under Unreleased; `scripts/build.sh test` passes with no warnings; `openspec validate --all` passes.
