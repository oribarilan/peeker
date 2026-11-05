# Spec Delta

## MODIFIED Requirements

### Requirement: Animated images

An image with several frames that its format animates (GIF, animated PNG, WebP, HEIC sequence) SHALL play in a loop with the frame timing its file gives, in the Editor and the Peek panel, unless Reduce Motion is on, when it SHALL open paused on its first frame. A click on the image, or View > Play Animation in a window, SHALL pause it and resume it; the menu item SHALL be checked while it plays. A multi-page TIFF SHALL never play; its pages show as "Multi-page TIFFs show every page" says.

#### Scenario: Playing
- **WHEN** the user opens an animated GIF
- **THEN** its frames play in a loop

#### Scenario: Pausing
- **WHEN** the user clicks a playing animation
- **THEN** it stops on the current frame, and a second click plays it on from there

#### Scenario: Reduce Motion
- **WHEN** Reduce Motion is on and the user opens an animated GIF
- **THEN** it shows its first frame without playing, until the user clicks it or chooses View > Play Animation

#### Scenario: From the View menu
- **WHEN** an animated GIF plays in a window and the user chooses View > Play Animation
- **THEN** it pauses and the menu item is no longer checked; choosing it again plays it on
