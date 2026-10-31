import PDFKit

/// The PDF shown in a window. PDFKit's thumbnail view moves a dragged page by inserting a copy of it and removing
/// the original, and says nothing else; this reports such changes, made by anyone but Peeker, once they're done.
nonisolated final class PeekerPDFDocument: PDFDocument {
    /// Called on the run loop turn after pages were inserted, removed or swapped by someone else, with the pages as
    /// they were before.
    @MainActor var onForeignChange: (([PDFPage]) -> Void)?
    @MainActor private var ownChanges = 0
    @MainActor private var before: [PDFPage]?

    /// Runs `body`, whose page changes are Peeker's own.
    @MainActor func own<T, E: Error>(_ body: () throws(E) -> T) throws(E) -> T {
        ownChanges += 1
        defer { ownChanges -= 1 }
        return try body()
    }

    nonisolated override func insert(_ page: PDFPage, at index: Int) {
        noteChangeOnMain()
        super.insert(page, at: index)
    }

    nonisolated override func removePage(at index: Int) {
        noteChangeOnMain()
        super.removePage(at: index)
    }

    nonisolated override func exchangePage(at indexA: Int, withPageAt indexB: Int) {
        noteChangeOnMain()
        super.exchangePage(at: indexA, withPageAt: indexB)
    }

    /// A shown document's pages change on the main thread: from Peeker's edits or PDFKit's thumbnail view.
    private func noteChangeOnMain() {
        guard Thread.isMainThread else { return }
        nonisolated(unsafe) let document = self
        MainActor.assumeIsolated { document.noteChange() }
    }

    @MainActor private func noteChange() {
        guard ownChanges == 0, before == nil else { return }
        before = (0..<pageCount).compactMap(page(at:))
        Task { @MainActor [weak self] in
            guard let self, let before = self.before else { return }
            self.before = nil
            self.onForeignChange?(before)
        }
    }

    /// The new order as indices into `before`, given the pages now; nil unless they're the same pages moved around.
    /// A page object not seen before is PDFKit's copy of a dragged page: matched with the gone page it shares its
    /// underlying page with, or else in order with the pages that went.
    static func order(before: [PDFPage], after: [PDFPage]) -> [Int]? {
        guard after.count == before.count else { return nil }
        var gone = before.indices.filter { index in !after.contains { $0 === before[index] } }
        var order: [Int] = []
        for page in after {
            if let index = before.firstIndex(where: { $0 === page }) {
                order.append(index)
            } else if let ref = page.pageRef, let match = gone.firstIndex(where: { before[$0].pageRef === ref }) {
                order.append(gone.remove(at: match))
            } else if !gone.isEmpty {
                order.append(gone.removeFirst())
            } else {
                return nil
            }
        }
        return Set(order).count == order.count ? order : nil
    }
}
