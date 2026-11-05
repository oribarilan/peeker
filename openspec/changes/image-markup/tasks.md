# Tasks

## 1. Model and saving

- [x] 1.1 Failing tests: `ImageMark` kinds round-trip through recovery JSON and are validated (fractions in range, strings and point counts capped); step numbers follow order; crop, turn, flip and resize map marks, and a crop removes marks wholly outside it.
- [x] 1.2 `ImageMark`, the mark edits in `ImageEdit`, and the mapping; verify the tests pass.
- [x] 1.3 Failing tests: `MarkRenderer` draws each kind (pixels sampled on a small canvas: arrow and box in the color, plain text with outline, label fill, pixelate blocks uniform, spotlight dims outside); sizes scale with the image.
- [x] 1.4 `MarkRenderer`; verify.
- [x] 1.5 Failing tests: saving draws marks at full resolution in the file's format with its metadata; Undo past a save; moving a saved mark and saving again leaves no trace of the old place; a JPEG saved twice is encoded from the opened bytes.
- [x] 1.6 Keep the opened bytes in `ImageDocument`, draw saves from them, stop clearing Undo at save; `ImageSaving` draws marks.

## 2. Tools and interaction

- [x] 2.1 Tool specs: Markup (M, tip) in the toolbar; the eight tools with their keys, out of the toolbar; greyed with the edit reason; none in the Peek panel. Tests for the lists and keys.
- [x] 2.2 The strip: tools, swatches, More…, S/M/L; style remembered in `PluginPreferences` (add `string`), validated; picking with a selection changes the mark. Tests.
- [x] 2.3 The overlay: draw each kind by dragging (click for steps and text), select, move, resize handles, arrow endpoints, Delete, Escape, double-click to edit text; one edit per gesture. Tests with synthetic mouse events.
- [x] 2.4 Copy and paste: image to the pasteboard as PNG and TIFF; a mark in a private type; paste offset. Tests.

## 3. Checks and docs

- [ ] 3.1 `scripts/build.sh test` passes with no warnings; benchmark open isn't slower (`scripts/bench-ab.sh`).
- [ ] 3.2 Screen step in `image-edit-flow.sh`: Markup, an arrow and a pixelate drawn, saved, the file changed and kept its size, Preview opens it; screenshots in light and dark. Copy stays a unit test (on a pasteboard of its own), since a run never touches the clipboard.
- [x] 3.3 CHANGELOG, `openspec validate --all --strict`.

## Workflow follow-up

- Commit the change, then bump the minor version in its own commit; archive.
