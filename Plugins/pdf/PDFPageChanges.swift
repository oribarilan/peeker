import AppKit
import PDFKit

/// Page edits as the view shows them: a thumbnail drag made into an edit, and the layout after any page edit.
extension PDFPluginDocument {
    /// Pages were moved by a drag in the thumbnails. Puts the old order back with the original page objects (PDFKit
    /// leaves copies), then makes a real move an edit like any other; one that isn't a move, or isn't allowed, beeps.
    func pagesDragged(before: [PDFPage]) {
        endInteraction()
        let after = (0..<document.pageCount).compactMap(document.page(at:))
        let order = isEditing && allowsPageChanges ? PeekerPDFDocument.order(before: before, after: after) : nil
        document.own {
            for page in after where !before.contains(where: { $0 === page }) { document.removePage(at: document.index(for: page)) }
            for (index, page) in before.enumerated() where index >= document.pageCount || document.page(at: index) !== page {
                let at = document.index(for: page)
                if at != NSNotFound { document.removePage(at: at) }
                document.insert(page, at: index)
            }
        }
        if let order, order != Array(order.indices), change(.reorderPages(order: order)) { return }
        pagesChanged()
        if order == nil { NSSound.beep() }
    }

    /// Lays out the pages again after a page edit, and searches them again. Pages put back or inserted are scrolled
    /// into view: on macOS 26 PDFKit can keep the page in view where it is and leave them above it. Right after a
    /// layout `visiblePages` still lists them, so where they sit decides.
    func pagesChanged(showing edit: PDFEdit? = nil) {
        pdfView.layoutDocumentView()
        container.finder.searchAgain()
        if case .restorePages(let pages, _, _) = edit, let first = pages.min().flatMap(document.page(at:)),
            PageMotion.frame(of: first, in: pdfView) == nil
        {
            pdfView.go(to: first)
        }
    }
}
