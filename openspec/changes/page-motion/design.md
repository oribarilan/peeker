# Design

## Context

Page edits go through `PDFPluginDocument.applyLive`, which applies a `PDFEdit` to the `PDFDocument` and lays the pages out again. PDFKit draws pages itself, with no animation hooks, and its views are replaced on layout.

## Goals / Non-Goals

**Goals:** a rotate, a delete and an undone delete read as motion, without delaying the edit or input. **Non-goals:** animating reordering (the drag already shows it), thumbnails, or the Peek panel, which can't edit.

## Decisions

**Animate images of the pages over the view, not the pages.** `PageMotion` takes an image of each changed page that's on screen before the edit (`PDFPage.thumbnail(of:for:)` at its on-screen size), the edit is applied and laid out at once, then a layer-backed overlay above the `PDFView` animates those images with Core Animation and removes itself after 0.25 s. The overlay passes clicks through. Considered animating PDFKit's own page views: they're private and rebuilt by layout.

- Rotate: the old image turns by the rotation and scales to the new page's frame, while a cover in the view's background color fades from over the page as it now sits.
- Delete: the image shrinks to 85% and fades out.
- Undo of a delete: the restored page's image grows from 85% and fades in, over a cover that hides the page until then.

**When nothing moves:** Reduce Motion on (read through a replaceable `reducesMotion`, as `HoverStyle` and `AnimationPlayer` do; kept per type so tests that set it can't race each other), no window (recovered edits are applied while opening), or no changed page on screen.

## Risks / Trade-offs

- [An image taken at screen size may look soft mid-turn] → it lasts 0.2 s; checked in the recordings.
- [Many pages rotated at once] → one image per visible page only.
