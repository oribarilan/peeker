# Spec Delta

## RENAMED Requirements

- FROM: `### Requirement: Decodes images outside the app`
- TO: `### Requirement: Decodes images at screen size`

## MODIFIED Requirements

### Requirement: Decodes images at screen size

The plugin SHALL open every image type macOS can decode (PNG, JPEG, HEIC, TIFF, GIF and the rest of `public.image`), decoding off the main thread. It SHALL decode the first image in the file, at no more pixels than the largest connected screen needs, applying the file's orientation. A file that can't be read or decoded SHALL show an error in its tab.

#### Scenario: Photo taken in portrait

- **WHEN** the user opens a JPEG whose orientation tag says it was taken in portrait
- **THEN** it shows upright

#### Scenario: Corrupt image

- **WHEN** the user opens a file named `.png` that isn't a readable image
- **THEN** the tab says the file isn't a readable image
