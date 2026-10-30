import AppKit
import os
import PDFKit
import PeekerKit

/// A PDF in a continuous native view with thumbnails, info and, in windows, highlighting saved on Cmd+S.
final class PDFPluginDocument: PluginDocument {
    let pdfView = PDFView()
    private let url: URL
    private let editable: Bool
    private let info: [InfoRow]
    var onEdit: (() -> Void)?
    /// Highlights added since the file was loaded or last saved, with the annotations that show them.
    private var pending: [(highlight: Highlight, annotation: PDFAnnotation)] = []
    /// Opaque: PDFKit drops alpha when writing and draws highlights with multiply, so text stays readable and the
    /// highlight looks the same before and after saving.
    private static let highlightColor = RGBA(red: 1, green: 0.8, blue: 0, alpha: 1)
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "dev.peeker", category: "pdf")

    init(url: URL, document: PDFDocument, info: [InfoRow], editable: Bool) {
        self.url = url
        self.info = info
        self.editable = editable
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
    }

    var contentView: NSView { pdfView }

    var sidebar: [SidebarPanel] {
        let thumbnails = PDFThumbnailView()
        thumbnails.pdfView = pdfView
        thumbnails.thumbnailSize = NSSize(width: 90, height: 120)
        thumbnails.backgroundColor = .clear
        return [SidebarPanel(thumbnails, sizing: .fill)] + (InfoPanel.make(info).map { [$0] } ?? [])
    }

    var commands: [CommandSpec] {
        [CommandSpec(id: "zoom-in", title: "Zoom In", symbol: "plus.magnifyingglass", shortcut: "cmd+="),
         CommandSpec(id: "zoom-out", title: "Zoom Out", symbol: "minus.magnifyingglass", shortcut: "cmd+-")]
            + (editable ? [CommandSpec(id: "highlight", title: "Highlight Selection", symbol: "highlighter", shortcut: "ctrl+cmd+h")] : [])
    }

    func perform(_ id: String) -> Bool {
        switch id {
        case "zoom-in": pdfView.zoomIn(nil)
        case "zoom-out": pdfView.zoomOut(nil)
        case "highlight" where editable:
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

    /// The unsaved highlights, or nil when there are none.
    var pendingHighlights: [Highlight]? {
        pending.isEmpty ? nil : pending.map(\.highlight)
    }

    func unsavedEdits() -> UnsavedEdits? {
        pendingHighlights.map { UnsavedEdits(PDFEdits.pdfHighlights($0)) }
    }

    func restore(encoded edits: Data) -> Bool {
        guard editable, let decoded = try? JSONDecoder().decode(PDFEdits.self, from: edits) else { return false }
        return add(decoded.highlights) > 0
    }

    func save(_ edits: UnsavedEdits, accepting offer: SaveOffer?) async throws(PluginError) {
        guard let highlights = (edits.value as? PDFEdits)?.highlights else { throw PluginError("These changes aren't PDF highlights.") }
        try await PDFPlugin.write(highlights, to: url.path)
        for highlight in highlights {
            if let index = pending.firstIndex(where: { $0.highlight == highlight }) { pending.remove(at: index) }
        }
    }

    func revertEdits() {
        for (_, annotation) in pending { annotation.page?.removeAnnotation(annotation) }
        pending = []
    }

    /// Shows `highlights` and makes them pending. Returns how many it added.
    @discardableResult
    private func add(_ highlights: [Highlight]) -> Int {
        guard let document = pdfView.document else { return 0 }
        let before = pending.count
        for highlight in highlights {
            // Saving refuses a whole file over one highlight it can't write, so such a one never becomes pending.
            guard (0..<document.pageCount).contains(highlight.page), let page = document.page(at: highlight.page),
                  highlight.isSavable(onPageWithMediaBox: page.bounds(for: .mediaBox)) else {
                Self.log.error("skipped an invalid highlight on page \(highlight.page + 1) of a \(document.pageCount)-page PDF")
                continue
            }
            let annotation = PDFPlugin.annotation(for: highlight)
            page.addAnnotation(annotation)
            pending.append((highlight, annotation))
        }
        let added = pending.count - before
        if added > 0 { onEdit?() }
        return added
    }
}
