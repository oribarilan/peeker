# table Specification

## Purpose
The Table plugin shows comma- and tab-separated files as a table and edits them as one: cells, rows and columns, saved back in the file's own format.

## Requirements

### Requirement: Opens CSV and TSV files as a table

By default the Table plugin SHALL open `csv` and `tsv` files, showing their rows and columns as a table with row numbers. A row with fewer fields than the widest row SHALL show empty cells, and quoted fields SHALL show their text without the quotes, with embedded delimiters, quotes and line breaks as the text holds them. A file that isn't text SHALL show "This doesn't look like a text file." in its tab.

#### Scenario: A quoted field

- **WHEN** the user opens a CSV whose second field is `"Smith, Jane"`
- **THEN** the table shows `Smith, Jane` in one cell of the second column

#### Scenario: Ragged rows

- **WHEN** one row has three fields and the next has five
- **THEN** the table has five columns and the short row ends in two empty cells

### Requirement: The delimiter is detected

The plugin SHALL detect a CSV file's delimiter from its first lines: comma, semicolon, tab or pipe. A `tsv` file SHALL always use tab. The View menu SHALL list the four delimiters (Commas, Semicolons, Tabs, Pipes) with the one in use checked, and choosing another SHALL split the file at it, remembered for that file.

#### Scenario: A semicolon file

- **WHEN** the user opens a `.csv` written with semicolons, such as `name;price` and `Tea;3,50`
- **THEN** the table shows two columns, with `3,50` in one cell

#### Scenario: Overriding the delimiter

- **WHEN** the user chooses View > Tabs
- **THEN** the table splits the file at tabs, and opening the file again keeps Tab

### Requirement: The header row

The plugin SHALL guess whether the first row is a header: it is when every field in it is text and some column below it holds numbers, or when the file has one row. A header row SHALL show as the table's column titles; without one, columns SHALL be titled A, B, C. View > Header Row SHALL show the guess as checked or not and switch it for that file, remembered for it. The header row SHALL stay the file's first line either way.

#### Scenario: A header guessed

- **WHEN** the first row is `name,price` and the rows below have numbers in the second column
- **THEN** the columns are titled name and price, and the data starts at row 1

#### Scenario: Turning the header off

- **WHEN** the user clears View > Header Row
- **THEN** the columns are titled A, B and the first line shows as row 1

### Requirement: Editing cells

In the Editor, double-clicking a cell or pressing Return SHALL edit it, Return SHALL commit and move down, Tab SHALL commit and move right, and Escape SHALL cancel. Each change SHALL be one undo step, mark the document edited and stay pending until Cmd+S. The Peek panel SHALL show the table without editing.

#### Scenario: Editing a cell

- **WHEN** the user double-clicks a cell, types `42` and presses Return
- **THEN** the cell shows 42, the selection moves to the cell below, and the window shows unsaved changes

### Requirement: Changing rows and columns

In the Editor, the user SHALL be able to add a row or column before or after the selection, delete the selected rows or the column of the cell last clicked, and move rows and columns by dragging their row number or column title. Each change SHALL be one undo step and stay pending until Cmd+S.

#### Scenario: Deleting a column

- **WHEN** the user selects the second column and chooses Delete Column
- **THEN** the column is gone, and Undo brings it back with its cells

### Requirement: Saving keeps the file's format

Saving SHALL write the table back with the file's delimiter, encoding, byte order mark and line endings. A field SHALL be quoted when it holds the delimiter, a quote, or a line break, or when it was quoted in the file; quotes inside a quoted field SHALL be doubled. Rows the user didn't change SHALL be written as they were read. Text the file's encoding can't hold SHALL ask before saving as UTF-8, as Plain Text does.

#### Scenario: Unchanged rows stay byte for byte

- **WHEN** the user edits one cell in a 1,000-row file and saves
- **THEN** only that cell's line differs from the file before

#### Scenario: A value with the delimiter

- **WHEN** the user types `a,b` into a cell of a comma file and saves
- **THEN** the file holds `"a,b"` in that field

### Requirement: Sorting shows, it doesn't edit

Clicking a column title SHALL sort the rows shown by that column, numbers by value and text alphabetically, and clicking again SHALL reverse the order; a third click SHALL return to file order. Sorting SHALL NOT change the file or mark the document edited. Edits made while sorted SHALL apply to the rows they were made on.

#### Scenario: Sorting by price

- **WHEN** the user clicks the price column's title
- **THEN** the rows show from the lowest price, and saving without other edits isn't offered

### Requirement: Large tables

A file larger than 50 MB SHALL open as a read-only table, with the reason shown as other read-only documents show it. Opening and scrolling a large table SHALL stay responsive, reading the file off the main thread.

#### Scenario: A 200 MB export

- **WHEN** the user opens a 200 MB CSV in the Editor
- **THEN** the table shows, editing is greyed out with the reason, and scrolling stays smooth

### Requirement: Opening a table is fast

Opening a CSV file in a window or the Peek panel SHALL be at least as fast as TextEdit opening it, and the Peek panel at least as fast as Quick Look, measured by the benchmark on the same Mac.

#### Scenario: A 50,000-row file

- **WHEN** the benchmark opens its large CSV fixture in the Peek panel and in a window
- **THEN** both are at least as fast as Quick Look and TextEdit on the same file
