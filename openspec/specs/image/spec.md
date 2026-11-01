# image Specification

## Purpose

The Image plugin: show photos and other images faster than Preview, fitted to the window, with zoom and the image's details in the sidebar. Viewing only for now.

## Requirements

### Requirement: Decodes images at screen size

By default the plugin SHALL open the common image formats macOS can decode (PNG, JPEG, HEIC, HEIF, AVIF, GIF, TIFF, WebP, BMP, ICO, JPEG XL, JPEG 2000, PSD, OpenEXR) and camera RAW formats (such as DNG, CR2, CR3, NEF, ARW, RAF, ORF and RW2), decoding off the main thread. It SHALL decode the first image in the file, at no more pixels than the largest connected screen needs, applying the file's orientation. A file that can't be read or decoded SHALL show an error in its tab.

#### Scenario: Photo taken in portrait

- **WHEN** the user opens a JPEG whose orientation tag says it was taken in portrait
- **THEN** it shows upright

#### Scenario: Corrupt image

- **WHEN** the user opens a file named `.png` that isn't a readable image
- **THEN** the tab says the file isn't a readable image

### Requirement: Shows the image fitted, with zoom

The image SHALL appear fitted to the window, keeping its aspect ratio and resizing with the window. Zoom In and Zoom Out (Cmd+= and Cmd+-) SHALL scale it by 25% per step and pinch SHALL zoom too, between fit and 16 times fit. Zoom to Fit (Cmd+9) SHALL return to fit.

#### Scenario: Zooming into a corner

- **WHEN** the user presses Cmd+= twice on a photo
- **THEN** the image is about 1.56 times its fitted size and can be scrolled

### Requirement: Image details in the sidebar

The sidebar SHALL show the details the file has: dimensions, kind, color model, color profile, resolution, camera, lens, the date it was taken, and file size.

#### Scenario: iPhone photo

- **WHEN** the user opens a HEIC photo from an iPhone
- **THEN** the sidebar shows its dimensions, the camera model, the lens and when it was taken

### Requirement: Opening images beats Preview

Opening an image with the app not running SHALL draw it no later than Preview shows its window for the same file: faster, or within 10%. The benchmark measures this on a 512×512 PNG, 12 MP JPEG and HEIC photos, and a 48 MP PNG.

#### Scenario: 48 MP PNG

- **WHEN** the benchmark opens the 48 MP PNG fixture in Peeker and in Preview
- **THEN** Peeker's content time is lower than Preview's window time, or at most 10% higher

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

### Requirement: Print an image

Printing an image SHALL print it on one page, centered, at its own size as given by its pixel dimensions and resolution (72 pixels per inch when the file states none), shrunk to fit the printable area when larger and never enlarged. The print panel SHALL start in landscape for an image wider than it is tall and in portrait otherwise, and the image SHALL print upright as it is shown.

#### Scenario: A large photo
- **WHEN** the user prints a 4000 × 3000 pixel photo
- **THEN** the print panel starts in landscape and the photo fills the printable area's width or height, centered

#### Scenario: A small icon
- **WHEN** the user prints a 64 × 64 pixel icon with no resolution set
- **THEN** it prints centered at 64 × 64 points, not enlarged

#### Scenario: A rotated photo
- **WHEN** the photo's file says it was taken rotated
- **THEN** it prints upright, as the window shows it

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
