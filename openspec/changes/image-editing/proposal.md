# Proposal

## Why

Cropping a screenshot, turning a sideways photo or shrinking an image to send are the image chores that still need Preview. Image editing is the last item on the roadmap. Decided in an interview on 2026-10-31.

## What Changes

- Images get Edit mode, like PDFs: they open in a read view that never changes the file, and the Edit button or Cmd+E turns Edit mode on.
- **Crop:** C in Edit mode. Drag a rectangle; handles adjust it, the size in pixels shows beside it, and the outside is dimmed. Return applies, Escape cancels.
- **Rotate & Resize:** Cmd+R opens a small panel. Its buttons rotate left or right and flip horizontally or vertically, and also answer L, R, H and V while it's open. Width and height fields take pixels or percent, with an aspect lock on by default. From the read view, Cmd+R turns Edit mode on first.
- Single letters are otherwise kept free for future markup tools.
- **Saving:**
  - Cmd+S writes the same file in its own format and keeps its metadata, updating the size and orientation.
  - JPEG and HEIC are re-encoded at high quality. When the only edits are rotations and flips, only the orientation tag changes, so no quality is lost.
  - Edits apply to the full-resolution image.
  - Undo, the recovery copy and the question on close work as for other edits.
- **Edit greyed out, with the reason, for:** formats macOS can't write or Peeker would flatten (camera RAW, WebP, JPEG XL, PSD, EXR and others), images with several frames, and images over 100 megapixels.
- **Host:** an edit tool's shortcut may be a single key. It works only in Edit mode, and not while typing in a text field. Settings accepts single keys for edit tools.
- Not included: markup, fixed crop ratios, color adjustments, Save As.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `image`: Edit mode with crop, rotate, flip and resize, and saving.
- `plugin-host`: single-key shortcuts for edit tools.

## Impact

- `Sources/Host/Documents/DocumentWindowController.swift`: runs single-key shortcuts in Edit mode.
- `Sources/Host/Settings/KeyRecorder.swift` and the plugin pane: edit tools accept single keys.
- `Plugins/image/`:
  - New files for the edit model and saving, the crop overlay and the Rotate & Resize panel.
  - `ImagePlugin` decides whether a file can be edited.
  - `ImageDocument` gains editing.
- Opening stays as fast: the edit check reuses the properties already read, and the tools are made only when Edit mode turns on.
