# Spec Delta

## ADDED Requirements

### Requirement: Markup tools

An image window's toolbar SHALL have Markup (M), which shows a strip under the toolbar with Arrow (A), Box (B, an ellipse with Option held), Text (T), Pixelate (X), Steps (N), Pen (P), Marker (K) and Spotlight (S), each also reachable by its key. Markup SHALL be greyed out with the reason wherever editing is, and absent from the Peek panel.

#### Scenario: Pointing at a button

- **WHEN** the user presses M, then A, and drags from an empty spot to a button in a screenshot
- **THEN** an arrow in the current color points at the button

### Requirement: What each markup tool draws

Text SHALL be plain with a thin outline or a label on a filled rounded box. Steps SHALL number themselves in order and renumber when one is deleted. Pixelate SHALL hide its rectangle in blocks too coarse to read back. Spotlight SHALL dim the image outside its boxes, of which there can be several.

#### Scenario: Steps renumber

- **WHEN** the user drops steps 1, 2 and 3 and deletes step 2
- **THEN** the remaining badges read 1 and 2

#### Scenario: Hiding a password

- **WHEN** the user pixelates a password and saves
- **THEN** the saved file shows coarse blocks where the password was

### Requirement: One remembered markup style

Every markup tool SHALL use one color, picked from six swatches or the system color picker, and one size, S, M or L, scaled to the image. Both SHALL be remembered across launches. Picking a color or size with a mark selected SHALL change that mark.

#### Scenario: Recoloring a mark

- **WHEN** the user selects an arrow and clicks the blue swatch
- **THEN** the arrow turns blue, and the next mark drawn is blue too, also after a relaunch

### Requirement: Marks stay editable until the window closes

Marks SHALL be selectable, movable, resizable and deletable until the window closes, saved or not, with one Undo step per gesture. Crop and Rotate & Resize after marking SHALL move the marks with the image.

#### Scenario: Moving a saved mark

- **WHEN** the user draws a box, saves, drags the box elsewhere and saves again
- **THEN** the file shows the box only in its new place

#### Scenario: Cropping a marked image

- **WHEN** the user draws an arrow on the right half of an image and crops to the right half
- **THEN** the arrow stays on the same part of the picture

### Requirement: Copying the marked image

With no mark selected, Cmd+C SHALL copy the whole image with its edits and marks at full resolution. With a mark selected, Cmd+C SHALL copy the mark, and Cmd+V SHALL add a copy of it, offset a little.

#### Scenario: Pasting into a chat

- **WHEN** the user marks up a screenshot, presses Cmd+C and pastes into another app
- **THEN** the pasted image shows the marks

## MODIFIED Requirements

### Requirement: Saving image edits

Image edits and marks SHALL be pending until Cmd+S, undoable one by one, also past saves, while the window is open, kept in the recovery copy, and asked about on close. Saving SHALL apply them to the full-resolution image as the file was when it opened and replace the file in its own format, keeping its metadata with size and orientation updated; JPEG and HEIC at high quality, encoded once from the opened file at each save. When every edit is a rotation or flip and there are no marks, a JPEG, HEIC or TIFF SHALL keep its image data and only change its recorded orientation.

#### Scenario: Crop saved at full size
- **WHEN** the user crops a 4000 × 3000 photo to its left half and saves
- **THEN** the file is 2000 × 3000 pixels, still a JPEG, with its camera and date

#### Scenario: Lossless rotation
- **WHEN** the user rotates a JPEG and saves
- **THEN** the image data in the file is unchanged and its orientation says it's turned

#### Scenario: Undo past a save
- **WHEN** the user crops an image, saves, and chooses Undo
- **THEN** the whole image shows again, and saving writes it uncropped

#### Scenario: Recovery
- **WHEN** the user crops and rotates an image and Peeker is force-quit before saving
- **THEN** the next launch reopens it with those edits
