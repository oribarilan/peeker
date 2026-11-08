import AppKit
import PeekerKit

/// Takes the mouse over the image while the markup strip shows: draws a mark with the armed tool, selects, moves and
/// resizes marks, deletes the selected one, and edits text. One edit per gesture; the mark in progress is drawn by
/// the document, so it looks as it will be saved.
final class MarkupOverlay: NSView, NSTextFieldDelegate {
    /// What the overlay reads from and hands to the document.
    struct Document {
        var marks: () -> [ImageMark]
        var pixelSize: () -> CGSize
        var style: () -> MarkStyle
        /// Shows the image without the mark with this id, while it's dragged; nil shows every mark again.
        var hide: (String?) -> Void
        /// Shows a spotlight being drawn or dragged with the other marks; nil stops.
        var preview: (ImageMark?) -> Void
        var put: (ImageMark) -> Void
        var remove: (String) -> Void
        /// The selection changed, so the strip can show its color and size.
        var selected: (ImageMark?) -> Void
    }

    private enum Drag {
        case drawing(start: CGPoint)
        case moving(from: CGPoint, original: ImageMark)
        /// A corner of a box-like mark, or an end of an arrow, with the other end fixed.
        case reshaping(fixed: CGPoint, original: ImageMark, end: Bool)
    }

    var tool: MarkupTool?
    private(set) var selectedID: String? {
        didSet {
            needsDisplay = true
            document.selected(selected)
        }
    }
    private var drag: Drag?
    private var draft: ImageMark?
    private weak var canvas: ImageCanvas?
    private let document: Document
    private var field: NSTextField?
    private var editing: ImageMark?

    init(canvas: ImageCanvas, document: Document) {
        self.canvas = canvas
        self.document = document
        super.init(frame: canvas.bounds)
        autoresizingMask = [.width, .height]
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { false }

    var selected: ImageMark? { selectedID.flatMap { id in document.marks().first { $0.id == id } } }

    func select(_ id: String?) { selectedID = id }

    // MARK: Coordinates

    private var imageRect: CGRect { canvas?.imageRect ?? .zero }

    /// A point in this view as image pixels from the top left.
    func pixel(_ point: CGPoint) -> CGPoint {
        let rect = imageRect, size = document.pixelSize()
        guard rect.width > 0, rect.height > 0 else { return .zero }
        return CGPoint(x: (point.x - rect.minX) / rect.width * size.width, y: (rect.maxY - point.y) / rect.height * size.height)
    }

    /// Image pixels as a point in this view.
    func viewPoint(_ pixel: CGPoint) -> CGPoint {
        let rect = imageRect, size = document.pixelSize()
        guard size.width > 0, size.height > 0 else { return .zero }
        return CGPoint(x: rect.minX + pixel.x / size.width * rect.width, y: rect.maxY - pixel.y / size.height * rect.height)
    }

    private func viewRect(_ rect: CGRect) -> CGRect { CGRect(from: viewPoint(rect.origin), to: viewPoint(CGPoint(x: rect.maxX, y: rect.maxY))) }

    /// How far a click may miss, in image pixels: 6 points on screen.
    private var tolerance: CGFloat {
        let rect = imageRect
        return rect.width > 0 ? 6 * document.pixelSize().width / rect.width : 6
    }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        endTextEditing()
        let point = pixel(convert(event.locationInWindow, from: nil))
        if event.clickCount == 2, let mark = hit(point), case .text = mark.kind { return beginTextEditing(mark) }
        if let mark = selected, let handle = handle(of: mark, at: point) {
            drag = .reshaping(fixed: handle.fixed, original: mark, end: handle.end)
            return
        }
        if let mark = hit(point) {
            selectedID = mark.id
            drag = .moving(from: point, original: mark)
            return
        }
        // The image is drawn again only once a drag really moves something, not on every event.
        selectedID = nil
        guard let tool else { return }
        let style = document.style(), width = style.size.width(for: document.pixelSize())
        let option = event.modifierFlags.contains(.option)
        switch tool {
        case .step:
            document.put(ImageMark(id: ImageMark.newID(), kind: .step(center: point), color: style.color, size: style.size, width: width))
        case .text:
            beginTextEditing(ImageMark(id: ImageMark.newID(), kind: .text(origin: point, string: " ", style: Self.textStyle(style.text, label: option)), color: style.color,
                                       size: style.size, width: width), new: true)
        default:
            draft = ImageMark(id: ImageMark.newID(), kind: Self.kind(tool, from: point, to: point, ellipse: option, style: style), color: style.color,
                              size: style.size, width: width)
            drag = .drawing(start: point)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let drag else { return }
        let point = pixel(convert(event.locationInWindow, from: nil))
        switch drag {
        case .drawing(let start):
            guard var mark = draft, let tool else { return }
            switch (tool, mark.kind) {
            case (.pen, .pen(let points)): mark.kind = .pen(Self.extended(points, with: point, minimum: tolerance / 3))
            case (.marker, .marker(let points)): mark.kind = .marker(Self.extended(points, with: point, minimum: tolerance / 3))
            default: mark.kind = Self.kind(tool, from: start, to: point, ellipse: event.modifierFlags.contains(.option), style: document.style())
            }
            draft = mark
        case .moving(let from, let original):
            if draft == nil { document.hide(original.id) }
            draft = original.moved(by: CGPoint(x: point.x - from.x, y: point.y - from.y))
        case .reshaping(let fixed, let original, let end):
            if draft == nil { document.hide(original.id) }
            draft = original.reshaped(fixed: fixed, moving: point, end: end)
        }
        if let draft, case .spotlight = draft.kind { document.preview(draft.isVisible(tolerance: tolerance / 2) ? draft : nil) }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            drag = nil
            draft = nil
            needsDisplay = true
        }
        guard let draft else { return }
        guard draft.isValid, draft.isVisible(tolerance: tolerance / 2) else { return document.hide(nil) }
        if case .moving(_, let original) = drag, original == draft { return document.hide(nil) }
        document.put(draft)
        if case .drawing = drag { selectedID = nil } else { selectedID = draft.id }
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 51, 117:  // Delete, Forward Delete
            guard let id = selectedID else { return super.keyDown(with: event) }
            selectedID = nil
            document.remove(id)
        case 53: cancelOperation(nil)  // Escape
        default: super.keyDown(with: event)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        if drag != nil {
            drag = nil
            draft = nil
            document.hide(nil)
        } else if selectedID != nil {
            selectedID = nil
        } else {
            tool = nil
            document.selected(nil)
        }
        needsDisplay = true
    }

    // MARK: Text

    private func beginTextEditing(_ mark: ImageMark, new: Bool = false) {
        guard case .text(let origin, let string, _) = mark.kind else { return }
        editing = mark
        selectedID = new ? nil : mark.id
        let field = NSTextField(string: new ? "" : string)
        style(field, as: mark)
        field.drawsBackground = false
        field.isBordered = false
        field.focusRingType = .none
        field.delegate = self
        field.setAccessibilityLabel("Markup text")
        let top = viewPoint(origin)
        field.frame = NSRect(x: top.x, y: top.y - field.intrinsicContentSize.height, width: max(bounds.maxX - top.x, 80), height: field.intrinsicContentSize.height)
        addSubview(field)
        window?.makeFirstResponder(field)
        self.field = field
    }

    /// The field in the text's font, size and color, as it will be drawn.
    private func style(_ field: NSTextField, as mark: ImageMark) {
        guard case .text(_, _, let style) = mark.kind else { return }
        let scale = imageRect.width / max(document.pixelSize().width, 1)
        field.font = MarkRenderer.font(style, size: max(mark.width * ImageMark.textScale * scale, 9))
        field.textColor = NSColor(cgColor: mark.color.cgColor)
    }

    /// The text being typed, new or a mark being changed; nil when none is.
    var editingMark: ImageMark? { editing }

    /// Changes the text being typed, so a color, size or style picked meanwhile lands with it instead of being undone
    /// when typing ends. False when no text is being typed.
    func restyleEditing(_ change: (inout ImageMark) -> Void) -> Bool {
        guard var mark = editing, let field else { return false }
        change(&mark)
        editing = mark
        style(field, as: mark)
        return true
    }

    func controlTextDidEndEditing(_ notification: Notification) { endTextEditing() }

    /// Puts the typed text in place, or nothing when it's empty; empty on an existing mark deletes it.
    func endTextEditing() {
        guard let field, var mark = editing, case .text(let origin, _, let style) = mark.kind else { return }
        self.field = nil
        editing = nil
        let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        field.removeFromSuperview()
        let exists = document.marks().contains { $0.id == mark.id }
        if text.isEmpty {
            if exists { document.remove(mark.id) }
            return
        }
        mark.kind = .text(origin: origin, string: String(text.prefix(ImageMark.maxText)), style: style)
        document.put(mark)
        window?.makeFirstResponder(self)
    }

    // MARK: Finding marks

    /// The topmost mark at `point`.
    func hit(_ point: CGPoint) -> ImageMark? {
        document.marks().reversed().first { $0.contains(point, tolerance: tolerance) }
    }

    /// The corner or end of `mark` under `point`, with the point that stays put.
    private func handle(of mark: ImageMark, at point: CGPoint) -> (fixed: CGPoint, end: Bool)? {
        let near = { (p: CGPoint) in hypot(p.x - point.x, p.y - point.y) <= self.tolerance * 1.5 }
        switch mark.kind {
        case .arrow(let from, let to), .line(let from, let to):
            if near(to) { return (from, true) }
            if near(from) { return (to, false) }
        case .box(let rect, _), .pixelate(let rect, _), .spotlight(let rect, _):
            let r = rect.standardized
            let corners = [CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.maxX, y: r.maxY), CGPoint(x: r.minX, y: r.maxY)]
            for (index, corner) in corners.enumerated() where near(corner) { return (corners[(index + 2) % 4], true) }
        default: break
        }
        return nil
    }

    private static func kind(_ tool: MarkupTool, from start: CGPoint, to point: CGPoint, ellipse: Bool, style: MarkStyle) -> ImageMark.Kind {
        let rect = CGRect(from: start, to: point)
        switch tool {
        case .arrow: return .arrow(from: start, to: point)
        case .line: return .line(from: start, to: point)
        case .box: return .box(rect, ellipse: ellipse)
        case .pixelate: return .pixelate(rect, strength: style.strength)
        case .spotlight: return .spotlight(rect, ellipse: style.ovalSpotlight)
        case .pen: return .pen([start])
        case .marker: return .marker([start])
        case .step: return .step(center: point)
        case .text: return .text(origin: start, string: " ", style: style.text)
        }
    }

    /// The style for new text: Option held makes it a label.
    private static func textStyle(_ style: TextStyle, label: Bool) -> TextStyle {
        guard label else { return style }
        var labeled = style
        labeled.effect = .label
        return labeled
    }

    /// `points` with `point` added when it's far enough from the last, up to the limit.
    private static func extended(_ points: [CGPoint], with point: CGPoint, minimum: CGFloat) -> [CGPoint] {
        guard points.count < ImageMark.maxPoints else { return points }
        if let last = points.last, hypot(point.x - last.x, point.y - last.y) < minimum { return points }
        return points + [point]
    }

    // MARK: Drawing

    /// The mark being drawn or dragged, or the selected mark's outline and handles.
    override func draw(_ dirtyRect: NSRect) {
        if let draft, let context = NSGraphicsContext.current?.cgContext {
            var marks = document.marks()
            if let index = marks.firstIndex(where: { $0.id == draft.id }) { marks[index] = draft } else { marks.append(draft) }
            MarkRenderer.drawDraft(draft, number: ImageMark.stepNumbers(marks)[draft.id], imageSize: document.pixelSize(), in: imageRect, context: context)
            return
        }
        guard drag == nil, let mark = selected else { return }
        NSColor.controlAccentColor.setStroke()
        let outline = NSBezierPath(rect: viewRect(mark.bounds))
        outline.setLineDash([4, 3], count: 2, phase: 0)
        outline.lineWidth = 1
        outline.stroke()
        var handles: [CGPoint] = []
        switch mark.kind {
        case .arrow(let from, let to), .line(let from, let to): handles = [from, to]
        case .box(let rect, _), .pixelate(let rect, _), .spotlight(let rect, _):
            let r = rect.standardized
            handles = [CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.maxX, y: r.maxY), CGPoint(x: r.minX, y: r.maxY)]
        default: break
        }
        for handle in handles.map(viewPoint) {
            let dot = NSBezierPath(ovalIn: NSRect(x: handle.x - 4, y: handle.y - 4, width: 8, height: 8))
            NSColor.white.setFill()
            dot.fill()
            dot.stroke()
        }
    }
}

nonisolated extension ImageMark {
    /// Whether `point` (image pixels) is on the mark, within `tolerance`.
    func contains(_ point: CGPoint, tolerance: CGFloat) -> Bool {
        let reach = tolerance + width
        switch kind {
        case .arrow(let from, let to), .line(let from, let to): return Self.distance(point, toSegment: from, to) <= reach
        case .pen(let points), .marker(let points):
            let reach = kind.isMarker ? reach + width * 1.5 : reach
            if points.count == 1 { return hypot(point.x - points[0].x, point.y - points[0].y) <= reach }
            return zip(points, points.dropFirst()).contains { Self.distance(point, toSegment: $0, $1) <= reach }
        default: return bounds.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
        }
    }

    /// Big enough to keep: a drag of a few pixels is a click, not a mark.
    func isVisible(tolerance: CGFloat) -> Bool {
        switch kind {
        case .arrow(let from, let to), .line(let from, let to): hypot(to.x - from.x, to.y - from.y) >= tolerance
        case .box(let rect, _), .pixelate(let rect, _), .spotlight(let rect, _): rect.width >= tolerance && rect.height >= tolerance
        default: true
        }
    }

    func moved(by delta: CGPoint) -> ImageMark {
        var mark = self
        let move = { (p: CGPoint) in CGPoint(x: p.x + delta.x, y: p.y + delta.y) }
        switch kind {
        case .arrow(let from, let to), .line(let from, let to): mark.kind = kind.withEnds(move(from), move(to))
        case .box(let r, let ellipse): mark.kind = .box(r.offsetBy(dx: delta.x, dy: delta.y), ellipse: ellipse)
        case .pixelate(let r, let strength): mark.kind = .pixelate(r.offsetBy(dx: delta.x, dy: delta.y), strength: strength)
        case .spotlight(let r, let ellipse): mark.kind = .spotlight(r.offsetBy(dx: delta.x, dy: delta.y), ellipse: ellipse)
        case .text(let origin, let string, let style): mark.kind = .text(origin: move(origin), string: string, style: style)
        case .step(let center): mark.kind = .step(center: move(center))
        case .pen(let points): mark.kind = .pen(points.map(move))
        case .marker(let points): mark.kind = .marker(points.map(move))
        }
        return mark
    }

    /// The mark with one corner or end dragged to `point` and the opposite one at `fixed`.
    func reshaped(fixed: CGPoint, moving point: CGPoint, end: Bool) -> ImageMark {
        var mark = self
        switch kind {
        case .arrow, .line: mark.kind = end ? kind.withEnds(fixed, point) : kind.withEnds(point, fixed)
        case .box(_, let ellipse): mark.kind = .box(CGRect(from: fixed, to: point), ellipse: ellipse)
        case .pixelate(_, let strength): mark.kind = .pixelate(CGRect(from: fixed, to: point), strength: strength)
        case .spotlight(_, let ellipse): mark.kind = .spotlight(CGRect(from: fixed, to: point), ellipse: ellipse)
        default: break
        }
        return mark
    }

    static func distance(_ p: CGPoint, toSegment a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y, length = dx * dx + dy * dy
        guard length > 0 else { return hypot(p.x - a.x, p.y - a.y) }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / length))
        return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
    }
}

nonisolated extension ImageMark.Kind {
    var isMarker: Bool { if case .marker = self { true } else { false } }
}
