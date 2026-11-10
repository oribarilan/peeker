# Tasks

## 1. Shared find bar

- [x] 1.1 Move the find bar to `Sources/PeekerKit/FindBar.swift` as `FindBar` with `onSearch`, `status` and a weak responder target; switch `PDFFindContainer` to it; `Tests/PDFFindTests.swift` passes with only the type names changed.

## 2. Find in tables

- [x] 2.1 `TableFinder`: background search of a `CSVTable` copy, ignoring case and accents, header titles included, stale results dropped; pure ordering by shown rows. Tests: "zurich" finds "Zürich", sorted order, header first, nothing found.
- [x] 2.2 `TableFindContainer` as the content view: Cmd+F shows the bar with the cursor in it and ends cell typing; Done and Escape close it; Cmd+G/Shift+Cmd+G, Return/Shift+Return step; the status reads "1 of 3" / "Not found"; Find items are greyed out where they don't apply. Tests drive it in a window.
- [x] 2.3 Tints: matching cells and header titles tinted, the current one selected and scrolled into view; edits, undo, delimiter and header changes search again without moving to the first match. Tests check the marks after a search and after an edit.

## 3. Print

- [x] 3.1 `TablePrintLayout` and `TablePrintView`: fit-width scale (never above 1), whole rows per page, header repeated, black on white, header and footer on. Tests: scale for a wide table, page count for 500 rows, header on each page's band.
- [x] 3.2 `TablePrintOptions` in the print panel: Row Numbers and column checkboxes, the last column locked, preview key path bumps; choices kept on the document. Tests: unchecking a column changes the printed columns, the last can't be unchecked, choices survive a second print job.
- [x] 3.3 `TableDocument.printJob` builds the job from the shown order and unsaved edits; Print is enabled for tables. Test: printing an edited, sorted table lays out rows in shown order with the edit.

## 4. Checks and docs

- [x] 4.1 `scripts/build.sh test` passes with no warnings.
- [ ] 4.2 Screen step in `scripts/screen/table-edit-flow.sh`: Cmd+F, type, the bar shows "1 of N"; Cmd+P shows the print panel with the Table section (queued until the maintainer's go).
- [x] 4.3 CHANGELOG line; backlog: drop "Find and Print in CSV/TSV tables", add "Replace in CSV/TSV tables"; `openspec validate --all` passes.

## Workflow follow-up

- Commit to local main, then bump `MARKETING_VERSION` to the next minor `-dev` in its own commit.
- Archive once the screen step has passed.
