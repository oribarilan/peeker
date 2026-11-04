# Spec Delta

## MODIFIED Requirements

### Requirement: Decodes images at screen size

By default the plugin SHALL open the common image formats macOS can decode (PNG, JPEG, HEIC, HEIF, AVIF, GIF, TIFF, WebP, BMP, ICO, JPEG XL, JPEG 2000, PSD, OpenEXR) and camera RAW formats (such as DNG, CR2, CR3, NEF, ARW, RAF, ORF and RW2), decoding off the main thread. To open, it SHALL decode the first image in the file at no more pixels than the largest connected screen needs, applying the file's orientation. A file that can't be read or decoded SHALL show an error in its tab.

#### Scenario: Photo taken in portrait

- **WHEN** the user opens a JPEG whose orientation tag says it was taken in portrait
- **THEN** it shows upright

#### Scenario: Corrupt image

- **WHEN** the user opens a file named `.png` that isn't a readable image
- **THEN** the tab says the file isn't a readable image

#### Scenario: Opening a large photo

- **WHEN** the user opens a 4000 × 3000 photo on a screen 2560 pixels wide
- **THEN** the image first shown is no larger than the screen needs, whatever its full size

## ADDED Requirements

### Requirement: Sharp when zoomed in

The first time a still image is zoomed past its fitted size, or shown at Actual Size, and the file has more pixels than the screen-size decode, the plugin SHALL decode it at full resolution off the main thread and show that in place of the screen-size picture once ready, at the same place and size. The full decode SHALL be at most 16,384 pixels on the longer side and 100 megapixels, and SHALL be kept until the document closes, or decoded again from the file after a save.

#### Scenario: Actual Size on a large photo

- **WHEN** the user opens a 4000 × 3000 photo and presses Cmd+0
- **THEN** after a moment the window shows the photo's own pixels, one per screen pixel, instead of enlarged screen-size ones

#### Scenario: Zooming in

- **WHEN** the user presses Zoom In on a photo larger than the screen
- **THEN** the full-resolution picture replaces the screen-size one without the view moving or going blank

#### Scenario: A small image

- **WHEN** the user zooms in on a 64 × 64 icon
- **THEN** it isn't decoded again, since the first decode already holds every pixel

#### Scenario: A very large image

- **WHEN** the user zooms in on a 20,000 × 15,000 image
- **THEN** it is decoded again at most 16,384 pixels wide and within 100 megapixels

#### Scenario: Zooming back to fit

- **WHEN** the user zooms in, waits for the sharp picture, then presses Zoom to Fit and zooms in again
- **THEN** the full-resolution picture is still shown and the file isn't decoded a third time

#### Scenario: An animated image

- **WHEN** the user zooms in on an animated GIF
- **THEN** it plays as before and isn't decoded again

### Requirement: Sharp edit previews when zoomed in

Once an image has its full-resolution decode, the Editor SHALL show crop, rotate, flip and resize from it, so edits stay sharp when zoomed. Each edit SHALL show at once from the screen-size decode when the sharp one isn't ready, and the sharp one SHALL replace it only if it still matches the current edits and the file as last loaded or saved.

#### Scenario: Cropping a zoomed photo

- **WHEN** the user presses Cmd+0 on a large photo, waits, then crops it
- **THEN** the cropped image shows at full resolution, not enlarged screen pixels

#### Scenario: Saving while the sharp picture is on its way

- **WHEN** the user crops, saves, and a full decode started before the save finishes after it
- **THEN** the window shows the saved image, never the pixels from before the save

#### Scenario: Undo while the sharp picture is on its way

- **WHEN** the user rotates a zoomed photo and presses Cmd+Z before its sharp preview is ready
- **THEN** the window shows the unrotated photo, and the rotated preview never appears
