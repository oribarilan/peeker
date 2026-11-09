## MODIFIED Requirements

### Requirement: Failed or unfinished saves keep the edits

A save that fails for any reason SHALL show why in a sheet and leave the edits on screen and pending, so the user can retry or copy them out. A save the user cancels partway, such as at a password the plugin asks for, SHALL show nothing more and SHALL also leave the edits pending. A save that hasn't finished SHALL NOT trap the window: closing it SHALL still ask about the unsaved edits, and the file SHALL end up either fully written or untouched.

#### Scenario: Write fails

- **WHEN** the save can't write because the file's folder was deleted
- **THEN** the window shows the failure, the edits stay, and a later Cmd+S can still save them once the folder is back

#### Scenario: Cancelled at a password

- **WHEN** a save asks for a password and the user clicks Cancel
- **THEN** no failure is shown, the file is unchanged, and the edits stay pending

#### Scenario: Closing during a slow save

- **WHEN** the user closes a window while its save is still writing to a slow network drive
- **THEN** the close asks Save, Don't Save or Cancel as usual, and the file is never left half written
