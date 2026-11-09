import AppKit
import PDFKit
import PeekerKit

// The conformance is declared on the class itself: this file alone would be left out of the app, since nothing
// else in the static plugin library refers to it, and a PDF or image would then not zoom from the host.
extension PDFPluginDocument {
    var zoomPercent: Double { pdfView.scaleFactor * 100 }

    /// PDFView's own limits (10% to 10,000%, fitted or not), where Zoom In and Zoom Out stop too.
    var zoomRange: ClosedRange<Double> { pdfView.minScaleFactor * 100...pdfView.maxScaleFactor * 100 }

    /// Scales the pages, then scrolls so the page point that was under `point` is under it again.
    func setZoom(_ percent: Double, around point: NSPoint?) {
        let anchor = point.map { pdfView.convert($0, from: contentView) } ?? NSPoint(x: pdfView.bounds.midX, y: pdfView.bounds.midY)
        let page = pdfView.page(for: anchor, nearest: true)
        let onPage = page.map { pdfView.convert(anchor, to: $0) }
        pdfView.autoScales = false
        pdfView.scaleFactor = min(max(percent, zoomRange.lowerBound), zoomRange.upperBound) / 100
        guard let page, let onPage, let scrollView = pdfView.documentView?.enclosingScrollView else { return }
        pdfView.layoutDocumentView()
        let clip = scrollView.contentView
        let moved = clip.convert(pdfView.convert(onPage, from: page), from: pdfView)
        let target = clip.convert(anchor, from: pdfView)
        var bounds = clip.bounds
        bounds.origin.x += moved.x - target.x
        bounds.origin.y += moved.y - target.y
        clip.scroll(to: clip.constrainBoundsRect(bounds).origin)
        scrollView.reflectScrolledClipView(clip)
    }
}
