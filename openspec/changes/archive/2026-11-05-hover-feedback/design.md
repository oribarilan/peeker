# Design

## Context

The Markdown outline has the only hover today: `OutlineList` tracks the pointer and `OutlineRowView.drawBackground` fills a rounded rect in `quaternarySystemFill`. Toolbar tools are native image items on macOS 26's glass capsules, so Peeker has no view of its own there to track the pointer. PDF thumbnails are PDFKit's `PDFThumbnailView` (subclassed as `PageThumbnails`), with no hover hook and its own selection drawing: a gray rounded box behind the page and a gray badge on its number. TIFF thumbnails are an `NSTableView` in `PageList`. The trail's places are borderless `NSButton`s in `HistoryTrail`. Plugins can share code only through `PeekerKit`.

## Goals / Non-Goals

**Goals:** one look defined once; each place adds the least code to show it; no work on the open path.

**Non-Goals:** pointer changes (no hand cursor); hover on framed system buttons, menus, text or Settings' theme cards (each already a large framed preview).

## Decisions

**`PeekerKit.HoverStyle` holds the look:** the fill color (`NSColor.controlAccentColor`, which is the user's accent or Peeker's indigo under Multicolor, at 12% alpha in light and 18% in dark, as a dynamic color so it follows the appearance), the corner radius (6 points) and the fade (0.1 s, zero when `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`). The maintainer picked this tint over an accent outline and over gray from mockups in light and dark: gray would look like PDFKit's gray thumbnail selection, and an outline reads as keyboard focus.

**`PeekerKit.HoverFill` draws it:** a layer-backed `NSView` placed behind content, with `isHovered` animating its opacity by the fade. `HistoryTrail` adds one tracking area and moves a fill behind the place under the pointer. Table rows share `PeekerKit.HoverTableScrollView`, the outline's row tracking moved there so `PageList` uses it too, and its `HoverRowView` holds a fill behind the cells that stays hidden on the selected row; `OutlineRowView` and its gray are gone.

**PDF thumbnails get a fill behind PDFKit's cells, not a subclass of them.** `PageThumbnails` adds a tracking area, maps the pointer to the thumbnail under it with the collection view's `indexPathForItem(at:)` (the same collection view the drop bar already finds), and moves one `HoverFill` to that item's frame, skipping selected items. The fill lives in the collection view's `backgroundView`: PDFKit's items draw into the collection view's own layer, so a fill added as a subview would cover the pages, as the first screen run showed. Considered drawing into PDFKit's cells: they're private and replaced on reload.

**The toolbar is left to macOS.** Its tools are native items, which this change can't draw into without giving up the glass capsules, and on macOS 26 a hovered capsule already lightens (checked on screen: its gray goes from 3D3A3A to 535151 in dark while its neighbor stays put).

## Risks / Trade-offs

- [The tint may read as a selection] → outline and TIFF selections are a solid accent and PDF thumbnail selections are gray, so a 12-18% accent tint differs from both; checked in mockups and, once built, in screenshots in light and dark.
- [PDFKit may lay out thumbnails differently on macOS 26] → the overlay asks the collection view for frames each move rather than assuming a layout; the PDF screen flow covers it on this Mac, and macOS 26 differences are a known gap.
