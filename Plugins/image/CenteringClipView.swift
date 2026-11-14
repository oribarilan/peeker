import AppKit

/// Keeps a document view smaller than the visible area (an image zoomed out below fit) in the middle, and scrolls so
/// the image's corner lands on a whole screen pixel: an image fitted between pixels, magnified to Actual Size, would
/// otherwise blend each pixel with its neighbour.
final class CenteringClipView: NSClipView {
    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var rect = super.constrainBoundsRect(proposedBounds)
        guard let documentView, rect.width > 0, rect.height > 0 else { return rect }
        let document = documentView.frame
        if rect.width > document.width { rect.origin.x = document.midX - rect.width / 2 }
        if rect.height > document.height { rect.origin.y = document.midY - rect.height / 2 }
        let corner = (documentView as? ImageCanvas).map { $0.convert($0.imageRect.origin, to: self) } ?? document.origin
        let pixelsX = frame.width / rect.width * (window?.backingScaleFactor ?? 2)
        let pixelsY = frame.height / rect.height * (window?.backingScaleFactor ?? 2)
        rect.origin.x = corner.x - ((corner.x - rect.origin.x) * pixelsX).rounded() / pixelsX
        rect.origin.y = corner.y - ((corner.y - rect.origin.y) * pixelsY).rounded() / pixelsY
        return rect
    }
}
