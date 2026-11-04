# Spec Delta

## MODIFIED Requirements

### Requirement: File menu additions

File SHALL offer Open Recent, listing recently opened files with Clear Menu at the end; choosing a file SHALL open it as Open… would. File SHALL offer Open With, a submenu listing the plugins the toolbar's Open With control lists, with the current one checked, switching the same way; when the toolbar hides that control because only one plugin can show the file, File > Open With SHALL stay in the menu, greyed out. File SHALL offer Revert to Saved…, enabled only while the document has unsaved edits; it SHALL ask before discarding them, and confirming SHALL return the document to its last saved or loaded state.

#### Scenario: Reopening a recent file
- **WHEN** the user opened notes.md earlier and chooses File > Open Recent > notes.md
- **THEN** notes.md opens in the Editor

#### Scenario: Reverting
- **WHEN** a text document has unsaved edits and the user chooses Revert to Saved… and confirms
- **THEN** the text is back as last saved and the window no longer shows unsaved edits

#### Scenario: Nothing to revert
- **WHEN** a document has no unsaved edits
- **THEN** Revert to Saved… is greyed out

#### Scenario: Open With with one choice
- **WHEN** a photo is open in a window
- **THEN** File > Open With is greyed out
