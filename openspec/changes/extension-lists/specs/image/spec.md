# Spec Delta

## MODIFIED Requirements

### Requirement: Decodes images at screen size

By default the plugin SHALL open the common image formats macOS can decode (PNG, JPEG, HEIC, HEIF, AVIF, GIF, TIFF, WebP, BMP, ICO, JPEG XL, JPEG 2000, PSD, OpenEXR) and camera RAW formats (such as DNG, CR2, CR3, NEF, ARW, RAF, ORF and RW2), decoding off the main thread. It SHALL decode the first image in the file, at no more pixels than the largest connected screen needs, applying the file's orientation. A file that can't be read or decoded SHALL show an error in its tab.

#### Scenario: Photo taken in portrait

- **WHEN** the user opens a JPEG whose orientation tag says it was taken in portrait
- **THEN** it shows upright

#### Scenario: Corrupt image

- **WHEN** the user opens a file named `.png` that isn't a readable image
- **THEN** the tab says the file isn't a readable image
