# Design

## Context

The Markdown outline has the only hover today: `OutlineList` tracks the pointer and `OutlineRowView.drawBackground` fills a rounded rect in `quaternarySystemFill`. Toolbar buttons become Peeker's own `ToolbarButton` in `toolbar-shortcuts-and-tips`; this change needs that one first. PDF thumbnails are PDFKit's `PDFThumbnailView` (subclassed as `PageThumbnails`), with no hover hook and its own selection drawing. TIFF thumbnails are an `NSTableView` in `PageList`. The trail's places are borderless `NSButton`s in `HistoryTrail`. Theme cards are SwiftUI `Button`s with `.plain` style in `AppearancePane`. Plugins can share code only through `PeekerKit`.

## Goals / Non-Goals

**Goals:** one look defined once; each place adds the least code to show it; no work on the open path.

**Non-Goals:** pointer changes (no hand cursor); hover on framed system buttons, menus or text.

## Decisions

**`PeekerKit.HoverStyle` holds the look:** the fill color (`NSColor.controlAccentColor` at 22% alpha, which follows the user's accent and the app's indigo under Multicolor, in light and dark), the corner radius (6 points) and the fade (0.1 s, zero when `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`). The host's SwiftUI modifier reads the same values, so Settings matches.

**`PeekerKit.HoverFill` draws it:** a layer-backed `NSView` placed behind or over content, with `isHovered` animating its opacity by the fade. Views that track the pointer themselves (`ToolbarButton`, `HistoryTrail`'s buttons) add one tracking area and set it. Table rows (`OutlineList`, `PageList`) keep their row-tracking code and draw the fill through `HoverStyle` in their row views' `drawBackground`, skipping selected rows; `OutlineRowView` changes from its gray to it.

**PDF thumbnails get an overlay, not a subclass of PDFKit's cells.** `PageThumbnails` adds a tracking area over its scroll view, maps the pointer to the thumbnail under it with the collection view's `indexPathForItem(at:)` (the same collection view the drop bar already finds), and moves one `HoverFill` over that item's frame, skipping selected items. Considered drawing into PDFKit's cells: they're private and replaced on reload.

**Settings' theme cards use `.onHover`** with a background of `HoverStyle`'s color and radius, under the card's border; the selected card shows none.

## Risks / Trade-offs

- [The accent fill may read as a selection] → it's at 22%, below the selected state's full accent, and goes as soon as the pointer leaves; checked in screenshots in light and dark.
- [PDFKit may lay out thumbnails differently on macOS 26] → the overlay asks the collection view for frames each move rather than assuming a layout; the PDF screen flow covers it on this Mac, and macOS 26 differences are a known gap.
