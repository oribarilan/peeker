# Proposal

## Why

Dragging a PDF page's thumbnail to reorder shows no insertion bar, so it's hard to tell where the page will land. Preview and Finder show one. PDFKit's thumbnail view draws none and has no API for it (found 2026-11-03; the maintainer chose an overlay on PDFKit's view over replacing it).

## What Changes

- While a thumbnail is dragged over the thumbnails, an accent-colored bar shows in the gap where the page will land, following the pointer. It goes when the drop happens, when the drag ends elsewhere, and when the pointer leaves the thumbnails.
- Nothing else about dragging changes: the same drags move the same pages, on macOS 27 and later only.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `pdf`: the reorder requirement gains the insertion bar.

## Impact

- `Plugins/pdf/PageThumbnails.swift` and a new `Plugins/pdf/ThumbnailDropBar.swift`.
- Tests, a step in the pdf-pages screen flow, CHANGELOG, and the version goes to `0.5.1-dev` (a fix).
