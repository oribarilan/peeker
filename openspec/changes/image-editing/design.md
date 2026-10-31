# Design

## Context

The image plugin decodes the first image at most screen size (upright, premultiplied sRGB) and shows it in a layer-backed view inside a magnifying scroll view. It has no save path and no edit mode. The host already has Edit mode (`EditMode`, `setEditing`, edit tools shown in the toolbar only while editing, a read-view tool shortcut turning Edit mode on), safe writes (`FileReplacement`), recovery and the save prompts. ImageIO on macOS 27 writes JPEG, PNG, GIF, TIFF, JPEG 2000, HEIC, AVIF, BMP, ICO, ICNS, PSD, EXR, TGA and a few texture formats. It doesn't write WebP, JPEG XL or camera RAW.

## Goals / Non-Goals

**Goals:**
- Crop, rotate, flip and resize, saved at full resolution in the file's own format, with metadata kept.
- Rotation and flips alone stay lossless.
- Opening stays as fast; the tools load with Edit mode.

**Non-Goals:**
- Markup, crop ratios, color adjustments, Save As.
- Editing several frames.
- Keeping PSD layers or EXR's float data: those formats can't be edited.

## Decisions

**The unsaved state is the list of edits.** `ImageEdit` is one of:
- `.rotate(by:)`, ±90
- `.flip(horizontal:)`
- `.crop(CGRect)`: normalized 0…1, in the image as it looks after the edits before it
- `.resize(width:height:)`: in pixels

The view's image is the screen-size decode with the list applied, recomputed after each change. That's cheap at screen size. Undo and redo register the list before and after, so there are no hand-written inverses. Saving writes the list, then makes the result the new starting point and clears the undo history: once a crop is in the file its pixels are gone, so unlike PDF edits, image undo stops at a save. Recovery encodes the list. Considered: inverse edits as in the PDF plugin. That's more code here, and a crop has no inverse without the pixels.

**Saving.** Off the main thread, on the file as it is on disk:
- **Only rotations and flips, on a JPEG, HEIC or TIFF:** compose them with the file's orientation and copy the image source with the new `kCGImagePropertyOrientation` (`CGImageDestinationCopyImageSource`). The image data isn't re-encoded. If the copy fails, fall back to the pixel path. Lossless formats (PNG, GIF, BMP) always take the pixel path, which loses nothing for them and doesn't depend on apps reading an orientation tag in a PNG.
- **Otherwise:** decode the full image at its own bit depth, draw it upright, and apply the edits:
  - A crop uses `CGImage.cropping(to:)`, so no pixels are resampled.
  - Rotations, flips and resizes draw into a context with the same bits per component, color space and alpha, with high interpolation.
  - Write it with the source's properties, orientation reset to 1 and the pixel size updated, no embedded thumbnail, and JPEG or HEIC lossy quality 0.9.

Either way the data goes through `FileReplacement`, so permissions and symlinks are kept, and nothing is written on failure. A 100-megapixel limit keeps the full decode and one working copy under about 1 GB at 16 bits per channel.

**Which images can be edited** is decided at open from the properties the info panel already reads:
- the type is JPEG, PNG, GIF, TIFF, HEIC, AVIF, BMP or JPEG 2000
- one frame
- at most 100 megapixels
- not floating point

Otherwise `editMode` is `.unavailable` with one of three sentences:
- "Peeker can't save this format."
- "This image has several frames."
- "This image is too large to edit."

In the Space panel it's `.none`.

**Single-key shortcuts (host).** AppKit menus take key equivalents without modifiers, but using one would swallow letters typed in text fields. So a bare-key command gets no key equivalent in the menu. `DocumentWindowController` installs a local key-down monitor for its window. A key with no Command, Option or Control runs the matching command, but only when:
- the document is in Edit mode
- the command is an edit tool with that single-key shortcut
- the first responder isn't an `NSText` or `NSTextView`

The menu item's title shows the key, as in "Crop (C)". The Settings recorder gets a third rule, `.editTool`, that also accepts a single letter or digit. The image plugin's default shortcuts are `c` for Crop and `cmd+r` for Rotate & Resize.

**Crop overlay.** An `NSView` subview of the image view, made when cropping starts, in the image view's coordinates, so it zooms with it. It maps between view points and normalized image coordinates through the aspect-fit rectangle.
- Dragging from empty space draws a rectangle. Dragging inside moves it, and dragging a corner or edge resizes it, clamped to the image.
- It dims the outside, draws handles and a label with the size in pixels: the normalized size times the full image's pixel size after the earlier edits, which the document tracks.
- Return records `.crop` and Escape cancels. Leaving Edit mode or another tool cancels too.

**Rotate & Resize panel.** An `NSPopover` anchored to the top of the image.
- Four buttons, which L, R, H and V also press through the popover's key handling while no field is focused.
- Width and height fields with a pixels-or-percent popup and an aspect-lock toggle, and an Apply button (Return in a field).
- Each button press and each Apply is one edit. Escape closes the panel.

## Risks / Trade-offs

- **HEIC and AVIF re-encoding** loses a little quality, as in Preview. Only rotations and flips avoid it.
- **Orientation-only saves** depend on apps honoring the orientation tag. Nearly all do, and the choice was the maintainer's.
- **Partly transparent pixels** go through a premultiplied bitmap context on the pixel path. Core Graphics has no other kind, so a rotated PNG's half-transparent pixels can shift by a rounding step. They look the same once drawn.
- **Enlarging** is capped at the 100-megapixel editing limit, and the window shows an enlarged image no bigger than its first decode, so the screen stays cheap.
- **An undo during a save** drops what changed under it: the file has the saved edits, and the window starts from them.
- **HDR photos:** the pixel path most likely drops an HEIC's or JPEG's HDR gain map and other auxiliary images, so a cropped HDR photo saves as standard range. Not verified; worth a look before markup.
- **Pressing C while cropping** starts over and drops the rectangle chosen so far.
- **Metadata:** GPS and other EXIF are kept. Embedded thumbnails are dropped, since they would show the old image.
- **The local key monitor** sees every key for the window. It only acts on bare keys in Edit mode outside text, and returns the event otherwise.
