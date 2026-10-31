# Tasks

## 1. Host single-key shortcuts

- [x] 1.1 Run single-key shortcuts of edit tools from a key monitor on the document window (Edit mode only, not while a text view has focus), leave them out of the menu's key equivalents and show the key in the item's title; verify with tests using a stub document: a bare key runs its tool in Edit mode, does nothing in the read view, and passes through while a text view has focus
- [x] 1.2 Add the `.editTool` recorder rule that accepts single keys, used for edit tools in the plugin pane; verify with tests of `refusal(for:)` for each rule

## 2. Edit model and saving

- [x] 2.1 Add `ImageEdit` (Codable) and applying a list to a `CGImage` (rotate, flip, crop in normalized coordinates, resize), plus the pixel size after a list; verify with tests on generated images: size and corner colors after each edit and after a combination
- [x] 2.2 Add saving: orientation-only when every edit is a rotation or flip (falling back to pixels), otherwise full-resolution pixels at the source's bit depth with metadata kept, orientation 1, size updated, JPEG and HEIC at quality 0.9, written through `FileReplacement`; verify with tests: a rotated JPEG keeps its image data and gets the new orientation, a crop of a 400 × 300 JPEG with EXIF saves as 200 × 300 with the EXIF kept, a 16-bit PNG stays 16-bit, an oriented (6) photo crops in its upright frame

## 3. Document and editability

- [x] 3.1 Decide editability at open (type, frames, 100 MP, float) and give `ImageDocument` Edit mode: the list of edits, the view redrawn from it, undo and redo, unsaved edits, restore, save and revert; verify with tests: each reason (DNG-like unwritable type, animated GIF, too large), an editable PNG reports `.available` and `.none` in the Space panel, undo and redo restore the view's size, recovery reapplies edits, save writes the file and clears the edits
- [x] 3.2 Add the commands Crop (`c`) and Rotate & Resize (`cmd+r`) as edit tools; verify with a test of `ImagePlugin.commands`

## 4. Tools

- [x] 4.1 Add the crop overlay: drag, move, resize by handles, clamped, outside dimmed, size label in full-image pixels, Return records `.crop`, Escape and leaving Edit mode cancel; verify with tests of the view-to-image mapping and clamping, and that Return records the crop and Escape records nothing
- [x] 4.2 Add the Rotate & Resize popover: four buttons answering L, R, H, V, width and height in pixels or percent with the aspect lock, Apply records `.resize`, Escape closes; verify with tests: each key records its edit, a 50 percent width with the lock gives half of both sides, the lock off keeps the height

## 5. Wrap-up

- [x] 5.1 Update the README's image line, the roadmap in `openspec/config.yaml` and `openspec/gaps.md`; verify `openspec validate --all --strict` passes
- [x] 5.2 Run `scripts/build.sh test` and `scripts/check-plugin-imports.sh`; verify all tests pass and the build has no warnings
- [ ] 5.3 In the built app (needs the maintainer's hands-off go): crop, rotate, flip and resize a photo, save, and check it in Preview with its metadata; verify by screenshots

## Workflow follow-up

- Archive after the earlier changes.
- `scripts/bench-ab.sh main` with the maintainer's go, to confirm opening an image is unchanged.
