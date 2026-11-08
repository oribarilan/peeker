import AppKit
import PDFKit
import PeekerKit

/// Peeker's marks as PDF annotations: builds them, reads them back, and changes their bounds and text.
nonisolated enum PDFMarks {
    static let fontSizes = 8.0...36.0
    static let signatureLineWidth = 1.5
    private static let styleKey = PDFAnnotationKey(rawValue: "/DS")
    /// A second home for a mark's id: PDFKit on macOS 26 leaves `/NM` out when it writes a file, and keeps this key.
    static let idKey = PDFAnnotationKey(rawValue: "/PeekerID")
    /// A drawing's shape, which tells it from a signature, the other ink Peeker makes.
    static let shapeKey = PDFAnnotationKey(rawValue: "/PeekerShape")

    /// The annotation's id when Peeker made it, from `/NM` or else `/PeekerID`; nil for other apps' annotations,
    /// which are never selected or changed.
    static func id(of annotation: PDFAnnotation) -> String? {
        [PDFAnnotationKey.name, idKey].lazy.compactMap { annotation.value(forAnnotationKey: $0) as? String }.first { $0.hasPrefix(PDFEdit.idPrefix) }
    }

    static func find(_ id: String, on page: PDFPage) -> PDFAnnotation? {
        page.annotations.first { Self.id(of: $0) == id }
    }

    /// A text box's size. PDFKit drops it from `/DA` when it writes the file, so it's kept in the standard `/DS`
    /// style string too.
    static func fontSize(of annotation: PDFAnnotation) -> Double? {
        guard let style = annotation.value(forAnnotationKey: styleKey) as? String,
              let match = style.firstMatch(of: /font:[^;]*?([0-9.]+)pt/), let size = Double(match.1) else { return nil }
        return min(max(size, fontSizes.lowerBound), fontSizes.upperBound)  // a file can say anything
    }

    static func annotation(for mark: PDFMark) -> PDFAnnotation {
        let annotation: PDFAnnotation
        switch mark.kind {
        case .highlight(let color):
            annotation = PDFAnnotation(bounds: mark.rect, forType: .highlight, withProperties: nil)
            annotation.color = NSColor(srgbRed: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
        case .textBox(let text, let fontSize, let style):
            annotation = PDFAnnotation(bounds: mark.rect, forType: .freeText, withProperties: nil)
            let border = PDFBorder()
            border.lineWidth = 0
            annotation.border = border
            setText(text, fontSize: fontSize, style: style ?? .standard, of: annotation)
        case .signature(let strokes):
            annotation = PDFAnnotation(bounds: mark.rect, forType: .ink, withProperties: nil)
            annotation.color = .black
            let border = PDFBorder()
            border.lineWidth = signatureLineWidth
            annotation.border = border
            for path in paths(strokes, size: mark.rect.size) { annotation.add(path) }
        case .drawing(let drawing):
            annotation = PDFAnnotation(bounds: mark.rect, forType: .ink, withProperties: nil)
            annotation.setValue(drawing.shape.rawValue, forAnnotationKey: shapeKey)
            draw(drawing, on: annotation)
        }
        setID(mark.id, on: annotation)
        annotation.userName = nil  // PDFKit fills in the Mac account's full name, which would go out with the file
        return annotation
    }

    /// Names the annotation as Peeker's mark: `/NM` for every PDF app, `/PeekerID` for when `/NM` doesn't survive.
    static func setID(_ id: String, on annotation: PDFAnnotation) {
        annotation.setValue(id, forAnnotationKey: .name)
        annotation.setValue(id, forAnnotationKey: idKey)
    }

    /// The kind of mark an annotation can be; nil for kinds Peeker doesn't make.
    static func type(of annotation: PDFAnnotation) -> MarkType? {
        switch annotation.type {
        case "Highlight": .highlight
        case "FreeText": .textBox
        // A shape Peeker can't read is left alone like another app's annotation.
        case "Ink": annotation.value(forAnnotationKey: shapeKey) == nil ? .signature : drawing(of: annotation) == nil ? nil : .drawing
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
            kind = .textBox(text: annotation.contents ?? "", fontSize: fontSize(of: annotation) ?? 12, style: style(of: annotation).nilIfStandard)
        case .signature:
            let size = annotation.bounds.size
            guard size.width > 0, size.height > 0 else { return nil }
            kind = .signature(strokes: relativeStrokes(of: annotation))
        case .drawing:
            guard let drawing = drawing(of: annotation) else { return nil }
            kind = .drawing(drawing)
        }
        return PDFMark(id: id, page: page, rect: annotation.bounds, kind: kind)
    }

    /// Moves or resizes; a signature's strokes scale with it, a drawing is rebuilt to fit, and a text box keeps its size.
    static func setBounds(_ rect: CGRect, of annotation: PDFAnnotation) {
        let old = annotation.bounds
        if let drawing = drawing(of: annotation) {
            annotation.bounds = rect
            if rect.size != old.size { draw(drawing.rebuilt(in: rect.size), on: annotation) }
            return
        }
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
            // PDFKit redraws a moved box from its own font and colors, which it doesn't read back from a saved file.
            applyLook(style(of: annotation), fontSize: size, to: annotation)
        }
        annotation.bounds = rect
    }

    /// A drawing's new color and width; an arrow's head follows the width.
    static func setLook(color: RGBA, width: Double, of annotation: PDFAnnotation) {
        guard var drawing = drawing(of: annotation) else { return }
        (drawing.color, drawing.width) = (color, width)
        draw(drawing.rebuilt(in: annotation.bounds.size), on: annotation)
    }

    /// The drawing an ink annotation of Peeker's shows; nil for a signature or a shape Peeker doesn't know.
    static func drawing(of annotation: PDFAnnotation) -> PDFDrawing? {
        guard annotation.type == "Ink", let name = annotation.value(forAnnotationKey: shapeKey) as? String,
              let shape = PDFDrawing.Shape(rawValue: name.hasPrefix("/") ? String(name.dropFirst()) : name),
              annotation.bounds.width > 0, annotation.bounds.height > 0,
              let color = annotation.color.usingColorSpace(.sRGB) else { return nil }
        // In whole 8-bit steps, as the file keeps them, so a swatch's color reads back as the swatch's.
        let step = { (value: CGFloat) in (Double(value) * 255).rounded() / 255 }
        let drawing = PDFDrawing(shape: shape, strokes: relativeStrokes(of: annotation),
                                 color: RGBA(red: step(color.redComponent), green: step(color.greenComponent), blue: step(color.blueComponent), alpha: color.alphaComponent),
                                 width: Double(annotation.border?.lineWidth ?? 1))
        return drawing.isValid ? drawing : nil
    }

    /// Puts `drawing`'s strokes, color and width on the annotation, replacing what it had.
    private static func draw(_ drawing: PDFDrawing, on annotation: PDFAnnotation) {
        for path in annotation.paths ?? [] { annotation.remove(path) }
        annotation.color = nsColor(drawing.color)
        let border = PDFBorder()
        border.lineWidth = drawing.width
        annotation.border = border
        for path in paths(drawing.strokes, size: annotation.bounds.size, lineWidth: drawing.width) { annotation.add(path) }
    }

    /// An ink annotation's strokes as points within 0...1 of its bounds.
    private static func relativeStrokes(of annotation: PDFAnnotation) -> [[CGPoint]] {
        let size = annotation.bounds.size
        return (annotation.paths ?? []).map { points(of: $0).map { CGPoint(x: $0.x / size.width, y: $0.y / size.height) } }
    }

    static func setText(_ text: String, fontSize: Double, style: TextBoxStyle, of annotation: PDFAnnotation) {
        annotation.contents = text
        applyLook(style, fontSize: fontSize, to: annotation)
        // Digits other apps read, whatever the Mac's language.
        let size = fontSize.formatted(.number.grouping(.never).locale(Locale(identifier: "en_US_POSIX")))
        let box = style.boxed ? "; background-color: #\(hex(style.color))" : ""
        annotation.setValue("font: \(style.fontName) \(size)pt; color: #\(hex(style.textColor))\(box)", forAnnotationKey: styleKey)
    }

    private static func applyLook(_ style: TextBoxStyle, fontSize: Double, to annotation: PDFAnnotation) {
        annotation.font = NSFont(name: style.fontName, size: fontSize)
        annotation.fontColor = nsColor(style.textColor)
        annotation.color = style.boxed ? nsColor(style.color) : .clear
    }

    /// A text box's style, read from `/DS`, which survives saving where PDFKit's font and colors may not.
    static func style(of annotation: PDFAnnotation) -> TextBoxStyle {
        var style = TextBoxStyle.standard
        guard let string = annotation.value(forAnnotationKey: styleKey) as? String else { return style }
        if let name = string.firstMatch(of: /font:\s*([^\s;]+)\s/), let face = TextBoxStyle.face(of: String(name.1)) {
            (style.font, style.bold, style.italic) = (face.font, face.bold, face.italic)
        }
        if let fill = string.firstMatch(of: /background-color:\s*#([0-9A-Fa-f]{6})/), let color = rgba(String(fill.1)) {
            style.boxed = true
            style.color = color
        } else if let ink = string.firstMatch(of: /(?:^|;)\s*color:\s*#([0-9A-Fa-f]{6})/), let color = rgba(String(ink.1)) {
            style.color = color
        }
        return style
    }

    private static func rgba(_ hex: String) -> RGBA? {
        guard let value = UInt32(hex, radix: 16) else { return nil }
        let channel = { (shift: UInt32) in Double((value >> shift) & 0xFF) / 255 }
        return RGBA(red: channel(16), green: channel(8), blue: channel(0), alpha: 1)
    }

    private static func nsColor(_ color: RGBA) -> NSColor { NSColor(srgbRed: color.red, green: color.green, blue: color.blue, alpha: color.alpha) }

    private static func hex(_ color: RGBA) -> String {
        [color.red, color.green, color.blue].map { String(format: "%02X", Int((min(max($0, 0), 1) * 255).rounded())) }.joined()
    }

    /// Strokes of 0...1 points as paths in annotation space, scaled to `size`.
    static func paths(_ strokes: [[CGPoint]], size: CGSize, lineWidth: Double = signatureLineWidth) -> [NSBezierPath] {
        strokes.compactMap { stroke in
            guard let first = stroke.first else { return nil }
            let path = NSBezierPath()
            path.lineWidth = lineWidth
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
