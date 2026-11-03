## MODIFIED Requirements

### Requirement: Editing keeps the file's format

Text files SHALL be editable in the Editor, with undo and redo. Saving SHALL write the text in the file's original encoding and byte-order mark, write every line break as the file's dominant line ending, and keep the trailing newline as it is in the text. A save with no change to the text SHALL write nothing, so a file with mixed line endings stays byte for byte the same.

#### Scenario: Editing a CRLF file

- **WHEN** the user edits and saves a UTF-16 file with CRLF line endings and a byte-order mark
- **THEN** the file is still UTF-16 with the same byte-order mark and CRLF endings

#### Scenario: Saving without changes

- **WHEN** the user saves a file whose text they changed and then changed back
- **THEN** the file on disk is unchanged
