import AppKit
import PDFKit
import PeekerKit

/// Peeker's marks as PDF annotations: builds them, reads them back, and changes their bounds and text.
nonisolated enum PDFMarks {
    /// Text boxes use Helvetica: every PDF app has it, while the system font's name means nothing outside macOS.
    static let fontName = "Helvetica"
    static let fontSizes = 8.0...36.0
    static let signatureLineWidth = 1.5
    private static let styleKey = PDFAnnotationKey(rawValue: "/DS")

    /// The annotation's name when Peeker made it, else nil: other apps' annotations are never selected or changed.
    static func id(of annotation: PDFAnnotation) -> String? {
        guard let name = annotation.value(forAnnotationKey: .name) as? String, name.hasPrefix(PDFEdit.idPrefix) else { return nil }
        return name
    }

    static func find(_ id: String, on page: PDFPage) -> PDFAnnotation? {
        page.annotations.first { Self.id(of: $0) == id }
    }

    /// A text box's size. PDFKit drops it from `/DA` when it writes the file, so it's kept in the standard `/DS`
    /// style string too.
    static func fontSize(of annotation: PDFAnnotation) -> Double? {
        guard let style = annotation.value(forAnnotationKey: styleKey) as? String,
              let match = style.firstMatch(of: /font:[^;]*?([0-9.]+)pt/), let size = Double(match.1) else { return nil }
        return size
    }

    static func annotation(for mark: PDFMark) -> PDFAnnotation {
        let annotation: PDFAnnotation
        switch mark.kind {
        case .highlight(let color):
            annotation = PDFAnnotation(bounds: mark.rect, forType: .highlight, withProperties: nil)
            annotation.color = NSColor(srgbRed: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
        case .textBox(let text, let fontSize):
            annotation = PDFAnnotation(bounds: mark.rect, forType: .freeText, withProperties: nil)
            annotation.color = .clear
            annotation.fontColor = .black
            let border = PDFBorder()
            border.lineWidth = 0
            annotation.border = border
            setText(text, fontSize: fontSize, of: annotation)
        case .signature(let strokes):
            annotation = PDFAnnotation(bounds: mark.rect, forType: .ink, withProperties: nil)
            annotation.color = .black
            let border = PDFBorder()
            border.lineWidth = signatureLineWidth
            annotation.border = border
            for path in paths(strokes, size: mark.rect.size) { annotation.add(path) }
        }
        annotation.setValue(mark.id, forAnnotationKey: .name)
        return annotation
    }

    /// The kind of mark an annotation can be; nil for kinds Peeker doesn't make.
    static func type(of annotation: PDFAnnotation) -> MarkType? {
        switch annotation.type {
        case "Highlight": .highlight
        case "FreeText": .textBox
        case "Ink": .signature
        default: nil
        }
    }

    /// The mark an annotation of Peeker's shows, so a removal can be undone; nil for other annotations.
    static func mark(of annotation: PDFAnnotation, page: Int) -> PDFMark? {
        guard let id = id(of: annotation), let type = Self.type(of: annotation) else { return nil }
        let kind: PDFMark.Kind
        switch type {
        case .highlight:
            guard let color = annotation.color.usingColorSpace(.sRGB) else { return nil }
            kind = .highlight(RGBA(red: color.redComponent, green: color.greenComponent, blue: color.blueComponent, alpha: color.alphaComponent))
        case .textBox:
            kind = .textBox(text: annotation.contents ?? "", fontSize: fontSize(of: annotation) ?? 12)
        case .signature:
            let size = annotation.bounds.size
            guard size.width > 0, size.height > 0 else { return nil }
            kind = .signature(strokes: (annotation.paths ?? []).map { points(of: $0).map { CGPoint(x: $0.x / size.width, y: $0.y / size.height) } })
        }
        return PDFMark(id: id, page: page, rect: annotation.bounds, kind: kind)
    }

    /// Moves or resizes; a signature's strokes scale with it, and a text box keeps its size.
    static func setBounds(_ rect: CGRect, of annotation: PDFAnnotation) {
        let old = annotation.bounds
        if annotation.type == "Ink", old.width > 0, old.height > 0, old.size != rect.size {
            let scale = CGAffineTransform(scaleX: rect.width / old.width, y: rect.height / old.height)
            for path in annotation.paths ?? [] {
                annotation.remove(path)
                let scaled = path.copy() as! NSBezierPath
                scaled.transform(using: AffineTransform(m11: scale.a, m12: scale.b, m21: scale.c, m22: scale.d, tX: 0, tY: 0))
                annotation.add(scaled)
            }
        }
        if annotation.type == "FreeText", let size = fontSize(of: annotation) {
            annotation.font = NSFont(name: fontName, size: size)  // PDFKit redraws a loaded box at its default size otherwise
        }
        annotation.bounds = rect
    }

    static func setText(_ text: String, fontSize: Double, of annotation: PDFAnnotation) {
        annotation.contents = text
        annotation.font = NSFont(name: fontName, size: fontSize)
        annotation.setValue("font: \(fontName) \(fontSize.formatted(.number.grouping(.never)))pt; color: #000000", forAnnotationKey: styleKey)
    }

    /// Strokes of 0...1 points as paths in annotation space, scaled to `size`.
    static func paths(_ strokes: [[CGPoint]], size: CGSize) -> [NSBezierPath] {
        strokes.compactMap { stroke in
            guard let first = stroke.first else { return nil }
            let path = NSBezierPath()
            path.lineWidth = signatureLineWidth
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.move(to: CGPoint(x: first.x * size.width, y: first.y * size.height))
            for point in stroke.dropFirst() { path.line(to: CGPoint(x: point.x * size.width, y: point.y * size.height)) }
            if stroke.count == 1 { path.line(to: CGPoint(x: first.x * size.width + 0.1, y: first.y * size.height)) }  // a dot
            return path
        }
    }

    private static func points(of path: NSBezierPath) -> [CGPoint] {
        var points = [CGPoint](repeating: .zero, count: 3)
        return (0..<path.elementCount).compactMap { index in
            switch path.element(at: index, associatedPoints: &points) {
            case .moveTo, .lineTo: points[0]
            case .curveTo, .cubicCurveTo: points[2]
            case .quadraticCurveTo: points[1]
            default: nil
            }
        }
    }

}
