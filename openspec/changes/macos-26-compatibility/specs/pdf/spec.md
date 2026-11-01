## ADDED Requirements

### Requirement: Saved annotations stay Peeker's on every supported macOS

A highlight, text box or signature Peeker saved SHALL be found again as Peeker's own when the file is reopened, on every macOS version Peeker supports, so it can be moved, resized, changed or removed like an unsaved one. Another app's annotation SHALL never be taken for Peeker's.

#### Scenario: Removing a saved highlight on macOS 26

- **WHEN** on macOS 26 the user saves a highlight, reopens the PDF later, selects the highlight in Edit mode, deletes it and saves
- **THEN** the save succeeds and the highlight is gone from the file

#### Scenario: Another app's annotation on macOS 26

- **WHEN** on macOS 26 the PDF holds a highlight another app made, next to one Peeker saved
- **THEN** only Peeker's can be selected in Edit mode

### Requirement: Reordering pages by dragging needs macOS 27

On macOS 26, thumbnails SHALL NOT be draggable, in Edit mode or out of it; Rotate Left, Rotate Right and Delete Page SHALL keep working from the toolbar, the Commands menu and the thumbnails' menu. On macOS 27 and later, dragging SHALL reorder pages as before.

#### Scenario: Dragging on macOS 26

- **WHEN** on macOS 26 the user drags page 3's thumbnail above page 1 in Edit mode
- **THEN** no page moves, and Rotate and Delete Page still work on the selected thumbnails

#### Scenario: Dragging on macOS 27

- **WHEN** on macOS 27 the user drags page 3's thumbnail above page 1 in Edit mode
- **THEN** page 3 becomes page 1
