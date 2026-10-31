# Spec Delta

## MODIFIED Requirements

### Requirement: Unsaved edits survive a crash of the app

About 2 seconds after the last edit, the host SHALL write a recovery copy of the document's unsaved edits to `~/Library/Application Support/<bundle id>/Recovery/`, or to the folder in `$PEEKER_RECOVERY` when that's set, readable only by the user, and never next to or over the real file. The next launch SHALL look for recovery copies in the same folder. The copy SHALL be removed when the edits are saved or discarded, and a document closed without edits SHALL leave no copy.

#### Scenario: Save clears the recovery copy

- **WHEN** a document with a recovery copy is saved
- **THEN** its recovery copy is deleted

#### Scenario: A test run keeps its recovery copies apart

- **WHEN** the app runs with `$PEEKER_RECOVERY` set to a folder, a document is edited, and the app is killed
- **THEN** the recovery copy is in that folder, nothing is written to the default folder, and a launch without `$PEEKER_RECOVERY` restores nothing from that run
