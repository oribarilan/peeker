import CoreGraphics
import Foundation
import PeekerKit

/// A markup mark on an image, in full-resolution pixels of the image as its edits leave it, from the top left. Its
/// line width is in the same pixels, so a crop keeps it and a resize scales it.
nonisolated struct ImageMark: Codable, Sendable, Equatable {
    enum Kind: Codable, Sendable, Equatable {
        case arrow(from: CGPoint, to: CGPoint)
        case line(from: CGPoint, to: CGPoint)
        case box(CGRect, ellipse: Bool)
        /// `origin` is the top left of the text.
        case text(origin: CGPoint, string: String, style: TextStyle)
        /// `strength` from 0 (fine blocks) to 1 (coarse ones).
        case pixelate(CGRect, strength: Double)
        /// A numbered badge; its number is its place among the steps.
        case step(center: CGPoint)
        case pen([CGPoint])
        case marker([CGPoint])
        case spotlight(CGRect, ellipse: Bool)
    }

    let id: String
    var kind: Kind
    var color: RGBA
    var size: MarkSize
    /// The stroke width in image pixels; text, badges and arrowheads scale from it.
    var width: Double

    static let maxPoints = 10_000
    static let maxText = 10_000

    static func newID() -> String { "mark-\(UUID().uuidString)" }

    /// Within bounds; recovered marks come from a file.
    var isValid: Bool {
        guard !id.isEmpty, id.count <= 64, color.isValid, width.isFinite, (0.5...4000).contains(width) else { return false }
        let ok = { (p: CGPoint) in p.x.isFinite && p.y.isFinite && abs(p.x) <= 1_000_000 && abs(p.y) <= 1_000_000 }
        switch kind {
        case .arrow(let from, let to), .line(let from, let to): return ok(from) && ok(to)
        case .box(let rect, _), .pixelate(let rect, _), .spotlight(let rect, _):
            if case .pixelate(_, let strength) = kind, !(0...1).contains(strength) { return false }
            return ok(rect.origin) && ok(CGPoint(x: rect.maxX, y: rect.maxY)) && rect.width >= 0 && rect.height >= 0
        case .text(let origin, let string, _): return ok(origin) && !string.isEmpty && string.count <= Self.maxText
        case .step(let center): return ok(center)
        case .pen(let points), .marker(let points): return (1...Self.maxPoints).contains(points.count) && points.allSatisfy(ok)
        }
    }

    /// The area it covers, for hit testing and for dropping marks a crop leaves out.
    var bounds: CGRect {
        let pad = width * 4
        switch kind {
        case .arrow(let from, let to): return CGRect(from: from, to: to).insetBy(dx: -pad, dy: -pad)  // room for the head
        case .line(let from, let to): return CGRect(from: from, to: to).insetBy(dx: -width, dy: -width)
        case .box(let rect, _), .pixelate(let rect, _), .spotlight(let rect, _): return rect.standardized.insetBy(dx: -width, dy: -width)
        case .text(let origin, let string, _):
            let lines = string.split(separator: "\n", omittingEmptySubsequences: false)
            let font = width * Self.textScale
            let longest = Double(lines.map(\.count).max() ?? 1)
            return CGRect(x: origin.x, y: origin.y, width: longest * font * 0.6 + font, height: Double(lines.count) * font * 1.3)
        case .step(let center): return CGRect(x: center.x, y: center.y, width: 0, height: 0).insetBy(dx: -width * Self.stepScale, dy: -width * Self.stepScale)
        case .pen(let points), .marker(let points):
            let xs = points.map(\.x), ys = points.map(\.y)
            return CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!).insetBy(dx: -pad, dy: -pad)
        }
    }

    var isPixelate: Bool { if case .pixelate = kind { true } else { false } }

    /// Font size and badge radius as multiples of the stroke width.
    static let textScale = 5.0
    static let stepScale = 3.5

    /// The mark after `edit`, made to an image of `size` pixels; nil when a crop leaves it wholly outside.
    func mapped(through edit: ImageEdit, from size: CGSize) -> ImageMark? {
        let w = size.width, h = size.height
        var mark = self
        let point: (CGPoint) -> CGPoint
        switch edit {
        case .rotate(let by): point = by > 0 ? { CGPoint(x: h - $0.y, y: $0.x) } : { CGPoint(x: $0.y, y: w - $0.x) }
        case .flip(let horizontal): point = horizontal ? { CGPoint(x: w - $0.x, y: $0.y) } : { CGPoint(x: $0.x, y: h - $0.y) }
        case .crop(let fractions):
            let crop = ImageEditing.cropRect(fractions, in: size)
            guard bounds.intersects(CGRect(origin: crop.origin, size: crop.size)) else { return nil }
            point = { CGPoint(x: $0.x - crop.minX, y: $0.y - crop.minY) }
        case .resize(let width, let height):
            let sx = Double(width) / w, sy = Double(height) / h
            point = { CGPoint(x: $0.x * sx, y: $0.y * sy) }
            mark.width = max(self.width * (sx * sy).squareRoot(), 0.5)
        }
        let rect = { (r: CGRect) in CGRect(from: point(r.origin), to: point(CGPoint(x: r.maxX, y: r.maxY))) }
        switch kind {
        case .arrow(let from, let to), .line(let from, let to): mark.kind = kind.withEnds(point(from), point(to))
        case .box(let r, let ellipse): mark.kind = .box(rect(r), ellipse: ellipse)
        case .pixelate(let r, let strength): mark.kind = .pixelate(rect(r), strength: strength)
        case .spotlight(let r, let ellipse): mark.kind = .spotlight(rect(r), ellipse: ellipse)
        case .text(let origin, let string, let style):
            // Text stays upright: its top left follows the corner of its box that lands top left.
            let box = rect(CGRect(origin: origin, size: bounds.size))
            mark.kind = .text(origin: edit.isOrientationOnly ? box.origin : point(origin), string: string, style: style)
        case .step(let center): mark.kind = .step(center: point(center))
        case .pen(let points): mark.kind = .pen(points.map(point))
        case .marker(let points): mark.kind = .marker(points.map(point))
        }
        return mark
    }

    /// The marks after `edit`; ones a crop leaves out are dropped.
    static func mapped(_ marks: [ImageMark], through edit: ImageEdit, from size: CGSize) -> [ImageMark] {
        marks.compactMap { $0.mapped(through: edit, from: size) }
    }

    /// The number each step shows: its place among the steps, from 1.
    static func stepNumbers(_ marks: [ImageMark]) -> [String: Int] {
        var numbers: [String: Int] = [:]
        for mark in marks { if case .step = mark.kind { numbers[mark.id] = numbers.count + 1 } }
        return numbers
    }
}

/// How markup text looks: its font, weight, slant, and how it stands out from the image.
nonisolated struct TextStyle: Codable, Sendable, Equatable {
    enum Font: String, Codable, Sendable, CaseIterable { case system, serif, rounded, mono }
    /// Plain; a thin contrasting outline; a drop shadow; or a filled rounded box behind it.
    enum Effect: String, Codable, Sendable, CaseIterable { case plain, outline, shadow, label }
    var font: Font
    var bold: Bool
    var italic: Bool
    var effect: Effect

    /// Bold system text with an outline, as markup text always was.
    static let standard = TextStyle(font: .system, bold: true, italic: false, effect: .outline)
}

/// What the next mark is drawn with: the color and size, Pixelate's strength, Spotlight's shape and the text style.
nonisolated struct MarkStyle: Equatable, Sendable {
    var color: RGBA
    var size: MarkSize
    var strength: Double
    var ovalSpotlight: Bool
    var text: TextStyle

    /// Blocks of 1/60 of the image's shorter side, too coarse to read back.
    static let defaultStrength = log10(100.0 / 60)
    static let standard = MarkStyle(color: markupPalette[0].color, size: .medium, strength: defaultStrength, ovalSpotlight: false, text: .standard)

    /// Pixelate's block size in pixels: from 1/100 of the image's shorter side at strength 0 (still too coarse for
    /// small text) to 1/10 at 1, and never under 6 pixels.
    static func block(strength: Double, imageSize: CGSize) -> CGFloat {
        max(min(imageSize.width, imageSize.height) * pow(10, strength) / 100, 6 + 6 * strength)
    }
}

/// The three markup sizes, as a share of the image's shorter side.
nonisolated enum MarkSize: String, Codable, Sendable, CaseIterable {
    case small, medium, large

    var fraction: Double {
        switch self {
        case .small: 0.004
        case .medium: 0.008
        case .large: 0.014
        }
    }

    /// The stroke width for an image of `size` pixels, at least one pixel.
    func width(for size: CGSize) -> Double { max(fraction * min(size.width, size.height), 1) }
}

extension CGRect {
    /// The rectangle with corners `a` and `b`, in any order.
    nonisolated init(from a: CGPoint, to b: CGPoint) {
        self.init(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
    }
}

nonisolated extension ImageMark.Kind {
    /// An arrow or line with these ends, the same kind as this one.
    func withEnds(_ from: CGPoint, _ to: CGPoint) -> Self {
        if case .arrow = self { .arrow(from: from, to: to) } else { .line(from: from, to: to) }
    }
}
