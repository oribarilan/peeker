# Proposal

## Why

CSV and TSV tables are the one editable format with neither Find nor Print: Cmd+F and Cmd+P are greyed out, so finding a value in a long export means scrolling, and printing means opening the file elsewhere.

## What Changes

- Find… (Cmd+F) in a table window shows a find bar under the toolbar, the same bar PDFs have: search field, match count, previous and next, Done. Find Next and Find Previous step through the matches.
- A cell matches when it contains the search, ignoring case and accents; the header row's titles count too. Matches follow the order shown, sort included. Matching cells are tinted and the current one is selected and scrolled into view. Edits refresh the matches. Finding never edits the file. No Replace.
- Print (Cmd+P) prints every row in the order shown, unsaved edits included, as a black-on-white grid shrunk to the page width (never enlarged), with the header row repeated on each page when the table has one, and the system header and footer.
- The print panel gets a Table section: a Row Numbers checkbox (off at first) and a list of the columns with checkboxes (all on at first); the last column can't be unticked; the preview follows. The choices last until the window closes.
- The PDF plugin's find bar moves into PeekerKit so both plugins use one bar; PDFs look and behave as before.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `table`: adds finding and printing.

## Impact

- New: `Sources/PeekerKit/FindBar.swift` (moved from `Plugins/pdf/PDFFindContainer.swift`), `Plugins/table/TableFind*.swift`, `Plugins/table/TablePrint*.swift`.
- Changed: `Plugins/pdf/PDFFindContainer.swift` (uses the shared bar), `Plugins/table/TableDocument.swift` (content view, print job), `Plugins/table/TableView.swift` (tints matches, reports changes).
- Tests next to `Tests/PDFFindTests.swift` and `Tests/TableDocumentTests.swift`; a screen step in the table flow; a CHANGELOG line; the backlog line goes, and "Replace in CSV/TSV tables" is added.
- No new dependency. Opening a table does no extra work: the bar and the finder are made on the first Cmd+F.
