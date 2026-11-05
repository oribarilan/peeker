# Design

## Context

`ImageDocument` shows the image as a layer in `ImageCanvas` inside a magnifying scroll view, so canvas coordinates don't change with zoom. Edits are an ordered `[ImageEdit]` (rotate, flip, crop in fractions, resize) with whole-list Undo on the document's own `UndoManager`; a save writes them through `ImageSaving` (full decode, redraw, the source's metadata, `FileReplacement`), burns them into the base and clears Undo. Crop is an overlay subview that takes mouse events; Rotate & Resize is a popover whose L, R, H, V keys run after the host's single-key monitor. The PDF plugin's `EditController` already selects, moves, resizes and deletes marks with one recorded edit per gesture.

## Goals / Non-Goals

**Goals:** the eight tools, editable marks until close, Undo past saves, pixels on disk, Copy. **Non-goals:** markup in PDFs (their highlight stays), layers, blur (pixelate only), keyboard-only drawing (A1 in the backlog).

## Decisions

**Marks are data on top of the edits.** `ImageMark { id, kind, color: RGBA, size: S/M/L }`, with kinds arrow(from, to), box(rect, ellipse), text(origin, string, label), pixelate(rect), step(center), pen(points), marker(points), spotlight(rect), all in fractions of the image as the edits leave it. Step numbers come from order, so a delete renumbers. `ImageEdit` gains add, change and remove of a mark, so marks share the edit list's Undo, recovery and pending state. A crop, turn, flip or resize after marks maps their fractions; a mark wholly outside a crop is removed by that crop and comes back with Undo.

**One renderer for screen and file.** `MarkRenderer.draw(_ marks:, in: CGContext, imageSize:, image:)` draws with Core Graphics; the canvas draws it over the screen-size image in a layer above the picture, and `ImageSaving` draws it over the full-resolution image. Sizes scale with the image's shorter side (strokes at 0.4, 0.8, 1.4 percent; text at 2.5, 4, 6 percent), so a mark looks the same at any zoom and on any image. Pixelate reads the pixels under it from the image it's drawn on and averages blocks of at least 1/60 of the shorter side, so the saved file can't be read back. Spotlight fills the image with 50 percent black outside the union of its boxes.

**Saves draw from the file as it opened.** The document keeps the opened file's bytes (compressed, so small) and every save decodes them, applies all edits and marks, and writes. Undo then reaches past saves, a saved mark can still move, and a JPEG is re-encoded once per save from the original, not from its last save. A change on disk by someone else, reloaded, replaces the bytes. Save As keeps them.

**The strip is the plugin's.** A bar at the top of the image's content view (as the PDF find bar sits above its pages), below the toolbar's edge: the tool buttons with their keys, the six swatches and More…, and an S/M/L control. Markup (M, a toolbar edit tool with a first-use tip) shows and hides it; choosing a tool or pressing its key shows it too. Letters avoid C (Crop) and L, R, H, V (the Rotate & Resize popover's keys).

**Interaction mirrors the PDF marks.** An overlay over the canvas takes clicks while a tool is armed or a mark is selected: drag to draw, click a mark to select it, drag to move, handles to resize a box, pixelate or spotlight, endpoints for an arrow, Delete removes, Escape deselects or cancels a drag, double-click edits text in a field at the mark. One edit per gesture.

**Remembered style.** Color and size live in `PluginPreferences` (`markupColor` as a hex string, `markupSize`), validated on read.

**Copy and paste.** With no mark selected, Cmd+C writes the image with edits and marks at full resolution as PNG and TIFF to the pasteboard; with a mark selected, the mark in a private pasteboard type, which Cmd+V adds again, offset a little.

## Risks / Trade-offs

- [Keeping the opened bytes costs memory] → compressed, so a few MB for a photo, at most the file's size.
- [Undo past saves differs from today's image behavior] → it now matches PDF and text.
- [Many pen strokes slow the overlay] → points thinned while drawing; one path per stroke.
