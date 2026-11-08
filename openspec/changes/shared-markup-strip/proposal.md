# Proposal

## Why

PDFs are getting markup tools like images have (planned 2026-11-08), and the maintainer wants both to look and work alike: the same strip, and the same key for a tool both have. This first change moves the strip's shared part into PeekerKit and brings image markup's keys in line with what PDFs will use.

## What Changes

- The strip's tools (with their keys), color swatches and plugin controls become a shared `MarkupBar` in PeekerKit, with a shared color swatch and Aa menu. The image strip uses it and looks the same, its tool buttons now small like its other controls.
- Images gain Line (L), a straight line by dragging, which PDFs will have too.
- Marker moves from K to H: H highlights in both, as Highlight does in PDFs.

## Capabilities

### Modified Capabilities

- `image`: markup gains Line, and Marker is on H.

## Impact

`Sources/PeekerKit/MarkupBar.swift` (new); `Plugins/image/MarkupStrip.swift` on top of it; `ImageMark`'s line kind and its drawing, moving and hit testing. Tests for Line, the keys and the strip's width. CHANGELOG; minor version bump.
