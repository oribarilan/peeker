## MODIFIED Requirements

### Requirement: Image Edit mode

In a document window, an image Peeker can edit SHALL open in a read view that never changes the file, with the host's Edit button and Cmd+E to turn Edit mode on. The image tools SHALL show in the toolbar only in Edit mode. The Peek panel SHALL have no Edit mode.

#### Scenario: Turning Edit mode on
- **WHEN** the user opens a PNG and presses Cmd+E
- **THEN** Edit mode turns on and the Crop and Rotate & Resize tools show

### Requirement: Animated images

An image with several frames that its format animates (GIF, animated PNG, WebP, HEIC sequence) SHALL play in a loop with the frame timing its file gives, in document windows and the Peek panel. A click on the image SHALL pause it and another click resume it. A multi-page TIFF SHALL keep showing its first page.

#### Scenario: Playing
- **WHEN** the user opens an animated GIF
- **THEN** its frames play in a loop

#### Scenario: Pausing
- **WHEN** the user clicks a playing animation
- **THEN** it stops on the current frame, and a second click plays it on from there
