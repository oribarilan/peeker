import Foundation
import PDFKit

/// PDFKit writes the annotations of a page that moved (by a reorder, or a page removed or inserted before it) from
/// scratch, dropping their name (`/NM`) and style (`/DS`); without the name Peeker no longer knows its own marks.
/// A page that didn't move keeps every key, so writing once more after putting them back keeps them.
nonisolated enum MovedPageRepair {
    private static let keys = [PDFAnnotationKey.name, PDFAnnotationKey(rawValue: "/DS")]

    struct Kept {
        let type: String
        let bounds: CGRect
        let values: [(PDFAnnotationKey, String)]
    }

    /// The keys to keep, per page, from the document about to be written. Every annotation is listed, with or
    /// without keys, so a nameless one matches its own twin rather than taking another's name.
    static func kept(in document: PDFDocument) -> [[Kept]] {
        kept(on: (0..<document.pageCount).compactMap(document.page(at:)))
    }

    static func kept(on pages: [PDFPage]) -> [[Kept]] {
        pages.map { page in
            page.annotations.map { annotation in
                let values = keys.compactMap { key in (annotation.value(forAnnotationKey: key) as? String).map { (key, $0) } }
                return Kept(type: annotation.type ?? "", bounds: annotation.bounds, values: values)
            }
        }
    }

    /// `data` written again with the kept keys back on the annotations that lost them, matched by page, type and
    /// bounds. Nil when it no longer reads as a PDF with the same pages.
    static func repaired(_ data: Data, kept: [[Kept]]) -> Data? {
        guard let document = PDFDocument(data: data), document.pageCount == kept.count else { return nil }
        for (index, page) in kept.enumerated() {
            var unmatched = page
            for annotation in document.page(at: index)?.annotations ?? [] {
                guard let match = unmatched.firstIndex(where: { $0.type == annotation.type && close($0.bounds, annotation.bounds) }) else { continue }
                for (key, value) in unmatched[match].values where annotation.value(forAnnotationKey: key) == nil {
                    annotation.setValue(value, forAnnotationKey: key)
                }
                unmatched.remove(at: match)
            }
        }
        return document.dataRepresentation()
    }

    private static func close(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) < 0.01 && abs(a.minY - b.minY) < 0.01 && abs(a.width - b.width) < 0.01 && abs(a.height - b.height) < 0.01
    }
}
