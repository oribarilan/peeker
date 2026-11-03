## ADDED Requirements

### Requirement: Image edit tools

In the Editor, an image Peeker can edit SHALL show Crop and Rotate & Resize in the toolbar and the Tools menu from the start. The Peek panel SHALL have no edit tools.

#### Scenario: Opening a PNG

- **WHEN** the user opens a PNG in the Editor
- **THEN** Crop and Rotate & Resize are in the toolbar, and pressing C starts cropping

### Requirement: Images Peeker can't edit are read-only

An image SHALL be read-only, with the reason, when its format is one Peeker can't write without loss (anything but JPEG, PNG, GIF, TIFF, HEIC, AVIF, BMP and JPEG 2000: camera RAW, WebP, JPEG XL, PSD and EXR among them), when it has more than one frame (an animated GIF, a multi-page TIFF), and when it's over 100 megapixels.

#### Scenario: An animated GIF

- **WHEN** the user opens an animated GIF in the Editor
- **THEN** Crop and Rotate & Resize are greyed out, and the note says the image has several frames

#### Scenario: Camera RAW

- **WHEN** the user opens a DNG
- **THEN** the edit tools are greyed out, and the note says Peeker can't save this format

## REMOVED Requirements

### Requirement: Image Edit mode
**Reason**: There is no Edit mode; image tools are always available in the Editor.
**Migration**: See "Image edit tools".

### Requirement: Images Peeker can't edit
**Reason**: With no Edit button, such images show greyed tools and a note.
**Migration**: See "Images Peeker can't edit are read-only".

## MODIFIED Requirements

### Requirement: Cropping an image

In the Editor, Crop (C) SHALL let the user drag a rectangle on the image, adjust it with corner and edge handles, see its size in the image's pixels, and see the area outside it dimmed. Once a rectangle exists, Crop and Cancel buttons SHALL follow it, at the same size whatever the zoom. Crop or Return SHALL crop to it, as one edit; Cancel or Escape SHALL change nothing. A rectangle SHALL stay within the image.

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

#### Scenario: Buttons below the rectangle
- **WHEN** the user drags a rectangle with room below it, then scrolls or zooms
- **THEN** the buttons stay just below its bottom-right corner, their right edge on the rectangle's

#### Scenario: Rectangle at the bottom of the window
- **WHEN** the rectangle reaches the bottom edge of the visible image area
- **THEN** the buttons sit inside the rectangle's bottom-right corner, fully visible

### Requirement: Rotate & Resize panel

Rotate & Resize (Cmd+R) SHALL open a panel just below the toolbar, with buttons to rotate left, rotate right, flip horizontally and flip vertically (also L, R, H and V while it's open), width and height fields in pixels or percent, and an aspect lock, on by default. Applying a new size SHALL resize the image as one edit; enlarging SHALL be allowed. Escape SHALL close the panel.

#### Scenario: Turning twice
- **WHEN** the user presses Cmd+R, then R twice
- **THEN** the image is upside down, as two edits

#### Scenario: Resizing to half
- **WHEN** the user sets the width to 50 percent with the lock on and applies it
- **THEN** both sides are half their size

#### Scenario: Toolbar stays clear
- **WHEN** the user opens Rotate & Resize from the toolbar button or with Cmd+R
- **THEN** the panel's top edge is below the toolbar, and every toolbar item stays visible and clickable

### Requirement: Saving image edits

Image edits SHALL be pending until Cmd+S, undoable one by one back to the last save, kept in the recovery copy, and asked about on close. Saving SHALL apply them to the full-resolution image and replace the file in its own format, keeping its metadata with size and orientation updated; JPEG and HEIC at high quality. When every edit is a rotation or flip, a JPEG, HEIC or TIFF SHALL keep its image data and only change its recorded orientation.

#### Scenario: Crop saved at full size
- **WHEN** the user crops a 4000 × 3000 photo to its left half and saves
- **THEN** the file is 2000 × 3000 pixels, still a JPEG, with its camera and date

#### Scenario: Lossless rotation
- **WHEN** the user rotates a JPEG and saves
- **THEN** the image data in the file is unchanged and its orientation says it's turned

#### Scenario: Recovery
- **WHEN** the user crops and rotates an image and Peeker is force-quit before saving
- **THEN** the next launch reopens it with those edits

### Requirement: Animated images

An image with several frames that its format animates (GIF, animated PNG, WebP, HEIC sequence) SHALL play in a loop with the frame timing its file gives, in the Editor and the Peek panel. A click on the image SHALL pause it and another click resume it. A multi-page TIFF SHALL keep showing its first page.

#### Scenario: Playing
- **WHEN** the user opens an animated GIF
- **THEN** its frames play in a loop

#### Scenario: Pausing
- **WHEN** the user clicks a playing animation
- **THEN** it stops on the current frame, and a second click plays it on from there
