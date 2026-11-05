# Design

## Context

The Markdown outline has the only hover today: `OutlineList` tracks the pointer and `OutlineRowView.drawBackground` fills a rounded rect in `quaternarySystemFill`. Toolbar tools are native image items on macOS 26's glass capsules, so Peeker has no view of its own there to track the pointer. PDF thumbnails are PDFKit's `PDFThumbnailView` (subclassed as `PageThumbnails`), with no hover hook and its own selection drawing: a gray rounded box behind the page and a gray badge on its number. TIFF thumbnails are an `NSTableView` in `PageList`. The trail's places are borderless `NSButton`s in `HistoryTrail`. Plugins can share code only through `PeekerKit`.

## Goals / Non-Goals

**Goals:** one look defined once; each place adds the least code to show it; no work on the open path.

**Non-Goals:** pointer changes (no hand cursor); hover on framed system buttons, menus, text or Settings' theme cards (each already a large framed preview).

## Decisions

**`PeekerKit.HoverStyle` holds the look:** the fill color (`NSColor.controlAccentColor`, which is the user's accent or Peeker's indigo under Multicolor, at 12% alpha in light and 18% in dark, as a dynamic color so it follows the appearance), the corner radius (6 points) and the fade (0.1 s, zero when `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`). The maintainer picked this tint over an accent outline and over gray from mockups in light and dark: gray would look like PDFKit's gray thumbnail selection, and an outline reads as keyboard focus.

**`PeekerKit.HoverFill` draws it:** a layer-backed `NSView` placed behind or over content, with `isHovered` animating its opacity by the fade. `HistoryTrail`'s buttons add one tracking area and set it. Table rows (`OutlineList`, `PageList`) keep their row-tracking code and draw the fill through `HoverStyle` in their row views' `drawBackground`, skipping selected rows; `OutlineRowView` changes from its gray to it.

**PDF thumbnails get an overlay, not a subclass of PDFKit's cells.** `PageThumbnails` adds a tracking area over its scroll view, maps the pointer to the thumbnail under it with the collection view's `indexPathForItem(at:)` (the same collection view the drop bar already finds), and moves one `HoverFill` over that item's frame, skipping selected items. Considered drawing into PDFKit's cells: they're private and replaced on reload.

**The toolbar is left to macOS if it already hovers.** Its tools are native items, which this change can't draw into without giving up the glass capsules; task 2.1 checks on screen first.

## Risks / Trade-offs

- [The tint may read as a selection] → outline and TIFF selections are a solid accent and PDF thumbnail selections are gray, so a 12-18% accent tint differs from both; checked in mockups and, once built, in screenshots in light and dark.
- [PDFKit may lay out thumbnails differently on macOS 26] → the overlay asks the collection view for frames each move rather than assuming a layout; the PDF screen flow covers it on this Mac, and macOS 26 differences are a known gap.
