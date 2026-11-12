# Tasks

## 1. Benchmark files

- [x] 1.1 `bench/make-fixtures.swift` writes `huge.csv` (500,000 rows, five columns, under 50 MB) and `wide.csv` (200 columns by 2,000 rows); `bench/ppbench.py` lists and labels both. Verify: running the fixture script makes both files, and `huge.csv` opens editable in the Release build.
- [x] 1.2 Record a baseline: `scripts/bench-ab.sh main` with only the new files, so later runs compare against the same fixtures (needs the maintainer's go, since it takes over the machine).

## 2. Fitting and alignment

- [x] 2.1 `ColumnFit`: per column, the three longest strings in the header and first 1,000 rows, and whether at least 80% of non-empty cells below the header are numbers. Tests: longest strings kept, a price column numeric, a mixed column not, the header ignored for numbers, a ragged row.
- [x] 2.2 Run it in `TablePlugin.load` and again after delimiter and header changes; `TablePrintView` measures through it. Tests: `TablePrintTests` pass unchanged; changing the header row changes which columns are numeric.
- [x] 2.3 `TableView` sets each column's width from the kept strings with the cell font, clamped to about four characters and 320 points times the zoom; number columns and their titles right-aligned; a cell wider than its column ends in an ellipsis. Tests: a short column is narrow, a long one stops at the cap, zoom scales the cap, a number column is right-aligned.
- [x] 2.4 Double-clicking a divider fits the column (`tableView(_:sizeToFitWidthOfColumn:)`), capped at the visible width. Test: the delegate's answer for a dragged-narrow column equals its fitted width.

## 3. Selection and the current cell

- [x] 3.1 `TableSelection`: current cell, anchor, and a block, rows or columns kind; click, Shift-click, Cmd-click on rows and columns, moves with and without extending, Select All, clamping after the table shrinks. Tests cover each.
- [x] 3.2 `CellView` draws `isSelected` (accent tint) and `isCurrent` (accent ring), with `isNumber` renamed `isRowNumber`; `TableView` sets them in `viewFor` and updates only visible cells on a change; the current cell's row number and title get a light tint. Test: after a selection change, the visible cells' flags match the model.
- [x] 3.3 Mouse in `GridView`: a cell click sets the current cell, Shift-click extends, a drag selects a block with autoscroll, row-number clicks keep AppKit's row selection and row drag, double-click edits. Title clicks select the column (Shift extends, Cmd toggles); title drags still move columns. Tests send synthetic mouse events in a window.
- [x] 3.4 Keys in `GridView`: arrows, Shift-arrows, Tab and Shift-Tab stopping at the edges, Return and Enter edit, Cmd+A selects all, and the table scrolls to the current cell. Tests send key events.
- [x] 3.5 Typing a printable character starts editing with an empty field and hands the event to the field editor; Return saves and moves down, Tab saves and moves right, Escape cancels, and none starts editing the next cell. Tests: typing `Cake` over `Tea` then Return gives `Cake` with the cell below current and no editor showing; Escape keeps `Tea` and the document unedited.
- [x] 3.6 Find makes its current match the current cell; sorting keeps the current cell's file row and collapses the selection. Tests in `TableFindTests` and `TableViewTests`.

## 4. Edits that follow the selection

- [x] 4.1 `CSVTable.removeColumns(_:)` in one pass; Delete Columns removes the columns the selection covers, Delete Rows the rows, Add Row/Column use the selection's edges; each one undo step. Tests: deleting two selected columns and undoing, deleting the rows a block covers.
- [x] 4.2 Delete and Forward Delete clear the selected cells as one undo step and do nothing in a read-only table or when every cell is already empty. Tests: clearing a block and undoing, read-only does nothing, the document isn't marked edited for empty cells.

## 5. Sorting

- [x] 5.1 `TableHeaderView`: a dimmed indicator on the hovered title, the sorted one always shown; a click inside the indicator rect cycles ascending, descending, file order; elsewhere it selects. Tests: a click in the indicator rect sorts, a click elsewhere selects without sorting.
- [x] 5.2 `sort-ascending`, `sort-descending`, `sort-none` tools (Sort Ascending, Sort Descending, Original Order) for the current cell's column, in Tools and the title's right-click menu, no shortcuts, working read-only. Tests: each tool's order, and that sorting doesn't mark the document edited.

## 6. Checks and docs

- [x] 6.1 `scripts/build.sh test` passes with no warnings.
- [x] 6.2 `scripts/screen/table-edit-flow.sh`: sort through the title's arrow instead of a title click; the edit step's Return leaves no editor showing; new steps for typing over a cell, Shift-Down selecting, Delete clearing and saving, and a title click selecting a column; Space on a CSV takes a screenshot of the panel, since Accessibility gives a cell's frame but not where its text sits; unit tests check the alignment. Run with the maintainer's go.
- [ ] 6.3 On screen, by hand: the hover arrow and the selection tint and ring in light and dark; dragging a block; typing with an input method (queued in `.local/screen-queue.md` if the screen isn't free).
- [x] 6.4 `scripts/bench-ab.sh main` shows no regression on `huge.csv`, `wide.csv` or the existing CSV files (with the maintainer's go).
- [x] 6.5 CHANGELOG line under Unreleased; backlog: add "Table: sort and column edits off the main thread"; `openspec validate --all` passes.

## Workflow follow-up

- Commit to local main, then bump `MARKETING_VERSION` to the next minor `-dev` in its own commit.
- Archive once the screen steps have passed.
- Then propose `table-copy` from the same plan.
