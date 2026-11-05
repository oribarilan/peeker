# Proposal

## Why

Little in Peeker reacts when the pointer is over it: toolbar tools, PDF and TIFF page thumbnails, and the trail under the toolbar look the same hovered or not, so nothing says what can be clicked before it's clicked. Only the Markdown outline highlights a row, in a gray of its own. The design language should have one hover look, used everywhere.

## What Changes

- One hover look: a faint rounded tint in the accent color (12% in light, 18% in dark), fading in quickly (at once with Reduce Motion), following light and dark and the user's chosen accent.
- It shows on everything clickable that has no button frame of its own: PDF page thumbnails, TIFF page thumbnails, the trail's places, and the Markdown outline's rows (which change from their gray to this look). Toolbar buttons keep macOS's own hover, which already lightens their glass capsules.
- Never on a selected row or thumbnail, whose own look stays.
- Settings' theme cards are left as they are: each is already a large framed preview.
- Framed system buttons, such as Open in Peeker and Settings' push buttons, keep macOS's own look.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `plugin-host`: a shared hover look for clickable things, in the host and every plugin.

## Impact

- `Sources/PeekerKit/`: a small hover drawing helper (color, corner radius, fade) plugins and the host share, and a tracking helper for views and table rows.
- Host: `HistoryTrail`.
- Plugins: `PageThumbnails` (PDF; a fill behind PDFKit's thumbnails, which have no hover hook), `PageList` (image), `OutlineList` (Markdown).
- Tests for the helper's color and fade, and per place that hovering shows and leaving clears; a screen step capturing a hovered page thumbnail; CHANGELOG; minor version bump.
