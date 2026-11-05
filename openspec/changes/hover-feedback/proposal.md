# Proposal

## Why

Little in Peeker reacts when the pointer is over it: toolbar tools, PDF and TIFF page thumbnails, the trail under the toolbar and Settings' theme cards look the same hovered or not, so nothing says what can be clicked before it's clicked. Only the Markdown outline highlights a row, in a gray of its own. The design language should have one hover look, used everywhere.

## What Changes

- One hover look: a rounded fill in the accent color at low strength, fading in quickly (at once with Reduce Motion), following light and dark and the user's chosen accent.
- It shows on everything clickable that has no button frame of its own: toolbar buttons, PDF page thumbnails, TIFF page thumbnails, the trail's places, the Markdown outline's rows (which change from their gray to this look) and Settings' theme cards.
- Never on a selected row or the selected card, whose own look stays.
- Framed system buttons, such as Open in Peeker and Settings' push buttons, keep macOS's own look.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `plugin-host`: a shared hover look for clickable things, in the host and every plugin.

## Impact

- `Sources/PeekerKit/`: a small hover drawing helper (color, corner radius, fade) plugins and the host share, and a tracking helper for views and table rows.
- Host: `ToolbarButton` (from `toolbar-shortcuts-and-tips`, which this change builds on), `HistoryTrail`, Settings' `ThemeCard` (a SwiftUI hover modifier with the same color and radius).
- Plugins: `PageThumbnails` (PDF; an overlay above PDFKit's thumbnail view, which has no hover hook), `PageList` (image), `OutlineList` (Markdown).
- Tests for the helper's color and fade, and per place that hovering shows and leaving clears; a screen step capturing a hovered toolbar button; CHANGELOG; minor version bump.
