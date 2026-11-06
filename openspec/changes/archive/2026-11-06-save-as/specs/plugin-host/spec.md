# Spec Delta

## ADDED Requirements

### Requirement: Plugins write a copy for Save As

A plugin document that saves SHALL also write its file to a new place for Save As: with unsaved edits, the file as a save would write it, read from its current file and written to the new place; without edits, a copy of the file as it is. Once the write succeeds, the document SHALL use the new file for later saves and reads; if it fails, the document SHALL stay on its file with its edits. A document that can't save SHALL refuse Save As.

#### Scenario: A failed Save As

- **WHEN** Save As can't write to the chosen folder
- **THEN** Peeker says why, the window still shows the original file, and its edits are still unsaved
