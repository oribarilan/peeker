# Proposal

## Why

The CSV and TSV table reads like a list of rows rather than a spreadsheet. Every column is 120 points wide, whatever it holds. Numbers line up left like text. There's no visible current cell, so the arrow keys move a row highlight. And a column can't be selected except by clicking one of its cells. People expect the table to behave like Numbers, Excel or Google Sheets, and the table must stay as fast to open as it is now on large files. This is the first of two changes; the second (`table-copy`) adds a copy sheet with formats, and copying from the Peek panel, and builds on the selection added here.

## What Changes

- Two new benchmark files, a 500,000-row CSV and a 200-column CSV, so this change and later table work are measured at scale.
- Columns open fitted to their header and the first 1,000 rows, between a minimum and about 320 points, with longer cells cut short with an ellipsis. Dragging a divider still resizes a column, and double-clicking it fits that column. The Peek panel fits columns too.
- A column whose sampled values are mostly numbers is right-aligned, its title too, in the Editor and the Peek panel.
- A current cell, drawn with a ring. Arrow keys move it, Tab and Shift-Tab move right and left, Return edits it, and typing a character replaces its text. While editing, Return saves and moves down, Tab saves and moves right, and Escape cancels; the next cell isn't put into editing. **BREAKING** for anyone used to Return and Tab carrying on typing in the next cell.
- Selection like Google Sheets: clicking a column title selects the column, clicking a row number selects the row, Shift-click and dragging across cells select a block, Shift-arrow grows the selection, and Cmd+A selects every cell. Delete or Forward Delete clears the selected cells as one undo step.
- Delete Rows and Delete Columns act on the rows and columns the selection covers.
- **BREAKING:** clicking a column title no longer sorts. Sorting moves to an arrow on the title, shown while the pointer is over it (and always on the sorted column); clicking it goes ascending, descending, then back to file order. The column title's right-click menu and the Tools menu get Sort Ascending, Sort Descending and Original Order.

Not in this change: copying (the `table-copy` change), sorting off the main thread, faster column edits on huge files, Go to Row, filters, Replace.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `table`: fitted column widths and right-aligned number columns; the current cell and its keys (Editing cells changes); cell, row, column and block selection with Delete to clear; Delete Rows and Delete Columns follow the selection (Changing rows and columns changes); sorting through the title's arrow and menus (Sorting shows, it doesn't edit changes); the benchmark's large table files (Opening a table is fast changes).

## Impact

- `Plugins/table/TableView.swift` (selection, keys, widths, alignment), a header view and header cell for the sort arrow, `TableDocument.swift` (clearing cells, deleting several columns, the sort tools), `TablePlugin.swift` (new tools), `CSVTable.swift` (removing several columns at once), `TableFind.swift` (the current match becomes the current cell). The width measuring in `TablePrintView.swift` moves to a shared helper the table view also uses.
- `bench/make-fixtures.swift` and `bench/ppbench.py` gain `huge.csv` and `wide.csv`.
- Tests: `TableViewTests`, `TableDocumentTests`, `TableFindTests`, and new suites for selection, keys and fitting.
- `scripts/screen/table-edit-flow.sh`: sorting moves to the arrow, Return no longer edits the next cell, and new steps for selection and keys.
- No new dependencies, no config keys, no host changes.
