# Design

## Context

See proposal.md for why. `PageThumbnails` subclasses `PDFThumbnailView`. Inside it, PDFKit keeps a private `PDFIconCollectionView` holding a plain `NSCollectionView` with a grid layout, whose delegate is that private view: it validates and accepts drops (observed 2026-11-03). The grid layout draws no gap indicator, and PDFKit offers no hook for drag feedback.

## Goals / Non-Goals

**Goals:**
- An insertion bar in the gap where a dragged page will land, with drops working exactly as before.
- Nothing worse than today if PDFKit's insides change: no bar, same drags.

**Non-Goals:**
- Opening a gap between thumbnails as Preview does, which would mean replacing PDFKit's view.
- Dragging pages in from other files or apps.

## Decisions

### Stand in for PDFKit's delegate, pass everything through

`ThumbnailDropBar` finds the first `NSCollectionView` inside the thumbnails and becomes its delegate, holding PDFKit's delegate and forwarding every message it doesn't handle (`responds(to:)` and `forwardingTarget(for:)`), so PDFKit sees every call it saw before. It handles three itself, each calling PDFKit's version first where PDFKit has one: validating a drop (the answer and the index path PDFKit settles on decide the bar: shown in that gap when the drop is allowed, hidden when not), accepting a drop (hides the bar), and the drag session ending (hides the bar). `PageThumbnails` installs it when it moves into a window and whenever editing turns on, and again if PDFKit has since set its delegate back.

The bar is an accent-colored rounded view, 3 points tall and as wide as a thumbnail, added above the items in the collection view so it scrolls with them, centered on the boundary between the two thumbnails (above the first, below the last). A drop proposed on a page rather than before it draws the bar before that page.

The collection view tells the delegate nothing when the pointer leaves, so while the bar shows, a 0.1 s timer hides it once the pointer is outside the thumbnails' visible area.

Alternative: draw from the pointer position alone, with our own guess of the landing gap. Rejected: the bar could disagree with where PDFKit drops the page. Alternative: an overlay that registers for the drag itself and forwards to the collection view. Rejected: it would sit in the drop path and could break drops.

### Fails closed

If no collection view or delegate is found, nothing is installed and dragging is as today. If PDFKit stops calling the validate method, the bar never shows.

## Risks / Trade-offs

- [Relies on PDFKit's private layout of views and on its delegate answering through forwarding] → Failure means no bar, never a broken drop; the screen flow notices a missing bar.
- [A delegate method PDFKit adds later and NSCollectionView only checks at `delegate` set time] → Forwarding answers `responds(to:)` for whatever PDFKit implements at install time, which is when NSCollectionView asks.
