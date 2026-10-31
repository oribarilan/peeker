import AppKit
import PDFKit
import PeekerKit

/// What a `PDFEdit` does to a `PDFDocument`: applies it, and reads the edit that takes it back. The view's document
/// takes edits live on the main thread; saving applies the same edits to a fresh copy off it.
nonisolated enum PDFEditing {
    private static let maxText = 10_000
    private static let maxStrokes = 500, maxPoints = 20_000
    /// The most a restore's copy of deleted pages may hold; it can come from a recovery file.
    private static let maxRestoreBytes = 256 << 20

    /// Applies `edit` to `document`, or throws without changing it when the edit doesn't fit. `fileName` is for messages.
    /// `stash` keeps deleted pages for their restore: one per document shown, and one per save.
    static func apply(_ edit: PDFEdit, to document: PDFDocument, fileName: String, stash: PageStash = PageStash()) throws(PluginError) {
        switch edit {
        case .add(let mark):
            let page = try page(mark.page, of: document, for: mark.type, fileName: fileName)
            guard mark.id.hasPrefix(PDFEdit.idPrefix), mark.id.count <= 64, isValid(mark.rect, on: page), isValid(mark.kind) else {
                throw PluginError("Can't save the \(mark.type.name) on page \(mark.page + 1): its position, size or contents are invalid.")
            }
            page.addAnnotation(PDFMarks.annotation(for: mark))
        case .setBounds(let id, let type, let index, let rect):
            let page = try page(index, of: document, for: type, fileName: fileName)
            let annotation = try find(id, type, verb: "move", on: page, index, fileName: fileName)
            guard isValid(rect, on: page) else {
                throw PluginError("Can't save the \(type.name) on page \(index + 1): its new position or size is invalid.")
            }
            PDFMarks.setBounds(rect, of: annotation)
        case .setText(let id, let index, let text, let fontSize, let rect):
            let page = try page(index, of: document, for: .textBox, fileName: fileName)
            let annotation = try find(id, .textBox, verb: "change", on: page, index, fileName: fileName)
            guard isValid(rect, on: page), isValid(.textBox(text: text, fontSize: fontSize)) else {
                throw PluginError("Can't save the text box on page \(index + 1): its text, size or position is invalid.")
            }
            annotation.bounds = rect
            PDFMarks.setText(text, fontSize: fontSize, of: annotation)
        case .delete(let id, let type, let index):
            let page = try page(index, of: document, for: type, fileName: fileName)
            page.removeAnnotation(try find(id, type, verb: "remove", on: page, index, fileName: fileName))
        case .field(let name, let value):
            let widgets = (0..<document.pageCount).flatMap { document.page(at: $0)?.annotations ?? [] }.filter { $0.fieldName == name }
            guard !widgets.isEmpty else { throw PluginError("Can't save the field “\(name)”: it's no longer in “\(fileName)”.") }
            guard value.count <= maxText else {
                throw PluginError("Can't save the field “\(name)”: its value is too long (over \(maxText.formatted()) characters).")
            }
            for widget in widgets { widget.widgetStringValue = value }
        case .rotatePages(let pages, let by):
            guard by == 90 || by == -90 else { throw PluginError("Can't save the page rotation: it isn't a quarter turn.") }
            for page in try self.pages(pages, of: document, fileName: fileName) {
                page.rotation = ((page.rotation + by) % 360 + 360) % 360
            }
        case .reorderPages(let order):
            let count = document.pageCount
            guard order.count == count, Set(order) == Set(0..<count) else {
                throw PluginError("Can't save the new page order: “\(fileName)” has \(count) pages.")
            }
            let wanted = order.compactMap(document.page(at:))
            // Moves keep each page object, with its annotations, and touch only pages out of place. Not
            // `exchangePage`: it crashes on a page that was removed and inserted again.
            for (index, page) in wanted.enumerated() where document.page(at: index) !== page {
                document.removePage(at: document.index(for: page))
                document.insert(page, at: index)
            }
        case .deletePages(let pages, let token):
            let targets = try self.pages(pages, of: document, fileName: fileName)
            guard targets.count < document.pageCount else { throw PluginError("Can't save: a PDF needs at least one page.") }
            stash.pages[token] = targets
            for index in pages.sorted(by: >) { document.removePage(at: index) }
        case .restorePages(let pages, let token, let data):
            let total = document.pageCount + pages.count
            guard !pages.isEmpty, Set(pages).count == pages.count, pages.allSatisfy({ (0..<total).contains($0) }) else {
                throw PluginError("Can't save the restored pages: “\(fileName)” has \(document.pageCount) pages.")
            }
            let restored: [PDFPage]
            if let kept = stash.pages[token], kept.count == pages.count {
                restored = kept
                stash.pages[token] = nil  // the same page objects can't go in twice
            } else {
                guard data.count <= maxRestoreBytes, let copy = PDFDocument(data: data), !copy.isLocked, copy.pageCount == pages.count else {
                    throw PluginError("Can't save the restored pages: their copy is missing or damaged.")
                }
                restored = (0..<copy.pageCount).compactMap(copy.page(at:))
            }
            for (index, page) in zip(pages.sorted(), restored) { document.insert(page, at: index) }
        }
    }

    /// The pages at `indices`, in page order; throws unless they're distinct, in range and at least one.
    private static func pages(_ indices: [Int], of document: PDFDocument, fileName: String) throws(PluginError) -> [PDFPage] {
        guard !indices.isEmpty, Set(indices).count == indices.count, indices.allSatisfy({ (0..<document.pageCount).contains($0) }) else {
            throw PluginError("Can't save the page changes: “\(fileName)” has \(document.pageCount) pages.")
        }
        return indices.sorted().compactMap(document.page(at:))
    }

    private static func page(_ index: Int, of document: PDFDocument, for type: MarkType, fileName: String) throws(PluginError) -> PDFPage {
        guard (0..<document.pageCount).contains(index), let page = document.page(at: index) else {
            // `&+`: the index comes from a file, and Int.max must not trap.
            throw PluginError("Can't save the \(type.name) on page \(index &+ 1): “\(fileName)” has \(document.pageCount) pages.")
        }
        return page
    }

    private static func find(_ id: String, _ type: MarkType, verb: String, on page: PDFPage, _ index: Int, fileName: String) throws(PluginError) -> PDFAnnotation {
        guard let annotation = PDFMarks.find(id, on: page) else {
            throw PluginError("Can't save: the \(type.name) to \(verb) on page \(index + 1) is no longer in “\(fileName)”.")
        }
        return annotation
    }

    /// Finite, of non-negative size, and touching the page.
    private static func isValid(_ rect: CGRect, on page: PDFPage) -> Bool {
        [rect.origin.x, rect.origin.y, rect.size.width, rect.size.height].allSatisfy(\.isFinite)
            && rect.size.width >= 0 && rect.size.height >= 0 && rect.intersects(page.bounds(for: .mediaBox))
    }

    private static func isValid(_ kind: PDFMark.Kind) -> Bool {
        switch kind {
        case .highlight(let color):
            color.isValid
        case .textBox(let text, let fontSize):
            text.count <= maxText && PDFMarks.fontSizes.contains(fontSize)
        case .signature(let strokes):
            strokes.count <= maxStrokes && strokes.reduce(0) { $0 + $1.count } <= maxPoints
                && strokes.allSatisfy { $0.allSatisfy { (-0.01...1.01).contains($0.x) && (-0.01...1.01).contains($0.y) } }
        }
    }

    /// The edit that takes `edit` back, read from the document as it is now; nil when its target is missing.
    static func inverse(of edit: PDFEdit, in document: PDFDocument) -> PDFEdit? {
        func annotation(_ id: String, _ page: Int) -> PDFAnnotation? {
            guard (0..<document.pageCount).contains(page), let page = document.page(at: page) else { return nil }
            return PDFMarks.find(id, on: page)
        }
        switch edit {
        case .add(let mark):
            return .delete(id: mark.id, type: mark.type, page: mark.page)
        case .setBounds(let id, let type, let page, _):
            return annotation(id, page).map { .setBounds(id: id, type: type, page: page, rect: $0.bounds) }
        case .setText(let id, let page, _, _, _):
            return annotation(id, page).map {
                .setText(id: id, page: page, text: $0.contents ?? "", fontSize: PDFMarks.fontSize(of: $0) ?? 12, rect: $0.bounds)
            }
        case .delete(let id, _, let page):
            return annotation(id, page).flatMap { PDFMarks.mark(of: $0, page: page) }.map { .add($0) }
        case .field(let name, _):
            let widget = (0..<document.pageCount).lazy.compactMap { document.page(at: $0)?.annotations.first { $0.fieldName == name } }.first
            return widget.map { .field(name: name, value: $0.widgetStringValue ?? "") }
        case .rotatePages(let pages, let by):
            return .rotatePages(pages: pages, by: -by)
        case .reorderPages(let order):
            guard order.count == document.pageCount, Set(order) == Set(order.indices) else { return nil }
            var back = order
            for (index, from) in order.enumerated() { back[from] = index }
            return .reorderPages(order: back)
        case .deletePages(let pages, let token):
            return copies(of: pages, in: document).map { .restorePages(pages: pages.sorted(), token: token, data: $0) }
        case .restorePages(let pages, let token, _):
            return .deletePages(pages: pages, token: token)
        }
    }

    /// The pages at `indices` as a PDF of copies, so a deletion can be undone after it was saved. Copying drops the
    /// annotations' names and styles, so they're put back as when saving moved pages.
    private static func copies(of indices: [Int], in document: PDFDocument) -> Data? {
        let pages = indices.sorted().compactMap { (0..<document.pageCount).contains($0) ? document.page(at: $0) : nil }
        guard pages.count == indices.count else { return nil }
        let copy = PDFDocument()
        for (position, page) in pages.enumerated() {
            guard let duplicate = page.copy() as? PDFPage else { return nil }
            copy.insert(duplicate, at: position)
        }
        return copy.dataRepresentation().flatMap { MovedPageRepair.repaired($0, kept: MovedPageRepair.kept(on: pages)) }
    }
}

/// Pages removed by `.deletePages`, by token, for the matching `.restorePages`.
nonisolated final class PageStash {
    var pages: [String: [PDFPage]] = [:]
}
