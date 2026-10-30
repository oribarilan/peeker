import AppKit
import os
import PDFKit

final class PDFComponent: Component {
    let pdfView = PDFView()
    var onEdit: (() -> Void)?
    /// Highlights added since the file was loaded or last saved, with the annotations that show them.
    private var pending: [(highlight: Highlight, annotation: PDFAnnotation)] = []
    /// Opaque: PDFKit drops alpha when writing and draws highlights with multiply, so text stays readable and the
    /// highlight looks the same before and after saving.
    private static let highlightColor = RGBA(red: 1, green: 0.8, blue: 0, alpha: 1)
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "dev.previewpp", category: "components")

    init(url: URL) throws {
        guard let document = PDFDocument(url: url) else { throw CocoaError(.fileReadCorruptFile) }
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
    }

    var view: NSView { pdfView }

    func makeThumbnails() -> NSView {
        let thumbnails = PDFThumbnailView()
        thumbnails.pdfView = pdfView
        thumbnails.thumbnailSize = NSSize(width: 90, height: 120)
        thumbnails.backgroundColor = .clear
        return thumbnails
    }

    func perform(_ verb: String) -> Bool {
        switch verb {
        case "zoom-in": pdfView.zoomIn(nil)
        case "zoom-out": pdfView.zoomOut(nil)
        case "highlight":
            guard let document = pdfView.document else { return true }
            let highlights = (pdfView.currentSelection?.selectionsByLine() ?? []).flatMap { line in
                line.pages.map { Highlight(page: document.index(for: $0), rect: line.bounds(for: $0), color: Self.highlightColor) }
            }
            pdfView.clearSelection()
            add(highlights)
        default:
            return false
        }
        return true
    }

    func pendingEdits() -> Edits? {
        pending.isEmpty ? nil : .pdfHighlights(pending.map(\.highlight))
    }

    func restore(_ edits: Edits) {
        if case .pdfHighlights(let highlights) = edits { add(highlights) }
    }

    func didSave(_ saved: Edits) {
        guard case .pdfHighlights(let highlights) = saved else { return }
        for highlight in highlights {
            if let index = pending.firstIndex(where: { $0.highlight == highlight }) { pending.remove(at: index) }
        }
    }

    func revertEdits() {
        for (_, annotation) in pending { annotation.page?.removeAnnotation(annotation) }
        pending = []
    }

    /// Shows `highlights` and makes them pending.
    private func add(_ highlights: [Highlight]) {
        guard let document = pdfView.document else { return }
        let before = pending.count
        for highlight in highlights {
            // The plugin refuses a whole save over one highlight it can't write, so such a one never becomes pending.
            guard (0..<document.pageCount).contains(highlight.page), let page = document.page(at: highlight.page),
                  highlight.isSavable(onPageWithMediaBox: page.bounds(for: .mediaBox)) else {
                Self.log.error("skipped an invalid highlight on page \(highlight.page + 1) of a \(document.pageCount)-page PDF")
                continue
            }
            let annotation = PDFAnnotation(bounds: highlight.rect, forType: .highlight, withProperties: nil)
            let color = highlight.color
            annotation.color = NSColor(srgbRed: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
            page.addAnnotation(annotation)
            pending.append((highlight, annotation))
        }
        if pending.count > before { onEdit?() }
    }
}
