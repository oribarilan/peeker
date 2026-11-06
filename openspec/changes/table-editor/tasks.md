# Tasks

## 1. Module and routing

- [ ] 1.1 Add the `PeekerTable` target (`Plugins/table/`) to `project.yml`: the app's dependencies and both test bundles; a `TablePlugin` stub (`id` "table", name "Table", symbol `tablecells`, `csv` and `tsv`).
- [ ] 1.2 Failing tests, then: `PluginCatalog.builtIn` lists Table between Markdown and Plain Text; `TextPlugin.defaultExtensions` drops `csv` and `tsv`; update `RoutingTests`, `DefaultExtensionsTests` and `PluginToolsTests`.

## 2. CSV model

- [ ] 2.1 Failing tests: the parser handles plain, quoted, doubled-quote and line-break fields, ragged rows, a stray quote, a missing closing quote, BOM and CRLF files; the record index gives row and column counts without building cells.
- [ ] 2.2 Failing tests: the delimiter guess (comma, semicolon, tab, pipe, ties, one column) and `tsv` always tab; the header guess (text over numbers, locale and POSIX numbers, one-row file, all-text file).
- [ ] 2.3 Failing tests: writing keeps unchanged records byte for byte, quotes where needed or already quoted, doubles quotes, joins with the file's line ending.
- [ ] 2.4 Implement `CSVTable`, the parser, the guesses and the writer.

## 3. Document

- [ ] 3.1 Failing tests: opening reads off the main thread and shows rows; a file over 50 MB is read-only with the reason; the Peek panel (`allowsEditing` false) doesn't edit; a non-text file says so.
- [ ] 3.2 Failing tests: each edit operation (cell, add/delete/move rows, add/delete/move column) changes the table, calls `onEdit`, and undoes as one step; edits apply to file rows while the view is sorted.
- [ ] 3.3 Failing tests: `unsavedEdits` encodes the CSV as `TextEdits`; `restore` brings it back; `save` and `saveAs` write the format and offer UTF-8; `revertEdits` and `reload` go back to the file; `recoveryText` reads the text.
- [ ] 3.4 Failing tests: View > Header Row and the delimiter switches change the view and are remembered per file in `PluginPreferences`; a remembered choice applies on the next open.
- [ ] 3.5 Implement `TableDocument` and its tools.

## 4. View

- [ ] 4.1 The `NSTableView`: row numbers, column titles from the header or A, B, …; cell editing with Return, Tab and Escape; dragging row numbers and column titles to move; right-click menus; sorting by clicking a column title.
- [ ] 4.2 Failing tests where the view can be checked in an off-screen window: titles, editing a cell through the table, sort order cycling, column move reaching the model.

## 5. Checks and docs

- [ ] 5.1 `bench/ppbench.py` times `small.csv` and `large.csv` (TextEdit as Apple's app); run `scripts/bench-ab.sh` against main.
- [ ] 5.2 Screen tests: routing cases for `csv` and `tsv` in `e2e-routing.sh`; a `table-edit` flow (open a CSV, edit a cell, save and compare the file; add and delete a row; sort and check nothing is unsaved; Header Row off; the Peek panel shows the table) wired into `screen-test.sh`; update the `run-peeker` skill.
- [ ] 5.3 `scripts/build.sh test` passes with no new warnings.
- [ ] 5.4 README's plugin list, CHANGELOG, `openspec/config.yaml`'s open question answered, `openspec/backlog.md` (the data editor next; Find and Print in tables); `openspec validate --all --strict`.

## Workflow follow-up

- Commit the change, then bump the minor version in its own commit; run the screen flows; archive, push and install.
