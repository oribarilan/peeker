# Proposal

## Why

A box or ellipse on an image is selected by a click anywhere inside it, and that click wins over the armed tool. Box something in a screenshot, and an arrow, number or text started inside the box grabs the box instead. PDF Markup already selects outlines only by their line, so what's inside stays usable; images should work the same.

## What Changes

- A box or ellipse mark on an image is selected only near its outline. A click inside it reaches the armed tool, or clears the selection.
- Pixelate and Spotlight have no outline, so they stay selected anywhere in their area.

## Capabilities

### Modified Capabilities

- `image`: boxes and ellipses are selected by their outline.

## Impact

`ImageMark.contains(_:tolerance:)` in `Plugins/image/MarkupOverlay.swift`. Unit tests, a step in the image-edit flow, CHANGELOG; patch version bump.
