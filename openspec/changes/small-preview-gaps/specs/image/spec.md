## ADDED Requirements

### Requirement: Actual size and zooming out

Actual Size (Cmd+0) SHALL show the image at one image pixel per screen pixel, centered. Zoom Out SHALL go below fit, down to an eighth of fit or to actual size when that's smaller. An image smaller than the window SHALL stay centered.

#### Scenario: Actual size of a small icon
- **WHEN** the user opens a 64 × 64 icon and presses Cmd+0
- **THEN** the icon shows at 64 × 64 screen pixels in the middle of the window

#### Scenario: Zooming out
- **WHEN** the user presses Zoom Out four times from fit
- **THEN** the image gets smaller than the window and stays centered

### Requirement: Animated images

An image with several frames that its format animates (GIF, animated PNG, WebP, HEIC sequence) SHALL play in a loop with the frame timing its file gives, in document windows and the Space panel. A click on the image SHALL pause it and another click resume it. A multi-page TIFF SHALL keep showing its first page.

#### Scenario: Playing
- **WHEN** the user opens an animated GIF
- **THEN** its frames play in a loop

#### Scenario: Pausing
- **WHEN** the user clicks a playing animation
- **THEN** it stops on the current frame, and a second click plays it on from there
