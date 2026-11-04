# Design

## Context

See proposal.md for why. `ImagePlugin.decode` (`Plugins/image/ImagePlugin.swift`) makes one decode with `CGImageSourceCreateThumbnailAtIndex`, capped at `min(maxPixels, maxDimension)` on the longer side, where `maxPixels` is the largest screen's longer side in pixels (`DocumentViewController.maxPixels`) and `maxDimension` is 16,384. `displayReady` then redraws it into premultiplied sRGB so Core Animation draws it without converting on the main thread. `ImageDocument` keeps that decode as `base`, the full size as `baseSize`, and shows `ImageEditing.preview(edits, of: base, fullSize: baseSize)` in `ImageCanvas`, whose layer scales its contents with `.resizeAspect` to fit the canvas. Magnification 1 on the scroll view is fit. Zooming never changes the canvas's frame; only the scroll view's magnification. The Peek panel uses the same `ImageDocument` with no zoom commands wired to keys.

## Goals / Non-Goals

**Goals:**
- No extra work on the open path, so the open benchmark doesn't move.
- One rule for when the full decode starts, whatever zoomed the view (menu, shortcut, pinch).

**Non-Goals:**
- Tiled or progressive decoding (decoding only the visible region at each zoom level).
- Freeing the full decode on zoom back to fit or under memory pressure.
- Sharper printing as a goal. Printing draws whatever the canvas holds, so it gets the full decode when one exists, with no change to the print code.
- Animated images (`AnimationPlayer` already draws full frames) and multi-page TIFFs.

## Decisions

### A second decode that shares the open path's code

`decode` keeps its signature and result. Its thumbnail-and-`displayReady` step moves into a private helper both decodes call, so the full one gets the same orientation handling (properties read before the thumbnail, for the PNG quirk noted there) and the same pixel layout. A new `@concurrent nonisolated static func decodeFull(_ url: URL, pixelSize: CGSize) async throws(PluginError) -> CGImage` asks for `fullSide(for: pixelSize)` on the longer side: the longer side itself, capped at `maxDimension` and scaled down so width times height stays within `maxEditablePixels` (100 MP). `fullSide` is a pure static function with its own tests. The 100 MP cap reuses the limit above which editing is already refused for memory, so the worst case is about 400 MB held, plus the same again for a moment while `displayReady` redraws.

Alternative: decode with `CGImageSourceCreateImageAtIndex` for the true full image. Rejected: it ignores the caps, and the thumbnail call with the same options keeps the two decodes identical apart from size.

### When it starts

`ImageDocument.sharpenIfNeeded()` runs after `zoom-in` and `zoom-actual` in `perform(_:)`, and on `NSScrollView.didEndLiveMagnifyNotification` for pinch, and acts only when all hold: the scroll view's magnification is above 1 (Actual Size counts whatever its magnification, since it shows image pixels one to one); the image isn't animated; no full decode is held or running; and the screen-size decode is smaller than `fullSide(for: baseSize)` on its longer side. The last check is what keeps small images from decoding twice.

Alternative: start it when the open finishes, idle. Rejected: every open would pay the memory, and the Peek panel opens many files in a row.

### Swapping it in

The decode runs in a `Task` the document holds as `sharpening` (internal, so tests can await it), capturing the document weakly. Back on the main actor it clears `sharpening`, stores the result as `full` and calls `redraw()`, which now draws `ImageEditing.preview(edits, of: full ?? base, fullSize: baseSize)`. The canvas frame and the image's aspect are unchanged, so nothing moves: `imageRect` comes from the aspect ratio, which differs between the two decodes by less than one screen-decode pixel, and the crop overlay stores its rectangle as fractions. `preview` already scales a resize from whatever decode it gets, so it works on `full` unchanged.

Edit previews use `full` synchronously on the main thread, as they use `base` today. On a laptop screen a 12 MP photo's full decode is under twice the screen decode's pixels, so the cost stays close to today's; task 2.4 measures a 48 MP rotate before relying on it.

Alternative: apply edits to `full` in the background and swap again after each edit. Rejected for now: each edit would first flash the blurry preview, and it adds a second stale-result check per edit.

### Dropping stale results

A `generation` counter goes up on each save. A finished decode whose generation doesn't match is thrown away. Undo, redo and new edits need no check, since `redraw()` always applies the current edits. A save also cancels a running decode, drops `full` and, when the view is past fit, starts a new decode of the saved file; until it lands the window shows the screen-size preview, as today. `deinit` cancels `sharpening`, so a closed tab's decode stops at the next cancellation check and never touches the gone document.

Alternative: on save, apply the saved edits to `full` as is done to `base`. Rejected: an in-flight decode of the old file would still need the generation check, so the counter is needed either way, and re-decoding keeps one source of truth, the file.

### Memory

`full` is kept until the document closes. `base` stays too; it's small next to `full` and keeps the save path unchanged. Zooming back to fit keeps `full`, so zooming in again costs nothing.

## Risks / Trade-offs

- [Edit previews on a 48 to 100 MP image may take hundreds of milliseconds on the main thread once `full` exists] → Task 2.4 measures it. If a 48 MP rotate preview takes over 100 ms, stop and bring the numbers to the maintainer before moving previews off the main thread. Measured on an Apple M6 in a Release build: a rotate preview of an 8000 × 6000 full decode took 113 to 141 ms (the first of each run up to 162 ms), against 11 to 18 ms from a 3024-pixel screen decode. That is over the 100 ms line, so moving previews off the main thread is the maintainer's call.
- [A brief blurry moment after a save while zoomed in, until the saved file decodes again] → Same as today's whole zoomed experience, and only after a save.
- [Up to about 800 MB at the peak of one 100 MP full decode] → The same limit editing already accepts; images above it decode at the capped size.
- [Pinch in the Peek panel] → The panel has no zoom commands. If it receives pinch, the same notification starts the decode; either way nothing changes for opening in the panel. Effectively the change applies to Editor windows.
- [`didEndLiveMagnifyNotification` fires only at the end of a pinch] → The sharp picture arrives a moment after the fingers lift, which matches the swap-when-ready behavior anyway.
