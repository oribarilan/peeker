# Proposal

## Why

Images are decoded only at the size the largest screen needs, so zooming in past fit, or Actual Size on a photo larger than the screen, shows upscaled, blurry pixels (listed in openspec/gaps.md under "Missing next to Preview"). Preview shows the photo's real pixels there.

## What Changes

- Opening stays exactly as today: the first decode is at screen size, with the same speed and memory.
- The first time the user zooms past the fitted size, or chooses Actual Size, the plugin decodes the image at full resolution in the background and swaps it in when it's ready. The screen-size picture stays until then, and nothing moves or flickers when the sharp one replaces it.
- Edit previews (crop, rotate, flip, resize) come from the full-resolution decode once it exists, so they stay sharp when zoomed. Saving is unchanged; it already re-reads the file at full size.
- The full decode is capped at 16,384 pixels on the longer side and at 100 megapixels, so a huge image gets as sharp as Peeker can afford rather than its full size.
- Images whose screen-size decode already holds every pixel (smaller than the screen) never decode twice. Animated images and multi-page TIFFs are left as they are.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `image`: "Decodes images at screen size" becomes a decode at screen size to open, then at full resolution on the first zoom past fit or Actual Size.

## Impact

- `Plugins/image/ImagePlugin.swift` (a second, full-resolution decode sharing the open path's code) and `Plugins/image/ImageDocument.swift` (when to start it, swapping it in, edit previews from it, dropping stale results).
- Memory: a 12 MP photo holds about 48 MB more once zoomed, until its tab closes. Opening is unchanged, so the open benchmark must show no change.
- Tests in `Tests/ImageDocumentTests.swift` and `Tests/ImagePluginTests.swift`, a check in the viewer screen flow, CHANGELOG, openspec/gaps.md, and the version goes to `0.6.2-dev` (a fix).
