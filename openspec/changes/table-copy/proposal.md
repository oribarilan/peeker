# Proposal

## Why

A table selects cells like a spreadsheet now, but nothing can copy them: Cmd+C does nothing in the Editor, and in the Peek panel it copies the file in Finder. Pasting part of a CSV into a message, a spreadsheet or a Markdown note means opening it elsewhere.

## What Changes

- Copy (Cmd+C, Edit > Copy, and Copy in the right-click menu) with one cell selected puts that cell's text on the clipboard at once.
- With more than one cell selected (a block, rows, columns or everything), Copy opens a sheet with a preview of the text, a format (Tabs, Commas, Semicolons or Markdown table) and Include header row (when the table has one), with Cancel and Copy. The last format and header choice are remembered, so Return copies the way it did last time.
- Copies follow the order on screen, so a sorted table copies sorted. Fields are quoted as the file's format would quote them; in a Markdown table `|` is escaped and line breaks become spaces.
- In the Peek panel, once the user clicks into the table, Cmd+C and the right-click Copy copy the selected cells the same way, instead of Finder copying the file. The sheet takes the keyboard while it's open and hands it back to Finder when it closes. Before any click in the panel, Cmd+C stays Finder's.
- The host's part is format-blind: in the panel, Cmd+C goes to the panel when what has the panel's focus can copy now. So selected text in a Markdown or text file in the panel copies too.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `table`: copying cells, and the copy sheet.
- `peek-panel`: Cmd+C copies what's selected in the panel.

## Impact

- New in the table plugin: `TableCopy.swift` (building the text in each format) and `TableCopySheet.swift` (the sheet). Changed: `TableGridView.swift` (copy and its validation), `TableView.swift` (the right-click Copy).
- Changed in the host: `Sources/Host/PeekPanel/HotkeyMonitor.swift` (a copy decision) and `PeekPanel.swift` (routing copy and handing focus back after a sheet).
- Tests in `Tests/TableCopyTests.swift` (new), `Tests/HotkeyDecisionTests.swift`, `Tests/PeekPanelTests.swift`; steps in `scripts/screen/table-edit-flow.sh`. A CHANGELOG line.
- Nothing on the open path; copying a whole 500,000-row table builds its text on the main thread when the user asks for it.
- Builds on `table-cells` (the selection), which isn't archived yet.
