# Design

## Context

Plain Text opens CSV and TSV today, through `TextFile.load` (which also cuts files over 16 MB for display) and an `NSTextView`. PeekerKit already has what a text-based editor needs:
- `TextCodec.decode` and `encode` handle encodings, BOMs and line endings;
- `TextFile.write` writes through `FileReplacement` and offers UTF-8 on `.cannotEncode`;
- `TextEdits` is the `{"text": …}` snapshot that Plain Text's `recoveryText(from:)` already reads.

A plugin may import only PeekerKit and Apple frameworks. `PluginCatalog.builtIn` sets both the sidebar order and which plugin wins an extension clash. Nothing in the repo parses CSV yet. The benchmark already writes `small.csv` (100 rows) and `large.csv` (50,000 rows), but doesn't time them.

## Goals / Non-Goals

**Goals:**
- Show any CSV or TSV a user meets as a table, quickly, including ragged rows, quoted line breaks and odd delimiters.
- Edits that never disturb what the user didn't touch: unchanged rows are written back exactly as read.

**Non-Goals:**
- Find and Print in tables, which go to the backlog.
- Column types, formulas, sorting saved into the file, and multi-cell paste beyond what a text field takes.
- Delimiters other than comma, semicolon, tab and pipe.

## Decisions

### The model keeps the file's text and parses rows when they're shown

`CSVTable` is a value type holding the decoded text and, per record, its range in that text and its field count. A record is a line, unless a quoted field holds a line break.
- **Indexing:** one pass over the UTF-8 bytes, tracking quote state, finds the record ranges and field counts. That gives the column count and row count without building every cell.
- **Reading fields:** a record's fields are parsed when it's displayed, through a small cache.
- **Edited rows:** a changed row holds its fields, each with a `quoted` flag from the file, and replaces its range.
- **Why:** a 50 MB file has around half a million rows. Building every cell as a `String` on open would cost far more memory and time than the panel can afford, and keeping the original ranges is also what makes "unchanged rows written as read" free.
- **Rejected:** parsing everything into `[[String]]` is simpler, but slow and memory-hungry at the sizes in the spec. Using `NSTextView` with tab stops can't edit cells.

### Reading and writing CSV

- **The parser:** RFC 4180 with a chosen delimiter.
  - Fields may be quoted; `""` inside quotes is a quote, and a line break inside quotes stays in the field.
  - A stray quote in an unquoted field is kept as text.
  - A missing closing quote runs to the end of the file, so the file still opens.
- **Writing:**
  - An unchanged record writes its original range. A changed one writes its fields joined by the delimiter.
  - A field is quoted when it was quoted in the file or holds the delimiter, a quote or a line break; quotes are doubled.
  - Records are joined with the file's line ending, and the text goes through `TextFile.write` with the file's `TextFormat`, so encoding, BOM and the UTF-8 offer work as in Plain Text.
  - `TextCodec.encode` writes every line break as the file's ending, including one inside a quoted field. A file with mixed line endings therefore comes out with one kind; that's the same as Plain Text, and it doesn't break the byte-for-byte promise for files that use one kind.
- **Rejected:** a CSV package such as SwiftCSV or CodableCSV. Neither keeps per-field quoting or original ranges, and the parser is about 150 lines.

### Delimiter and header guesses

- **Delimiter:** count each candidate (`,` `;` `\t` `|`) outside quotes on each of the first 20 records. Pick the one that appears on most lines with the same non-zero count, and break ties in that order. Files with one column fall back to comma. A `tsv` file is always tab.
- **Header:** the first row is a header when every field in it is non-numeric text and some column below holds a number in at least half its non-empty cells, or when the file has one row. Numbers are read as in the user's locale and in POSIX form, so `3,50` and `3.50` both count.
- **Remembering per file:** a choice made in the View menu is remembered in `PluginPreferences` under `files`, as JSON mapping a file's path to its delimiter and header choice. It keeps the 500 most recent entries. Rejected: an extended attribute on the file, which changes the user's file.

### Editing and undo

The document keeps an `UndoManager` and applies edits as operations, each with its inverse:
- set a cell;
- insert or delete rows, where a deletion stores the removed rows;
- insert or delete a column, where a deletion stores the removed cells;
- move rows or a column.

Rejected: whole-table snapshots per undo step. Copying the row array for each step costs about 20 MB per step at 500,000 rows.

**Pending edits and recovery.** `unsavedEdits()` returns a snapshot holding a copy of the table, which is cheap because the arrays are copy-on-write. It encodes off the main thread as `TextEdits(text:)` with the serialized CSV.
- This reuses Plain Text's recovery format, so `recoveryText(from:)` is the same one-liner.
- `restore(encoded:)` parses the recovered text as the table, as one undo step.

### The view

- **The table:** a view-based `NSTableView`, with a fixed row-number column and one column per CSV column. Column titles come from the header row, or A, B, …, Z, AA when there's none. Cells are `NSTextField`s, reused as rows scroll; the table never makes views for rows off screen.
- **Editing a cell:** double-click or Return. Return commits and moves down, Tab moves right, Escape cancels.
- **Moving rows:** dragging a row number moves rows, using an internal pasteboard type.
- **Moving columns:** `allowsColumnReordering`, with the row-number column pinned. `tableViewColumnDidMove` applies the move to the model.
- **Sorting:**
  - The view keeps an optional `order: [Int]` mapping shown rows to file rows. Edits address file rows, so they land on the row the user sees.
  - Clicking a column title cycles through ascending, descending and file order. Numbers compare by value, and text with `localizedStandardCompare`.
- **Tools:**
  - Edit tools: Add Row Above, Add Row Below, Add Column Before, Add Column After, Delete Rows and Delete Columns, in Tools and in right-click menus on row numbers and column titles. The toolbar shows Add Row and Add Column.
  - View tools (menu-only): Header Row is a switch through `isOn`, and Commas, Semicolons, Tabs and Pipes are switches with the one in use on.
  - None has a default key, since typing belongs to the cells.

### Size limits and speed

- **Reading:** the file is read with `Data(contentsOf:options: .alwaysMapped)` and decoded with `TextCodec.decode`. That's not `TextFile.load`, which cuts files over 16 MB.
- **Files over 50 MB:** the whole file is still indexed and shown, read-only, with `editability = .readOnly("Files over 50 MB open as a read-only table.")`.
- **Off the main thread:** decoding and indexing run in a `@concurrent` function. The view only asks the model for visible rows.
- **Measuring:** `bench/ppbench.py` adds `small.csv` and `large.csv` to its files, and Apple's app for them is TextEdit. The A/B gate covers the panel and window opens from then on.

### Catalog and routing

- **The catalog:** `TablePlugin` goes into `builtIn` between Markdown and Plain Text, which gives the sidebar order.
- **Extensions:** `csv` and `tsv` leave `TextPlugin.defaultExtensions`, so no clash is reported. Plain Text still reads them through Open With, because `.csv` conforms to `public.plain-text`.
- **Icon:** the plugin's symbol is `tablecells`.

## Risks / Trade-offs

- [A CSV whose first lines mislead the delimiter guess] → The View menu override is remembered per file.
- [Very wide files (thousands of columns) make thousands of `NSTableColumn`s] → They're built once per open, and `NSTableView` handles it, if slowly. A cap can come later if it shows up.
- [Header guess wrong for all-text tables] → They show without a header (A, B, C) until toggled; View > Header Row is one click and is remembered.
- [Line endings inside quoted fields get the file's ending on save] → The same as Plain Text; noted above.
- [Per-file settings keyed by path are lost when a file moves] → Acceptable for a convenience; the guess runs again.
