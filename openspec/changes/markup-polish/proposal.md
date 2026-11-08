# Proposal

## Why

The maintainer tried image markup on 2026-11-08 and found four problems. Marks look pixelated, as PDF marks once did, because they're painted into the image's own pixels for the screen as well as for the file. The strip doesn't show the tools' keys, so they seem missing although they work. Pixelate has one fixed strength, and Spotlight only lights rectangles.

## What Changes

- **Sharp marks:** marks draw over the image at screen resolution, at any zoom. Only Pixelate, which needs the image's pixels, is painted into the shown image. Saving still paints every mark into the file at the image's full resolution, as now.
- **Keys on the strip:** each tool shows its key beside its icon (A, B, T, X, N, P, K, S), as toolbar buttons show theirs.
- **Pixelate strength:** with Pixelate armed or a pixelate mark selected, a Strength slider takes the size control's place, from fine to coarse blocks; the default is today's strength.
- **Spotlight shape:** with Spotlight armed or a spotlight selected, a Rectangle or Oval picker takes the size control's place.
- Strength and shape are remembered like the color and size, and changing either with a mark selected changes that mark.

## Capabilities

### Modified Capabilities

- `image`: markup draws sharply on screen, shows its keys, and gains Pixelate strength and Spotlight's oval.

## Impact

- `Plugins/image/`: `MarkRenderer` splits the pixel part (Pixelate) from the drawn part; a view over the canvas draws marks; `ImageMark`'s pixelate and spotlight cases carry their strength and shape (recovery records from earlier development builds with those marks won't restore; there's no release yet); the strip's keys, slider and picker; the remembered style.
- Print draws the marks over the shown image too, and a marker is drawn over a copy of the image under it, so its multiply blend looks as it will be saved.
- Tests for the renderer, the style, the strip, zooming, printing and the marker; the `image-edit` screen flow checks the Strength slider and the shape picker. CHANGELOG; minor version bump.
