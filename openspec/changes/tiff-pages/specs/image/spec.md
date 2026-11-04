# Spec Delta

## ADDED Requirements

### Requirement: Multi-page TIFFs show every page

In the Editor, a TIFF with more than one page SHALL show one page at a time, with a thumbnail of every page in the sidebar, the page shown selected. A click on a thumbnail SHALL show that page. The Peek panel SHALL show the first page.

#### Scenario: Thumbnails
- **WHEN** the user opens a five-page TIFF in the Editor
- **THEN** the first page shows, and the sidebar has five thumbnails with the first selected

#### Scenario: A click on a thumbnail
- **WHEN** the user clicks the fourth thumbnail
- **THEN** the fourth page shows

#### Scenario: In the Peek panel
- **WHEN** the user presses Space on a multi-page TIFF in Finder
- **THEN** the Peek panel shows its first page

### Requirement: Moving between TIFF pages

Next Page and Previous Page (Page Down and Page Up), view tools listed only for a multi-page TIFF, SHALL move one page and do nothing past the first or last. Moving to a page SHALL keep the zoom mode: fit stays fit, and another zoom keeps its magnification, scrolled to the top left.

#### Scenario: Next page
- **WHEN** the first page of a multi-page TIFF shows and the user presses Page Down
- **THEN** the second page shows and its thumbnail is selected

#### Scenario: Zoom carries over
- **WHEN** the user zooms a page to about 156% of fit and presses Page Down
- **THEN** the next page shows at the same magnification, scrolled to its top left

#### Scenario: A single image has no page tools
- **WHEN** the user opens a one-page TIFF or a JPEG
- **THEN** the View menu has no Next Page or Previous Page and the sidebar has no thumbnails

## MODIFIED Requirements

### Requirement: Image details in the sidebar

The sidebar SHALL show the details the file has: dimensions, kind, color model, color profile, resolution, camera, lens, the date it was taken, and file size. For a multi-page TIFF the details SHALL be the page shown, with which page of how many, and SHALL follow the page as it changes.

#### Scenario: iPhone photo

- **WHEN** the user opens a HEIC photo from an iPhone
- **THEN** the sidebar shows its dimensions, the camera model, the lens and when it was taken

#### Scenario: A page of a TIFF

- **WHEN** the third page of a five-page TIFF shows
- **THEN** the sidebar says page 3 of 5 and gives that page's dimensions

### Requirement: Print an image

Printing an image SHALL print it on one page, centered, at its own size as given by its pixel dimensions and resolution (72 pixels per inch when the file states none), shrunk to fit the printable area when larger and never enlarged. The print panel SHALL start in landscape for an image wider than it is tall and in portrait otherwise, and the image SHALL print upright as it is shown. A multi-page TIFF SHALL print every page, each on a sheet of its own by the same rules, the orientation following the first page.

#### Scenario: A large photo
- **WHEN** the user prints a 4000 × 3000 pixel photo
- **THEN** the print panel starts in landscape and the photo fills the printable area's width or height, centered

#### Scenario: A small icon
- **WHEN** the user prints a 64 × 64 pixel icon with no resolution set
- **THEN** it prints centered at 64 × 64 points, not enlarged

#### Scenario: A rotated photo
- **WHEN** the photo's file says it was taken rotated
- **THEN** it prints upright, as the window shows it

#### Scenario: A multi-page TIFF
- **WHEN** the user prints a three-page TIFF while its second page shows
- **THEN** the print panel offers three sheets, one per page

### Requirement: Animated images

An image with several frames that its format animates (GIF, animated PNG, WebP, HEIC sequence) SHALL play in a loop with the frame timing its file gives, in the Editor and the Peek panel. A click on the image SHALL pause it and another click resume it. A multi-page TIFF SHALL never play; its pages show as "Multi-page TIFFs show every page" says.

#### Scenario: Playing
- **WHEN** the user opens an animated GIF
- **THEN** its frames play in a loop

#### Scenario: Pausing
- **WHEN** the user clicks a playing animation
- **THEN** it stops on the current frame, and a second click plays it on from there
