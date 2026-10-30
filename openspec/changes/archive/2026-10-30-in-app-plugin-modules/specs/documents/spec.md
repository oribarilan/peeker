# Spec Delta

## ADDED Requirements

### Requirement: Failed or unfinished saves keep the edits

A save that fails for any reason SHALL show why in a sheet and leave the edits on screen and pending, so the user can retry or copy them out. A save that hasn't finished SHALL NOT trap the window: closing it SHALL still ask about the unsaved edits, and the file SHALL end up either fully written or untouched.

#### Scenario: Write fails

- **WHEN** the save can't write because the file's folder was deleted
- **THEN** the window shows the failure, the edits stay, and a later Cmd+S can still save them once the folder is back

#### Scenario: Closing during a slow save

- **WHEN** the user closes a window while its save is still writing to a slow network drive
- **THEN** the close asks Save, Don't Save or Cancel as usual, and the file is never left half written

## REMOVED Requirements

### Requirement: A failed save keeps the edits

**Reason**: Its scenario was a plugin process crashing during a save, which can't happen once plugins run in the app. Replaced by "Failed or unfinished saves keep the edits", which also covers a save that hasn't finished when the window closes.

**Migration**: None for users.
