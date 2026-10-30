# image Specification

## Purpose

The Image plugin: show photos and other images faster than Preview, fitted to the window, with zoom and the image's details in the sidebar. Viewing only for now.

## Requirements

### Requirement: Decodes images outside the app

The plugin SHALL open every image type macOS can decode (PNG, JPEG, HEIC, TIFF, GIF and the rest of `public.image`), decoding in its own process and handing the host finished pixels, so a malformed image can crash only the plugin. It SHALL decode the first image in the file, at no more pixels than the largest connected screen needs, applying the file's orientation. A file that can't be read or decoded SHALL show an error in its tab.

#### Scenario: Photo taken in portrait

- **WHEN** the user opens a JPEG whose orientation tag says it was taken in portrait
- **THEN** it shows upright

#### Scenario: Corrupt image

- **WHEN** the user opens a file named `.png` that isn't a readable image
- **THEN** the tab says the file isn't a readable image, and the app keeps running

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
