import CoreGraphics
import Foundation
import PeekerKit

/// A drawing or stamp from the markup strip, saved as an ink annotation: its shape, its strokes as points within 0...1
/// of the mark's rect (origin at the bottom left, as signatures store theirs), its color and its line width in points.
nonisolated struct PDFDrawing: Codable, Sendable, Equatable {
    enum Shape: String, Codable, Sendable, CaseIterable {
        case pen, line, arrow, box, ellipse, x, check, circle, dot

        /// Dropped by a click as well as fitted to a drag.
        var isStamp: Bool { [.x, .check, .circle, .dot].contains(self) }
        /// Hit along its strokes rather than anywhere in its rect: lines and outlines, so what's inside stays clickable.
        var isHitAlongStrokes: Bool { [.pen, .line, .arrow, .box, .ellipse, .circle].contains(self) }
        /// Its rect follows its strokes, rather than the strokes filling a dragged rect.
        var isFreehand: Bool { [.pen, .line, .arrow].contains(self) }
    }

    var shape: Shape
    var strokes: [[CGPoint]]
    var color: RGBA
    var width: Double

    static let widths = 0.25...40.0
    /// A dot's width is half its side, so a big dot is a wide one.
    static let maxDotWidth = 2_000.0
    static let maxStrokes = 500, maxPoints = 20_000

    /// Opaque, a sane width, and something to draw within reach of the rect (an arrow's head can poke out a little).
    var isValid: Bool {
        color.isValid && color.alpha == 1 && width.isFinite
            && (shape == .dot ? (Self.widths.lowerBound...Self.maxDotWidth) : Self.widths).contains(width)
            && !strokes.isEmpty && strokes.count <= Self.maxStrokes && strokes.allSatisfy { !$0.isEmpty }
            && strokes.reduce(0) { $0 + $1.count } <= Self.maxPoints
            && strokes.allSatisfy { $0.allSatisfy { (-1...2).contains($0.x) && (-1...2).contains($0.y) } }
    }

    /// The mark a drag from `from` to `to` makes, in page space; Pen takes its stroke from `points`. Nil when there's
    /// nothing to draw.
    static func make(_ shape: Shape, from: CGPoint, to: CGPoint, points: [CGPoint], color: RGBA, width: Double) -> (rect: CGRect, drawing: PDFDrawing)? {
        let strokes: [[CGPoint]]
        var width = width
        var rect = CGRect(from: from, to: to)
        switch shape {
        case .pen:
            strokes = [thinned(points)]
        case .line:
            strokes = [[from, to]]
        case .arrow:
            strokes = arrow(from: from, to: to, width: width)
        case .dot:
            let side = min(rect.width, rect.height)
            rect = CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side)
            width = side / 2
            strokes = framed(shape, in: rect, width: width)
        default:
            strokes = framed(shape, in: rect, width: width)
        }
        guard let first = strokes.first?.first else { return nil }
        if shape.isFreehand {
            // The strokes' extent, with room for the line's width.
            let all = strokes.flatMap { $0 }
            let xs = all.map(\.x), ys = all.map(\.y)
            rect = CGRect(x: xs.min() ?? first.x, y: ys.min() ?? first.y, width: (xs.max() ?? 0) - (xs.min() ?? 0), height: (ys.max() ?? 0) - (ys.min() ?? 0))
                .insetBy(dx: -width / 2 - 1, dy: -width / 2 - 1)
        }
        guard rect.width > 0, rect.height > 0 else { return nil }
        let relative = strokes.map { $0.map { CGPoint(x: ($0.x - rect.minX) / rect.width, y: ($0.y - rect.minY) / rect.height) } }
        return (rect, PDFDrawing(shape: shape, strokes: relative, color: color, width: width))
    }

    /// The same drawing in a rect of `size`: an arrow's head keeps its size in points, a dot stays round and filled, and
    /// a framed shape stays half its width inside the rect. Pen strokes and lines scale with it. Moving, resizing and saving all go through this, so they agree.
    func rebuilt(in size: CGSize) -> PDFDrawing {
        guard size.width > 0, size.height > 0 else { return self }
        var drawing = self
        let toPoints = { (p: CGPoint) in CGPoint(x: p.x * size.width, y: p.y * size.height) }
        let toRelative = { (p: CGPoint) in CGPoint(x: p.x / size.width, y: p.y / size.height) }
        switch shape {
        case .arrow:
            guard let shaft = strokes.first, let from = shaft.first, let to = shaft.last else { return self }
            drawing.strokes = Self.arrow(from: toPoints(from), to: toPoints(to), width: width).map { $0.map(toRelative) }
        case .dot:
            let side = min(size.width, size.height)
            drawing.width = side / 2
            let square = CGRect(x: (size.width - side) / 2, y: (size.height - side) / 2, width: side, height: side)
            drawing.strokes = Self.framed(.dot, in: square, width: drawing.width).map { $0.map(toRelative) }
        case .box, .ellipse, .circle, .x, .check:
            drawing.strokes = Self.framed(shape, in: CGRect(origin: .zero, size: size), width: width).map { $0.map(toRelative) }
        case .pen, .line: break
        }
        return drawing
    }

    /// A shaft and a head, two barbs and the tip in one stroke, long enough to see at any width.
    private static func arrow(from: CGPoint, to: CGPoint, width: Double) -> [[CGPoint]] {
        let length = max(width * 4, 6)
        let angle = atan2(to.y - from.y, to.x - from.x)
        let barb = { (turn: Double) in CGPoint(x: to.x - length * cos(angle + turn), y: to.y - length * sin(angle + turn)) }
        return [[from, to], [barb(0.5), to, barb(-0.5)]]
    }

    /// The shapes drawn inside a rect, kept half a line width in so the whole line stays inside it.
    private static func framed(_ shape: Shape, in rect: CGRect, width: Double) -> [[CGPoint]] {
        let r = rect.insetBy(dx: min(width / 2, rect.width / 2), dy: min(width / 2, rect.height / 2))
        let at = { (x: Double, y: Double) in CGPoint(x: r.minX + x * r.width, y: r.minY + y * r.height) }
        let oval = { (box: CGRect) in
            (0...64).map { step in
                let angle = Double(step) / 64 * 2 * .pi
                return CGPoint(x: box.midX + box.width / 2 * cos(angle), y: box.midY + box.height / 2 * sin(angle))
            }
        }
        switch shape {
        case .box: return [[at(0, 0), at(1, 0), at(1, 1), at(0, 1), at(0, 0)]]
        case .ellipse, .circle: return [oval(r)]
        case .x: return [[at(0, 0), at(1, 1)], [at(0, 1), at(1, 0)]]
        case .check: return [[at(0, 0.5), at(0.35, 0.1), at(1, 0.9)]]
        // A circle half the side across, stroked half the side wide, covers the whole square.
        case .dot: return [oval(rect.insetBy(dx: rect.width / 4, dy: rect.height / 4))]
        case .pen, .line, .arrow: return []
        }
    }

    /// The pen's points less those within half a point of the last one kept, and at most `maxPoints`.
    private static func thinned(_ points: [CGPoint]) -> [CGPoint] {
        var kept: [CGPoint] = []
        for point in points where kept.last.map({ hypot(point.x - $0.x, point.y - $0.y) >= 0.5 }) ?? true { kept.append(point) }
        return Array(kept.prefix(maxPoints))
    }
}

private extension CGRect {
    nonisolated init(from a: CGPoint, to b: CGPoint) {
        self.init(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
    }
}

/// The strip's S, M and L: a line width, and the side of a stamp dropped by a click.
nonisolated enum MarkupSize: String, Codable, Sendable, CaseIterable {
    case small, medium, large

    var width: Double {
        switch self {
        case .small: 1
        case .medium: 2
        case .large: 3.5
        }
    }

    var stampSide: Double {
        switch self {
        case .small: 14
        case .medium: 22
        case .large: 34
        }
    }

    /// The size a drawing shows in the strip: by its width, or for a dot, whose width is its own, by its side.
    init(of drawing: PDFDrawing, in rect: CGRect) {
        if drawing.shape == .dot {
            let side = min(rect.width, rect.height)
            self = Self.allCases.min { abs($0.stampSide - side) < abs($1.stampSide - side) } ?? .medium
        } else {
            self = Self.allCases.min { abs($0.width - drawing.width) < abs($1.width - drawing.width) } ?? .medium
        }
    }
}

extension PDFDrawing {
    /// Whether `point`, in the space of a rect of `size` at the origin, is within `tolerance` of a stroke's line.
    func isNear(_ point: CGPoint, in size: CGSize, tolerance: Double) -> Bool {
        let reach = tolerance + width / 2
        let scaled = strokes.map { $0.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) } }
        return scaled.contains { stroke in
            if stroke.count == 1 { return hypot(point.x - stroke[0].x, point.y - stroke[0].y) <= reach }
            return zip(stroke, stroke.dropFirst()).contains { Self.distance(point, toSegment: $0, $1) <= reach }
        }
    }

    private static func distance(_ p: CGPoint, toSegment a: CGPoint, _ b: CGPoint) -> Double {
        let dx = b.x - a.x, dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        let t = lengthSquared == 0 ? 0 : max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared))
        return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
    }
}
