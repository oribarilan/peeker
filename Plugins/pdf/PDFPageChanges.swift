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

    func pagesChanged() {
        pdfView.layoutDocumentView()
        container.finder.searchAgain()
    }
}
