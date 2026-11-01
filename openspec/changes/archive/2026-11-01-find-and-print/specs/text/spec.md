## ADDED Requirements

### Requirement: Print text

Printing a text file SHALL print the text in the window, unsaved edits included, in the window's font and size, black on white whatever the system appearance, wrapped to the page width even when Wrap Lines is off, across as many pages as it takes. Each page SHALL carry the system's header and footer: the file's name, the date and the page number.

#### Scenario: Dark mode
- **WHEN** the system is in dark mode and the user prints a text file
- **THEN** the printout is black text on white

#### Scenario: Long lines with wrapping off
- **WHEN** Wrap Lines is off and a line is wider than the page
- **THEN** the line wraps on paper instead of being cut off

#### Scenario: Header
- **WHEN** the user prints `notes.txt`, which needs 3 pages
- **THEN** each page shows "notes.txt", the date and its page number
