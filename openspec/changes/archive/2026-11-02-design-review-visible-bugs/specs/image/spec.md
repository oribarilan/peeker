## MODIFIED Requirements

### Requirement: Cropping an image

In Edit mode, Crop (C) SHALL let the user drag a rectangle on the image, adjust it with corner and edge handles, see its size in the image's pixels, and see the area outside it dimmed. Once a rectangle exists, Crop and Cancel buttons SHALL show just below its bottom-right corner, or inside that corner when there's no room below, and follow it as it moves, scrolls or zooms, at the same size whatever the zoom. Crop, or Return, SHALL crop to it, as one edit, and Cancel, or Escape, SHALL cancel without changing anything. A rectangle SHALL stay within the image.

#### Scenario: Cropping
- **WHEN** the user presses C, drags a rectangle over the image's left half and presses Return
- **THEN** the image shows only that half and the document is marked as edited

#### Scenario: Cropping with the mouse
- **WHEN** the user chooses Crop from the toolbar, drags a rectangle and clicks the Crop button beside it
- **THEN** the image is cropped to the rectangle, as one edit

#### Scenario: Cancelling
- **WHEN** the user presses Escape while choosing a rectangle
- **THEN** the rectangle goes away and nothing changes

#### Scenario: Cancelling with the mouse
- **WHEN** the user drags a rectangle and clicks the Cancel button beside it
- **THEN** the rectangle and the buttons go away and nothing changes

#### Scenario: No buttons before a rectangle
- **WHEN** the user chooses Crop and hasn't dragged yet
- **THEN** the image is dimmed and no Crop or Cancel button shows

#### Scenario: Rectangle at the bottom of the window
- **WHEN** the rectangle reaches the bottom edge of the visible image area
- **THEN** the buttons sit inside the rectangle's bottom-right corner, fully visible

### Requirement: Rotate & Resize panel

Rotate & Resize (Cmd+R) SHALL open a panel with buttons to rotate left, rotate right, flip horizontally and flip vertically, which L, R, H and V also press while the panel is open, and with width and height fields in pixels or percent and an aspect lock, on by default. The panel SHALL appear just below the toolbar, centered over the image area, and never cover the toolbar, however it was opened. Applying a new size SHALL resize the image as one edit; enlarging SHALL be allowed. Escape SHALL close the panel. Run from the read view, Cmd+R SHALL turn Edit mode on first.

#### Scenario: Turning twice
- **WHEN** the user presses Cmd+R, then R twice
- **THEN** the image is upside down, as two edits

#### Scenario: Resizing to half
- **WHEN** the user sets the width to 50 percent with the lock on and applies it
- **THEN** both sides are half their size

#### Scenario: Toolbar stays clear
- **WHEN** the user opens Rotate & Resize from the toolbar button or with Cmd+R
- **THEN** the panel's top edge is below the toolbar, and every toolbar item stays visible and clickable
