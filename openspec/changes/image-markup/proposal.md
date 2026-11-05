# Proposal

## Why

Peeker opens screenshots but can't mark them up, so pointing at something in a screenshot means another app. The maintainer wants Shottr-style markup in the image Editor, and chose its shape in an interview (2026-11-05): a strip of tools under the toolbar, marks that stay movable until the window closes, and a copy of the marked image one keystroke away.

## What Changes

- A Markup button (M) in an image window's toolbar shows a strip under the toolbar with the tools, each with its own key: Arrow (A), Box (B; ellipse with Option held), Text (T), Pixelate (X), Steps (N), Pen (P), Marker (K) and Spotlight (S).
- Text is plain, with a thin outline for contrast, or a label: white text on a filled rounded box. Steps drop numbered badges that renumber when one is deleted. Pixelate hides a rectangle in blocks too coarse to read back. Spotlight dims everything outside its boxes; there can be several.
- One color (six swatches and More… for the system color picker) and one size (S, M, L, scaled to the image) for every tool, remembered across launches. Picking either with a mark selected changes that mark.
- Marks can be selected, moved, resized and deleted until the window closes, saved or not, and Undo reaches past saves. Saving writes plain pixels in the file's own format, drawn from the file as it opened, so a JPEG is never re-compressed over itself.
- Crop and Rotate & Resize after marking move the marks with the image.
- Cmd+C with no mark selected copies the whole marked image; with a mark selected, it copies the mark, and Cmd+V pastes a copy of it.
- Markup is greyed out, with the reason, where editing already is: animated images, multi-page TIFFs, formats Peeker can't save. The Peek panel has none.
- **BREAKING (behavior):** image Undo no longer stops at a save.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `image`: markup tools; saving and Undo across saves; Copy.

## Impact

- New in `Plugins/image/`: the mark model and its edits, a renderer shared by the screen and the save, the strip, the interaction overlay (select, move, resize, text editing), the copy and paste of marks.
- `ImageDocument` (tools, edits with marks, Undo past saves, keeping the opened file's bytes), `ImageSaving` (drawing marks at full resolution), `ImagePlugin` (tool specs, tips).
- `PluginPreferences` gains strings, for the remembered color.
- Tests per tool, for saving, Undo, crop with marks, copy; an image-edit screen step; CHANGELOG; minor version bump.
