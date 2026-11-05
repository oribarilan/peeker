# Spec Delta

## ADDED Requirements

### Requirement: Save As writes a copy and the window follows it

File > Save As… (Shift+Cmd+S) SHALL ask, in a sheet, for a name and folder, write the file there with its unsaved edits, and then show the new file in the same window, keeping its scroll position and zoom. The original file SHALL stay as it was on disk. The new file SHALL keep the original's format and extension. The window's title, Open Recent, watching for changes on disk and crash recovery SHALL follow the new file. The Peek panel SHALL NOT offer Save As.

#### Scenario: Keeping the original

- **WHEN** the user adds a text box to `form.pdf` and chooses Save As… with the name `form filled.pdf`
- **THEN** `form filled.pdf` holds the text box, `form.pdf` is unchanged on disk, and the window's title reads `form filled.pdf`

#### Scenario: Working on after Save As

- **WHEN** the user saves `notes.txt` as `draft.txt` and then types and presses Cmd+S
- **THEN** `draft.txt` gets the typing and `notes.txt` stays as it was

#### Scenario: Undo after Save As

- **WHEN** the user types in `notes.txt`, saves it as `draft.txt` and chooses Undo
- **THEN** the typing is undone in the window, and `draft.txt` shows as edited

### Requirement: Save As copies read-only files and leaves open ones alone

A file with no unsaved edits, or a read-only one, SHALL be copied as it is. Saving over a file that's open in another Peeker window SHALL be refused with the reason.

#### Scenario: A read-only file

- **WHEN** the user chooses Save As… on a digitally signed PDF
- **THEN** the copy is the same bytes as the original

#### Scenario: The destination is open elsewhere

- **WHEN** the user picks a file that another Peeker window shows
- **THEN** nothing is written and Peeker says the file is open in another window
