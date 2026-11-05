# Proposal

## Why

Rotating or deleting a PDF page in a window changes it in a single frame: the page jumps to its new shape or vanishes, and the eye has to work out what happened. A short motion shows it. The maintainer asked for small, playful animations, saw this one recorded in light, dark and with Reduce Motion, and chose to keep it.

## What Changes

- In a window, a rotated page turns into its new position, a deleted page shrinks and fades away, and a page brought back (undoing a delete) grows into place. Each takes 0.2 s.
- The edit itself is applied at once: the animation plays on images of the pages laid over them, so nothing waits for it and clicks go through.
- Nothing moves with Reduce Motion on, for pages scrolled off screen, or for edits applied while a document opens (recovered edits).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `pdf`: page edits in a window animate into place.

## Impact

- New `Plugins/pdf/PageMotion.swift`; `PDFPluginDocument.applyLive` takes images before an edit and plays them after.
- Tests: new `Tests/PDFPageMotionTests.swift`.
- CHANGELOG; minor version bump. No screen step: a 0.2 s animation can't be caught reliably in a screenshot, so the check is a recording looked at by eye, and the pdf-pages flow confirms page edits still work.
