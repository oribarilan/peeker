import AppKit
import PDFKit
import PeekerKit

/// Turns `PDFEdit`s into annotation changes on a `PDFDocument`. The view's document takes them live on the main
/// thread; saving applies the same edits to a fresh copy off it.
nonisolated enum PDFMarks {
    /// Text boxes use Helvetica: every PDF app has it, while the system font's name means nothing outside macOS.
    static let fontName = "Helvetica"
    static let fontSizes = 8.0...36.0
    static let signatureLineWidth = 1.5
    private static let styleKey = PDFAnnotationKey(rawValue: "/DS")
    private static let maxText = 10_000
    private static let maxStrokes = 500, maxPoints = 20_000

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

    /// The mark an annotation of Peeker's shows, so a removal can be undone; nil for other annotations.
    static func mark(of annotation: PDFAnnotation, page: Int) -> PDFMark? {
        guard let id = id(of: annotation) else { return nil }
        let kind: PDFMark.Kind
        switch annotation.type {
        case "Highlight":
            guard let color = annotation.color.usingColorSpace(.sRGB) else { return nil }
            kind = .highlight(RGBA(red: color.redComponent, green: color.greenComponent, blue: color.blueComponent, alpha: color.alphaComponent))
        case "FreeText":
            kind = .textBox(text: annotation.contents ?? "", fontSize: fontSize(of: annotation) ?? 12)
        case "Ink":
            let size = annotation.bounds.size
            guard size.width > 0, size.height > 0 else { return nil }
            kind = .signature(strokes: (annotation.paths ?? []).map { points(of: $0).map { CGPoint(x: $0.x / size.width, y: $0.y / size.height) } })
        default:
            return nil
        }
        return PDFMark(id: id, page: page, rect: annotation.bounds, kind: kind)
    }

    /// Applies `edit` to `document`, or throws without changing it when the edit doesn't fit. `fileName` is for messages.
    static func apply(_ edit: PDFEdit, to document: PDFDocument, fileName: String) throws(PluginError) {
        switch edit {
        case .add(let mark):
            let page = try page(mark.page, of: document, for: mark.type, fileName: fileName)
            guard mark.id.hasPrefix(PDFEdit.idPrefix), mark.id.count <= 64, isValid(mark.rect, on: page), isValid(mark.kind) else {
                throw PluginError("Can't save the \(mark.type.name) on page \(mark.page + 1): its position, size or contents are invalid.")
            }
            page.addAnnotation(annotation(for: mark))
        case .setBounds(let id, let type, let index, let rect):
            let page = try page(index, of: document, for: type, fileName: fileName)
            let annotation = try find(id, type, verb: "move", on: page, index, fileName: fileName)
            guard isValid(rect, on: page) else {
                throw PluginError("Can't save the \(type.name) on page \(index + 1): its new position or size is invalid.")
            }
            setBounds(rect, of: annotation)
        case .setText(let id, let index, let text, let fontSize, let rect):
            let page = try page(index, of: document, for: .textBox, fileName: fileName)
            let annotation = try find(id, .textBox, verb: "change", on: page, index, fileName: fileName)
            guard isValid(rect, on: page), isValid(.textBox(text: text, fontSize: fontSize)) else {
                throw PluginError("Can't save the text box on page \(index + 1): its text, size or position is invalid.")
            }
            annotation.bounds = rect
            setText(text, fontSize: fontSize, of: annotation)
        case .delete(let id, let type, let index):
            let page = try page(index, of: document, for: type, fileName: fileName)
            page.removeAnnotation(try find(id, type, verb: "remove", on: page, index, fileName: fileName))
        case .field(let name, let value):
            let widgets = (0..<document.pageCount).flatMap { document.page(at: $0)?.annotations ?? [] }.filter { $0.fieldName == name }
            guard !widgets.isEmpty, value.count <= maxText else {
                throw PluginError("Can't save the field “\(name)”: it's no longer in “\(fileName)”.")
            }
            for widget in widgets { widget.widgetStringValue = value }
        }
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

    private static func setText(_ text: String, fontSize: Double, of annotation: PDFAnnotation) {
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

    private static func page(_ index: Int, of document: PDFDocument, for type: MarkType, fileName: String) throws(PluginError) -> PDFPage {
        guard (0..<document.pageCount).contains(index), let page = document.page(at: index) else {
            // `&+`: the index comes from a file, and Int.max must not trap.
            throw PluginError("Can't save the \(type.name) on page \(index &+ 1): “\(fileName)” has \(document.pageCount) pages.")
        }
        return page
    }

    private static func find(_ id: String, _ type: MarkType, verb: String, on page: PDFPage, _ index: Int, fileName: String) throws(PluginError) -> PDFAnnotation {
        guard let annotation = find(id, on: page) else {
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
            text.count <= maxText && fontSizes.contains(fontSize)
        case .signature(let strokes):
            strokes.count <= maxStrokes && strokes.reduce(0) { $0 + $1.count } <= maxPoints
                && strokes.allSatisfy { $0.allSatisfy { (-0.01...1.01).contains($0.x) && (-0.01...1.01).contains($0.y) } }
        }
    }
}
