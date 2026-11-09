import AppKit
import PeekerKit

/// 100% is one image pixel per screen pixel; the scroll view's magnification counts from the image fitted to the window.
// The conformance is declared on the class itself: this file alone would be left out of the app, since nothing
// else in the static plugin library refers to it, and a PDF or image would then not zoom from the host.
extension ImageDocument {
    /// The magnification that shows one image pixel per screen pixel, for the image as fitted now.
    var actualSizeMagnification: CGFloat {
        let scale = contentScrollView.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        return Self.actualMagnification(pixelWidth: pixelSize.width, backingScale: scale, fittedWidth: canvas.imageRect.width)
    }

    var zoomPercent: Double { contentScrollView.magnification / actualSizeMagnification * 100 }

    /// Down to an eighth of fit, or to actual size when that's smaller, as Actual Size allows; up to 16 times fit.
    var zoomRange: ClosedRange<Double> {
        let actual = actualSizeMagnification
        return min(Self.minimumZoom, actual) / actual * 100...contentScrollView.maxMagnification / actual * 100
    }

    /// The scroll view's own live pinch is smoother than one made of `setZoom` calls.
    var pinchesNatively: Bool { true }

    func setZoom(_ percent: Double, around point: NSPoint?) {
        let actual = actualSizeMagnification, clip = contentScrollView.contentView
        let percent = min(max(percent, zoomRange.lowerBound), zoomRange.upperBound)
        contentScrollView.minMagnification = min(Self.minimumZoom, actual)
        let center = point.map { clip.convert($0, from: contentView) } ?? NSPoint(x: clip.bounds.midX, y: clip.bounds.midY)
        contentScrollView.setMagnification(percent / 100 * actual, centeredAt: center)
        sharpenIfNeeded(atActualSize: percent >= 100)
    }
}
