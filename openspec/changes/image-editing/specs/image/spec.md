## ADDED Requirements

### Requirement: Image Edit mode

In a document window, an image Peeker can edit SHALL open in a read view that never changes the file, with the host's Edit button and Cmd+E to turn Edit mode on. The image tools SHALL show in the toolbar only in Edit mode. The Space panel SHALL have no Edit mode.

#### Scenario: Turning Edit mode on
- **WHEN** the user opens a PNG and presses Cmd+E
- **THEN** Edit mode turns on and the Crop and Rotate & Resize tools show

### Requirement: Cropping an image

In Edit mode, Crop (C) SHALL let the user drag a rectangle on the image, adjust it with corner and edge handles, see its size in the image's pixels, and see the area outside it dimmed. Return SHALL crop to it, as one edit, and Escape SHALL cancel without changing anything. A rectangle SHALL stay within the image.

#### Scenario: Cropping
- **WHEN** the user presses C, drags a rectangle over the image's left half and presses Return
- **THEN** the image shows only that half and the document is marked as edited

#### Scenario: Cancelling
- **WHEN** the user presses Escape while choosing a rectangle
- **THEN** the rectangle goes away and nothing changes

### Requirement: Rotate & Resize panel

Rotate & Resize (Cmd+R) SHALL open a panel with buttons to rotate left, rotate right, flip horizontally and flip vertically, which L, R, H and V also press while the panel is open, and with width and height fields in pixels or percent and an aspect lock, on by default. Applying a new size SHALL resize the image as one edit; enlarging SHALL be allowed. Escape SHALL close the panel. Run from the read view, Cmd+R SHALL turn Edit mode on first.

#### Scenario: Turning twice
- **WHEN** the user presses Cmd+R, then R twice
- **THEN** the image is upside down, as two edits

#### Scenario: Resizing to half
- **WHEN** the user sets the width to 50 percent with the lock on and applies it
- **THEN** both sides are half their size

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
- **THEN** the next launch reopens it in Edit mode with those edits

### Requirement: Images Peeker can't edit

Edit SHALL be greyed out with the reason for an image whose format Peeker can't write without loss (anything but JPEG, PNG, GIF, TIFF, HEIC, AVIF, BMP and JPEG 2000: camera RAW, WebP, JPEG XL, PSD and EXR among them), for an image with more than one frame (an animated GIF, a multi-page TIFF), and for an image over 100 megapixels.

#### Scenario: An animated GIF
- **WHEN** the user opens an animated GIF in a window
- **THEN** the Edit button is disabled and says the image has several frames

#### Scenario: Camera RAW
- **WHEN** the user opens a DNG
- **THEN** the Edit button is disabled and says Peeker can't save this format
