# Spec Delta

## MODIFIED Requirements

### Requirement: File menu additions

File SHALL offer Open Recent, listing recently opened files with Clear Menu at the end; choosing a file SHALL open it as Open… would. File SHALL offer Open With, a submenu listing the plugins that read the file, with the current one checked, switching the same way the toolbar's Open With control does; then a separator, the other installed apps macOS says open the file, each with its icon (the Mac's default app for the file first, then the rest A to Z, without Peeker), and Other…, a picker of any app. Choosing an app SHALL open the file in it, in front, keep the window open and change no default. When the document has unsaved edits, choosing an app SHALL first ask to Save (then open the saved file), Open Without Saving (open the file as it is on disk and keep the edits), or Cancel (open nothing). The apps SHALL be listed only when the menu opens. File > Open With SHALL be enabled whenever a file is open.

#### Scenario: Reopening a recent file
- **WHEN** the user opened notes.md earlier and chooses File > Open Recent > notes.md
- **THEN** notes.md opens in the Editor

#### Scenario: Open With with one choice
- **WHEN** a photo is open in a window and the user opens File > Open With
- **THEN** it lists Image, checked, then the apps that open photos with the Mac's default first, then Other…

#### Scenario: Opening in another app
- **WHEN** `main.swift` is open with no unsaved edits and the user chooses Xcode from File > Open With
- **THEN** `main.swift` opens in Xcode in front, and the Peeker window stays open on it

#### Scenario: Unsaved edits, saving first
- **WHEN** `notes.md` has unsaved edits and the user chooses TextEdit from File > Open With, then Save
- **THEN** the edits are saved, then `notes.md` opens in TextEdit

#### Scenario: Unsaved edits, opening without saving
- **WHEN** `notes.md` has unsaved edits and the user chooses TextEdit, then Open Without Saving
- **THEN** TextEdit opens the file as saved on disk, and the Peeker window still shows the unsaved edits

#### Scenario: Cancelling
- **WHEN** `notes.md` has unsaved edits and the user chooses TextEdit, then Cancel
- **THEN** nothing opens and the edits stay unsaved

#### Scenario: Other…
- **WHEN** the user chooses File > Open With > Other… and picks an app
- **THEN** the file opens in that app, and the picker offers no Always checkbox
