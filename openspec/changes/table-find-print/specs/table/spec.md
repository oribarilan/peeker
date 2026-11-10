## ADDED Requirements

### Requirement: Finding in a table

In the Editor, Find… (Cmd+F) SHALL show a find bar above the table and below the toolbar, with a search field, the match count, previous and next buttons and Done, with the cursor in the field; Escape or Done SHALL close it. A cell SHALL match when its text contains the search, ignoring case and accents, the header row's titles included. Finding SHALL NOT change the file.

#### Scenario: Searching

- **WHEN** the user presses Cmd+F in a table window and types "berlin", which is in 3 cells
- **THEN** the 3 cells are tinted, the first is selected and in view, and the bar says "1 of 3"

#### Scenario: Case and accents ignored

- **WHEN** the user searches for "zurich" in a table with a cell "Zürich"
- **THEN** that cell is a match

#### Scenario: Nothing found

- **WHEN** the user searches for a word no cell has
- **THEN** the bar says "Not found"

### Requirement: Moving through matches

Matches SHALL be ordered as the rows are shown: header first, then row by row and left to right, following a sort. Every matching cell SHALL be tinted and the current one selected and scrolled into view. Find Next (Cmd+G), Find Previous (Shift+Cmd+G), Return and Shift+Return SHALL move through them.

#### Scenario: Sorted

- **WHEN** the table is sorted by a column and the user steps through matches with Cmd+G
- **THEN** the matches come in the order the rows are shown

### Requirement: Matches follow edits

While the find bar shows, an edit, an undo or a change of delimiter or header row SHALL search again, keeping the search text, without moving to the first match. A search of a large table SHALL run off the main thread, so the window keeps responding.

#### Scenario: Editing a match away

- **WHEN** the bar shows "1 of 3" for "berlin" and the user changes one matching cell to "Paris"
- **THEN** the bar shows 2 matches and that cell is no longer tinted

### Requirement: Printing a table

Print SHALL print every row in the order shown, unsaved edits included, as a grid of black text on white with light grid lines, whatever the appearance. The grid SHALL be shrunk to fit the page width, never enlarged. When the table has a header row, it SHALL print in bold at the top of every page. Rows SHALL NOT be split across pages. Each page SHALL carry the system's header and footer: the file's name, the date and the page number.

#### Scenario: A long table

- **WHEN** the user prints a table with a header row and 500 rows
- **THEN** the pages show the rows in order, each page starting with the header row

#### Scenario: A wide table

- **WHEN** the user prints a table whose columns are twice as wide as the page
- **THEN** every column fits across the page, at about half size

### Requirement: Choosing what prints

The print panel SHALL have a Table section with a Row Numbers checkbox, off at first, and a list of the table's columns, named by the header row or as Column 1, Column 2 and so on, each with a checkbox, all on at first. Only checked columns SHALL print, and row numbers SHALL print as a first column when checked. The last checked column SHALL NOT be uncheckable. The preview SHALL follow each change. Printing again from the same window SHALL start with the last choices.

#### Scenario: Leaving out columns

- **WHEN** the user unchecks two of five columns in the print panel
- **THEN** the preview and the printout show the other three, wider

#### Scenario: Choices remembered

- **WHEN** the user prints with row numbers on and later prints again from the same window
- **THEN** Row Numbers is already checked
