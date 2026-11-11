## MODIFIED Requirements

### Requirement: Editing cells

In the Editor, double-clicking a cell, pressing Return on the current cell, or typing a character SHALL edit it: Return and double-click start with the cell's text, and a typed character replaces the text with that character, input methods included. While editing, Return SHALL save the text and make the cell below current, Tab SHALL save it and make the cell to the right current, and Escape SHALL cancel; none of them SHALL start editing the next cell. Each change SHALL be one undo step, mark the document edited and stay pending until Cmd+S. The Peek panel SHALL show the table without editing.

#### Scenario: Editing a cell

- **WHEN** the user double-clicks a cell, types `42` and presses Return
- **THEN** the cell shows 42, the cell below is current and not being edited, and the window shows unsaved changes

#### Scenario: Typing replaces a cell

- **WHEN** the current cell holds `Tea` and the user types `Cake` and presses Return
- **THEN** the cell holds `Cake`, not `TeaCake`

#### Scenario: Escape keeps the old text

- **WHEN** the user types over a cell and presses Escape
- **THEN** the cell keeps its old text and the document isn't marked edited

### Requirement: Changing rows and columns

In the Editor, the user SHALL be able to add a row or column before or after the current cell, delete the rows or the columns the selection covers, and move rows and columns by dragging their row number or column title. Each change SHALL be one undo step and stay pending until Cmd+S.

#### Scenario: Deleting a column

- **WHEN** the user clicks the second column's title and chooses Delete Columns
- **THEN** the column is gone, and Undo brings it back with its cells

#### Scenario: Deleting the rows a block covers

- **WHEN** the user selects a block of cells spanning rows 3 to 5 and chooses Delete Rows
- **THEN** rows 3, 4 and 5 are gone, in one undo step

### Requirement: Sorting shows, it doesn't edit

Each column title SHALL show a sort arrow while the pointer is over it, and the sorted column SHALL show its arrow all the time. Clicking the arrow SHALL sort the rows shown by that column, numbers by value and text alphabetically; clicking it again SHALL reverse the order, and a third click SHALL return to file order. The column title's right-click menu and the Tools menu SHALL offer Sort Ascending, Sort Descending and Original Order for the current cell's column, with no keys of their own. Clicking a title anywhere but its arrow SHALL NOT sort. Sorting SHALL NOT change the file or mark the document edited, and SHALL work in read-only tables and the Peek panel. Edits made while sorted SHALL apply to the rows they were made on.

#### Scenario: Sorting by price

- **WHEN** the user clicks the arrow on the price column's title
- **THEN** the rows show from the lowest price, and saving without other edits isn't offered

#### Scenario: Clicking a title selects rather than sorts

- **WHEN** the user clicks the price column's title away from its arrow
- **THEN** the price column is selected and the row order doesn't change

#### Scenario: Sorting from the menu

- **WHEN** the current cell is in the name column and the user chooses Tools > Sort Descending
- **THEN** the rows show by name from Z to A, and Tools > Original Order puts them back in file order

### Requirement: Opening a table is fast

Opening a CSV file in a window or the Peek panel SHALL be at least as fast as TextEdit opening it, and the Peek panel at least as fast as Quick Look, measured by the benchmark on the same Mac. The benchmark SHALL include a CSV of 500,000 rows and one of 200 columns, and fitting the columns SHALL NOT make opening either of them measurably slower.

#### Scenario: A 50,000-row file

- **WHEN** the benchmark opens its large CSV fixture in the Peek panel and in a window
- **THEN** both are at least as fast as Quick Look and TextEdit on the same file

#### Scenario: A 500,000-row file

- **WHEN** the benchmark opens its 500,000-row CSV with and without fitted columns
- **THEN** the times are the same within the benchmark's noise

## ADDED Requirements

### Requirement: Columns fit their content

A table SHALL open with each column as wide as its title and the widest of its first 1,000 rows, at least wide enough for a few characters and at most about 320 points at the default text size, scaled with the table's zoom. A cell wider than its column SHALL be cut short with an ellipsis. Dragging a column's divider SHALL resize it, and double-clicking the divider SHALL fit the column to its title and the rows sampled and on screen, as wide as the table's visible area at most. The widths SHALL be fitted again when the delimiter or the header row changes, and SHALL NOT be remembered for the file. The Peek panel SHALL fit columns the same way.

#### Scenario: Short and long columns

- **WHEN** the user opens a CSV with an `id` column of two-digit numbers and a `notes` column of long sentences
- **THEN** `id` is narrow, `notes` stops at the widest size with its text ending in an ellipsis

#### Scenario: Fitting a dragged column

- **WHEN** the user drags a column narrower, then double-clicks its divider
- **THEN** the column is as wide as its widest sampled cell again

### Requirement: Number columns align right

A column SHALL be right-aligned, its title too, when most of its non-empty cells among the first 1,000 rows below the header are numbers as sorting reads them. Other columns SHALL stay left-aligned. The alignment SHALL be decided again when the delimiter or the header row changes, and SHALL apply in the Editor and the Peek panel.

#### Scenario: A price column

- **WHEN** the user opens a CSV whose `price` column holds `2.50`, `3.50` and `12`
- **THEN** the prices line up on the right, and the `name` column stays on the left

### Requirement: The current cell

A table SHALL have one current cell, drawn with a ring in the accent color, which starts at the first cell. Clicking a cell SHALL make it current. In the Editor, the arrow keys SHALL move it one cell, and Tab and Shift-Tab SHALL move it right and left, stopping at the table's edges; the table SHALL scroll to keep it in view. Find SHALL make its current match the current cell. Sorting SHALL keep the same file row current.

#### Scenario: Moving with the keys

- **WHEN** the first cell is current and the user presses Right, then Down
- **THEN** the cell in the second column of the second row is current

#### Scenario: Stopping at the edge

- **WHEN** the current cell is in the last column and the user presses Tab
- **THEN** the same cell stays current

### Requirement: Selecting cells, rows and columns

The selection SHALL be the current cell alone, a block of cells, whole rows or whole columns, tinted in the accent color with the current cell inside it. Clicking a row number SHALL select that row and clicking a column title SHALL select that column; Shift-click on a cell, row number or title SHALL extend the selection from the current cell, and Cmd-click on a row number or title SHALL add or remove that row or column. Dragging across cells SHALL select a block. In the Editor, Shift with an arrow key SHALL grow or shrink the selection by one cell, and Select All (Cmd+A) SHALL select every cell. Clicking a single cell SHALL select just that cell. The Peek panel SHALL select with the mouse the same way.

#### Scenario: Selecting a column

- **WHEN** the user clicks the price column's title
- **THEN** every cell in the price column is tinted, and its first cell is current

#### Scenario: A block by dragging

- **WHEN** the user drags from the cell at row 2, column A to the cell at row 4, column C
- **THEN** those nine cells are selected

#### Scenario: Growing with Shift-arrow

- **WHEN** a cell is current and the user presses Shift-Down twice
- **THEN** that cell and the two below it are selected

### Requirement: Clearing cells

In the Editor, Delete or Forward Delete SHALL clear every selected cell's text as one undo step, mark the document edited, and leave the rows and columns in place. In a read-only table, they SHALL do nothing.

#### Scenario: Clearing a block

- **WHEN** the user selects six cells and presses Delete
- **THEN** the six cells are empty, and one Undo brings back all six
