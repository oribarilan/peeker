import CoreGraphics
import Foundation

nonisolated struct RGBA: Codable, Sendable, Equatable {
    let red, green, blue, alpha: Double

    var isValid: Bool { [red, green, blue, alpha].allSatisfy { (0...1).contains($0) } }
}

/// What a mark is, for messages and for finding the annotation again.
nonisolated enum MarkType: String, Codable, Sendable {
    case highlight, textBox, signature

    var name: String {
        switch self {
        case .highlight: "highlight"
        case .textBox: "text box"
        case .signature: "signature"
        }
    }
}

/// Something Peeker puts on a page, saved as a standard annotation whose `/NM` is `id`. `page` is 0-based and `rect`
/// is in page space.
nonisolated struct PDFMark: Codable, Sendable, Equatable {
    nonisolated enum Kind: Codable, Sendable, Equatable {
        case highlight(RGBA)
        case textBox(text: String, fontSize: Double)
        /// Strokes as points within 0...1 of the mark's rect, origin at the bottom left, so resizing only changes the rect.
        case signature(strokes: [[CGPoint]])
    }

    let id: String
    let page: Int
    var rect: CGRect
    var kind: Kind

    var type: MarkType {
        switch kind {
        case .highlight: .highlight
        case .textBox: .textBox
        case .signature: .signature
        }
    }
}

/// One change to a PDF. Applied to the view at once, and again to a fresh copy of the file on save.
nonisolated enum PDFEdit: Codable, Sendable, Equatable {
    case add(PDFMark)
    /// A move or resize of one of Peeker's marks.
    case setBounds(id: String, type: MarkType, page: Int, rect: CGRect)
    /// New text or size for a text box, with the bounds that fit it.
    case setText(id: String, page: Int, text: String, fontSize: Double, rect: CGRect)
    case delete(id: String, type: MarkType, page: Int)
    /// A form field's value as PDFKit reports it: the text, a choice, or a button's on-state name ("Off" when off).
    case field(name: String, value: String)

    /// The prefix that marks an annotation as Peeker's own: only those can be selected and changed.
    static let idPrefix = "peeker-"

    static func newID() -> String { idPrefix + UUID().uuidString }

    /// The mark this edit adds, changes or removes.
    var markID: String? {
        switch self {
        case .add(let mark): mark.id
        case .setBounds(let id, _, _, _), .setText(let id, _, _, _, _), .delete(let id, _, _): id
        case .field: nil
        }
    }

    /// `edits` with the same effect in fewer steps: a change to a mark added in the list rewrites its `.add`, removing
    /// such a mark drops it, and only the latest change of each kind to a saved mark or field is kept.
    static func folded(_ edits: [PDFEdit]) -> [PDFEdit] {
        var out: [PDFEdit] = []
        for edit in edits {
            switch edit {
            case .add:
                out.append(edit)
            case .setBounds(let id, _, _, let rect):
                if let index = addIndex(of: id, in: out), case .add(var mark) = out[index] {
                    mark.rect = rect
                    out[index] = .add(mark)
                } else {
                    out.removeAll { if case .setBounds(id, _, _, _) = $0 { true } else { false } }
                    out.append(edit)
                }
            case .setText(let id, _, let text, let fontSize, let rect):
                if let index = addIndex(of: id, in: out), case .add(var mark) = out[index] {
                    mark.kind = .textBox(text: text, fontSize: fontSize)
                    mark.rect = rect
                    out[index] = .add(mark)
                } else {
                    // The text's bounds replace an earlier move too.
                    out.removeAll { $0.markID == id && $0.isChange }
                    out.append(edit)
                }
            case .delete(let id, _, _):
                // Only what came after an earlier removal of the same mark: an undone removal adds it back under its name.
                let start = out.lastIndex { if case .delete(id, _, _) = $0 { true } else { false } }.map { $0 + 1 } ?? 0
                let addedHere = out[start...].contains { if case .add(let mark) = $0 { mark.id == id } else { false } }
                out = Array(out[..<start]) + out[start...].filter { $0.markID != id }
                if !addedHere { out.append(edit) }
            case .field(let name, _):
                out.removeAll { if case .field(name, _) = $0 { true } else { false } }
                out.append(edit)
            }
        }
        return out
    }

    private var isChange: Bool {
        switch self {
        case .setBounds, .setText: true
        default: false
        }
    }

    private static func addIndex(of id: String, in edits: [PDFEdit]) -> Int? {
        let start = edits.lastIndex { if case .delete(id, _, _) = $0 { true } else { false } } ?? -1
        return edits.lastIndex { if case .add(let mark) = $0 { mark.id == id } else { false } }.flatMap { $0 > start ? $0 : nil }
    }
}

/// A document's unsaved changes, as recovery records keep them.
nonisolated enum PDFEdits: Codable, Sendable, Equatable {
    case operations([PDFEdit])
    /// The shape records had before edit mode: `{"pdfHighlights":{"_0":[…]}}`. Still decoded, never written.
    case pdfHighlights([LegacyHighlight])

    /// Old highlights come back as new marks, each with a new name.
    var operations: [PDFEdit] {
        switch self {
        case .operations(let edits): edits
        case .pdfHighlights(let highlights):
            highlights.map { .add(PDFMark(id: PDFEdit.newID(), page: $0.page, rect: $0.rect, kind: .highlight($0.color))) }
        }
    }
}

nonisolated struct LegacyHighlight: Codable, Sendable, Equatable {
    let page: Int
    let rect: CGRect
    let color: RGBA
}
