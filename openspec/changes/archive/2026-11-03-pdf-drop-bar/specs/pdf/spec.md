## MODIFIED Requirements

### Requirement: Reordering pages by dragging needs macOS 27

On macOS 26, thumbnails SHALL NOT be draggable; Rotate Left, Rotate Right and Delete Page SHALL keep working from the toolbar, the Tools menu and the thumbnails' menu. On macOS 27 and later, dragging SHALL reorder pages as before, and while a thumbnail is dragged over the thumbnails a bar SHALL show in the gap where the page will land, until the drop, the drag ends, or the pointer leaves the thumbnails.

#### Scenario: Dragging on macOS 26

- **WHEN** on macOS 26 the user drags page 3's thumbnail above page 1
- **THEN** no page moves, and Rotate and Delete Page still work on the selected thumbnails

#### Scenario: Dragging on macOS 27

- **WHEN** on macOS 27 the user drags page 3's thumbnail above page 1
- **THEN** page 3 becomes page 1

#### Scenario: Where the page will land

- **WHEN** on macOS 27 the user drags page 3's thumbnail and holds it over the top half of page 1's thumbnail
- **THEN** a bar shows above page 1, and it goes once the page is dropped
