import CoreGraphics
import Foundation
import PeekerKit

/// What a mark is, for messages and for finding the annotation again.
nonisolated enum MarkType: String, Codable, Sendable {
    case highlight, textBox, signature, drawing

    var name: String {
        switch self {
        case .highlight: "highlight"
        case .textBox: "text box"
        case .signature: "signature"
        case .drawing: "drawing"
        }
    }
}

/// A text box's font, weight, slant, color and fill. The fonts are PDF base fonts, which every PDF app has.
nonisolated struct TextBoxStyle: Codable, Sendable, Equatable {
    /// Nil for the standard style, which marks store as nil.
    var nilIfStandard: TextBoxStyle? { self == .standard ? nil : self }

    enum Font: String, Codable, Sendable, CaseIterable { case sans, serif, mono }
    var font: Font
    var bold: Bool
    var italic: Bool
    var color: RGBA
    /// Filled with `color`, the text white or black on it.
    var boxed: Bool

    static let standard = TextBoxStyle(font: .sans, bold: false, italic: false, color: RGBA(red: 0, green: 0, blue: 0, alpha: 1), boxed: false)
    static let standardSize = 12.0

    /// The base font's PostScript name, such as Times-BoldItalic.
    var fontName: String { Self.faces(of: font)[(bold ? 1 : 0) + (italic ? 2 : 0)] }

    /// Regular, bold, italic, bold italic.
    private static func faces(of font: Font) -> [String] {
        switch font {
        case .sans: ["Helvetica", "Helvetica-Bold", "Helvetica-Oblique", "Helvetica-BoldOblique"]
        case .serif: ["Times-Roman", "Times-Bold", "Times-Italic", "Times-BoldItalic"]
        case .mono: ["Courier", "Courier-Bold", "Courier-Oblique", "Courier-BoldOblique"]
        }
    }

    /// The font, weight and slant of a base font's name; nil for any other font.
    static func face(of name: String) -> (font: Font, bold: Bool, italic: Bool)? {
        for font in Font.allCases { if let index = faces(of: font).firstIndex(of: name) { return (font, index & 1 == 1, index & 2 == 2) } }
        return nil
    }

    /// Opaque and in range: the file keeps no transparency, so a style from a recovery record or the preferences that
    /// asks for it is refused.
    var isValid: Bool { color.isValid && color.alpha == 1 }

    /// The color text is written in: the style's, or on a box of it white or black, whichever contrasts more.
    var textColor: RGBA {
        guard boxed else { return color }
        return color.relativeLuminance > 0.179 ? RGBA(red: 0, green: 0, blue: 0, alpha: 1) : RGBA(red: 1, green: 1, blue: 1, alpha: 1)
    }
}

extension RGBA {
    /// WCAG's relative luminance: above about 0.179, black text contrasts more than white.
    nonisolated var relativeLuminance: Double {
        let linear = { (c: Double) in c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }
}

/// Something Peeker puts on a page, saved as a standard annotation named `id` (in `/NM` and `/PeekerID`). `page` is
/// 0-based and `rect` is in page space.
nonisolated struct PDFMark: Codable, Sendable, Equatable {
    nonisolated enum Kind: Codable, Sendable, Equatable {
        case highlight(RGBA)
        /// A nil style is the standard one, so records written before styles read the same.
        case textBox(text: String, fontSize: Double, style: TextBoxStyle? = nil)
        /// Strokes as points within 0...1 of the mark's rect, origin at the bottom left, so resizing only changes the rect.
        case signature(strokes: [[CGPoint]])
        /// A drawing or stamp from the markup strip.
        case drawing(PDFDrawing)
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
        case .drawing: .drawing
        }
    }
}

/// One change to a PDF. Applied to the view at once, and again to a fresh copy of the file on save. Page indices
/// refer to the document as it was just before the edit, so a list of edits only makes sense applied in order.
nonisolated enum PDFEdit: Codable, Sendable, Equatable {
    case add(PDFMark)
    /// A move or resize of one of Peeker's marks.
    case setBounds(id: String, type: MarkType, page: Int, rect: CGRect)
    /// New text, size or style for a text box, with the bounds that fit it.
    case setText(id: String, page: Int, text: String, fontSize: Double, rect: CGRect, style: TextBoxStyle? = nil)
    case delete(id: String, type: MarkType, page: Int)
    /// A new color or line width for a drawing.
    case setLook(id: String, page: Int, color: RGBA, width: Double)
    /// A form field's value as PDFKit reports it: the text, a choice, or a button's on-state name ("Off" when off).
    case field(name: String, value: String)
    /// Turns pages a quarter turn: `by` is 90 (clockwise) or -90.
    case rotatePages(pages: [Int], by: Int)
    /// Puts the pages in a new order: `order[i]` is the index of the page that ends up at `i`.
    case reorderPages(order: [Int])
    /// Removes pages, keeping them under `token` so the matching restore puts back the same pages.
    case deletePages(pages: [Int], token: String)
    /// Puts deleted pages back at `pages` (their indices once restored). `data` holds copies of them as a PDF, for
    /// when the pages kept under `token` aren't at hand: the deletion was saved, or this comes from a recovery copy.
    case restorePages(pages: [Int], token: String, data: Data)

    /// The prefix that marks an annotation as Peeker's own: only those can be selected and changed.
    static let idPrefix = "peeker-"

    static func newID() -> String { idPrefix + UUID().uuidString }

    /// The mark this edit adds, changes or removes.
    var markID: String? {
        switch self {
        case .add(let mark): mark.id
        case .setBounds(let id, _, _, _), .setText(let id, _, _, _, _, _), .delete(let id, _, _), .setLook(let id, _, _, _): id
        case .field, .rotatePages, .reorderPages, .deletePages, .restorePages: nil
        }
    }

    /// Rotates, removes, inserts or reorders pages.
    var isPageEdit: Bool {
        switch self {
        case .rotatePages, .reorderPages, .deletePages, .restorePages: true
        default: false
        }
    }

    /// Changes which index some page has.
    var movesPages: Bool {
        switch self {
        case .reorderPages, .deletePages, .restorePages: true
        default: false
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
                    if case .drawing(let drawing) = mark.kind { mark.kind = .drawing(drawing.rebuilt(in: rect.size)) }
                    mark.rect = rect
                    out[index] = .add(mark)
                } else {
                    out.removeAll { if case .setBounds(id, _, _, _) = $0 { true } else { false } }
                    out.append(edit)
                }
            case .setText(let id, _, let text, let fontSize, let rect, let style):
                if let index = addIndex(of: id, in: out), case .add(var mark) = out[index] {
                    mark.kind = .textBox(text: text, fontSize: fontSize, style: style)
                    mark.rect = rect
                    out[index] = .add(mark)
                } else {
                    // The text's bounds replace an earlier move too.
                    out.removeAll { $0.markID == id && $0.isChange }
                    out.append(edit)
                }
            case .setLook(let id, _, let color, let width):
                if let index = addIndex(of: id, in: out), case .add(var mark) = out[index], case .drawing(var drawing) = mark.kind {
                    (drawing.color, drawing.width) = (color, width)
                    mark.kind = .drawing(drawing.rebuilt(in: mark.rect.size))
                    out[index] = .add(mark)
                } else {
                    out.removeAll { if case .setLook(id, _, _, _) = $0 { true } else { false } }
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
            case .rotatePages, .reorderPages, .deletePages, .restorePages:
                out.append(edit)
            }
        }
        return out
    }

    private var isChange: Bool {
        switch self {
        case .setBounds, .setText, .setLook: true
        default: false
        }
    }

    private static func addIndex(of id: String, in edits: [PDFEdit]) -> Int? {
        let start = edits.lastIndex { if case .delete(id, _, _) = $0 { true } else { false } } ?? -1
        return edits.lastIndex { if case .add(let mark) = $0 { mark.id == id } else { false } }.flatMap { $0 > start ? $0 : nil }
    }
}
