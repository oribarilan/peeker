# Design

## Context

Zoom today is a set of menu-only tools with the ids `zoom-in`, `zoom-out`, `zoom-fit` and `zoom-actual`, which each plugin runs in `perform(_:)`: PDF through `PDFView` (`zoomIn`, `autoScales`, `scaleFactor`), image through `NSScrollView` magnification (it also pinches natively, `allowsMagnification`), text and Markdown through a font size remembered in preferences. Tables and data trees have no zoom. Nothing handles Cmd+scroll. The host knows no formats, so a control that shows the zoom needs a contract.

## Goals / Non-Goals

**Goals:** one zoom model every format reports through; Cmd+scroll and pinch everywhere, the Peek panel included; the pill in Editor windows; the same steps from the pill as from the menu.

**Non-Goals:** zoom remembered per file; toolbar zoom buttons; a zoom field for typing a percentage; changing how far each format zooms.

## Decisions

### An optional zoom contract in PeekerKit

`protocol Zooming: PluginDocument` with: `zoomPercent: Double` (100 is actual size: PDF scale 1, one image pixel per screen pixel, the format's default text size), `zoomRange: ClosedRange<Double>`, `setZoom(_ percent: Double, around point: NSPoint?)` (a point in the content view, or nil for the middle), `var onZoomChange: (() -> Void)?`, and `pinchesNatively: Bool` (default false). The menu tools stay as they are; the pill's − and + run `zoom-out` and `zoom-in`, so steps match the menu, and its Actual Size and Zoom to Fit run `zoom-actual` and `zoom-fit`. Fixed percentages call `setZoom`. *Alternative:* the host parses percentages out of tool titles; rejected as brittle.

### The host handles the gestures

Each document's controller installs a local event monitor for `.scrollWheel` and `.magnify` over its content (Editor window or Peek panel), removed on close, replacement or failure. A mouse wheel notch with Cmd zooms; a trackpad scroll decides when it begins (Cmd held over the content) and keeps that through its momentum, swallowing the whole gesture when it zooms, so releasing Cmd midway doesn't scroll and holding Cmd during a flick's momentum doesn't zoom. One event zooms by at most a quarter. A pinch zooms through the host unless the document's own view pinches (`pinchesNatively`: the image's `NSScrollView`); PDF pinches through the host. The Peek panel never becomes key, but scroll and magnify events still reach the window under the pointer, so Finder keeps the keyboard. *Alternative:* each plugin overrides `scrollWheel`/`magnify`; rejected, six copies of the same thing.

### The pill is host UI over the content

A small view in the document's content area, bottom right, with a glass background (`NSGlassEffectView` on macOS 26), three buttons (Zoom Out, the percentage, Zoom In), shown while the pointer is inside the content (a tracking area, checked at once when the content appears under the pointer) or its menu is open, faded quickly (instantly with Reduce Motion) and then hidden, so its corner takes no clicks or scrolls while it isn't showing. Scrolling over it scrolls the document. Its menu opens upward with Actual Size, Zoom to Fit where the format has it, and 50%, 200% and 400% within range, the current one checked. It updates on `onZoomChange`. Accessibility: a group labelled "Zoom", buttons "Zoom Out", "Zoom In" and the percentage; keyboard users zoom with the View menu's keys. Only Editor windows add it; documents that aren't `Zooming` get none.

### Tables and trees zoom by text size

Table and data get `zoom-in`, `zoom-out` and `zoom-actual` (menu-only, Cmd+= / Cmd+- / Cmd+0), a font size from 6 to 72 points remembered in their preferences (`plugins.table.fontSize`, `plugins.data.fontSize`), applied to cells and row heights, and to the tree and Show Text together. No Zoom to Fit, as for text.

### Found while building

- The plugins are static libraries, and the linker pulls in only files something refers to. A file holding nothing but `extension X: Zooming` was left out of the app (the tests linked it), so PDFs and images didn't zoom from the host. Each class declares `Zooming` itself; the members can live in an extension file.
- Reading `NSEvent.magnification` on a scroll event throws, which ended the event monitor and let Cmd+scroll through unzoomed. Each event's values are read only for its type.
- The Peek panel's Markdown view re-renders the whole file to change size, so its zoom (maintainer's choice, 2026-11-09) follows a gesture's steps in `zoomPercent` at once and draws the new size once the gesture has stopped for 250 ms.
- Synthetic scroll events posted at the HID level don't reach the window; the screen tool's `drive scroll` posts at the session level.

### Redraw pacing

Text and the Markdown editor restyle all their text to change size, which on a large file can't keep up with a gesture's events. A shared `ZoomPacer` in PeekerKit draws the first step at once and later ones at most every 100 ms, the last always; `zoomPercent` reports the size being headed to, so steps build on each other and the control follows at once. The menu's steps draw at once. The Peek panel's Markdown waits for the gesture to stop instead, since it re-renders the whole file.

## Risks / Trade-offs

- Each window's local event monitor sees every scroll in the app; it returns early for other windows and for events that don't zoom.
- The pill can cover the bottom-right corner of a page at high zoom; it shows only on hover, and moves aside for nothing else in this change.
- Trackpad Cmd+scroll and pinch couldn't be driven by the screen tests (they send wheel notches), so their feel is checked by hand.
- Text, tables and trees keep their scroll position while their text grows, rather than the point under the pointer.
- While a crop selection's buttons sit at the image's bottom right, the control can cover them while the pointer is over the image.
