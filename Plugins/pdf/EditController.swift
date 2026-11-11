import AppKit
import PDFKit
import PeekerKit

/// The edit tools on the view: choosing, moving, resizing and removing Peeker's own marks, placing text boxes and
/// signatures, drawing and stamping. Created when a tool or an annotation is first used, so opening a PDF costs nothing extra.
final class EditController {
    enum Corner { case topLeft, topRight, bottomLeft, bottomRight }
    enum Tool { case none, textBox, signature(Signature), highlighter, draw(PDFDrawing.Shape) }
    /// What the markup strip shows: a text style and size, or a drawing's color and size.
    enum StripState: Equatable { case text(TextBoxStyle, Double), drawing(RGBA, MarkupSize) }

    static let minimumSize: CGFloat = 8
    /// About the width of a signature on a signature line.
    static let signatureWidth: CGFloat = 180
    static let handleSize: CGFloat = 8

    private unowned let document: PDFPluginDocument
    private var view: PeekerPDFView { document.pdfView }
    private(set) var tool = Tool.none {
        didSet {
            onToolChange?()
            onStripChange?()
        }
    }
    /// Called whenever the tool changes, for the window's selected toolbar button.
    var onToolChange: (() -> Void)?
    private(set) var selectedID: String?
    private var selectedPage = 0
    /// A move or resize in progress: what's dragged, from where, and its bounds when the drag began.
    private var drag: (corner: Corner?, start: CGPoint, original: CGRect, annotation: PDFAnnotation)?
    /// A drawing in progress: on which page, from where, through which points (page space).
    private var draft: (shape: PDFDrawing.Shape, page: PDFPage, index: Int, points: [CGPoint])?
    private let overlay = EditOverlay()
    private var textBox: TextBoxEditor? {
        didSet { onStripChange?() }
    }
    /// Called when what the markup strip shows may have changed: the tool, the selection, typing, an edit.
    var onStripChange: (() -> Void)?

    init(document: PDFPluginDocument) {
        self.document = document
        overlay.frame = view.bounds
        overlay.autoresizingMask = [.width, .height]
        overlay.controller = self
        view.addSubview(overlay)
        let center = NotificationCenter.default
        for name in [Notification.Name.PDFViewScaleChanged, .PDFViewPageChanged, .PDFViewDocumentChanged] {
            center.addObserver(overlay, selector: #selector(EditOverlay.refresh), name: name, object: view)
        }
        if let clip = view.documentView?.enclosingScrollView?.contentView {
            clip.postsBoundsChangedNotifications = true
            center.addObserver(overlay, selector: #selector(EditOverlay.refresh), name: NSView.boundsDidChangeNotification, object: clip)
        }
    }

    // MARK: Tools

    /// Whether the next drag over text gets highlighted.
    var highlighterArmed: Bool { if case .highlighter = tool { true } else { false } }

    /// Arms the highlighter for one drag: text selected next is highlighted when the mouse comes up.
    func armHighlighter() {
        endTextBox()
        tool = .highlighter
        select(nil, page: 0)
    }

    /// A drag that may have selected text just ended: an armed highlighter highlights that text and disarms.
    func selectionEnded() {
        guard highlighterArmed, let text = view.currentSelection?.string, !text.isEmpty else { return }
        tool = .none
        document.highlightSelection()
    }

    func chooseTextBox() {
        endTextBox()
        tool = .textBox
        select(nil, page: 0)
        NSCursor.crosshair.set()
    }

    /// Arms a drawing or stamp tool, which stays armed for the next mark until Escape or another tool.
    func arm(_ shape: PDFDrawing.Shape) {
        endTextBox()
        tool = .draw(shape)
        select(nil, page: 0)
        NSCursor.crosshair.set()
    }

    /// The drawing or stamp tool armed, if any.
    var armedShape: PDFDrawing.Shape? { if case .draw(let shape) = tool { shape } else { nil } }

    func startPlacing(_ signature: Signature) {
        endTextBox()
        tool = .signature(signature)
        select(nil, page: 0)
    }

    /// Places the signature being placed, centered on `point` in page space. False when no signature is being placed.
    @discardableResult
    func place(at point: CGPoint, page: Int) -> Bool {
        guard case .signature(let signature) = tool else { return false }
        tool = .none
        overlay.ghost = nil
        let mark = Self.signatureMark(signature, page: page, centeredAt: point)
        if document.change(.add(mark)) { select(mark.id, page: page) }
        return true
    }

    static func signatureMark(_ signature: Signature, page: Int, centeredAt point: CGPoint) -> PDFMark {
        let size = CGSize(width: signatureWidth, height: signatureWidth * signature.aspect)
        let rect = CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height)
        return PDFMark(id: PDFEdit.newID(), page: page, rect: rect, kind: .signature(strokes: signature.strokes))
    }

    /// Finishes what's in progress and drops the selection: before a page edit or Don't Save, and on Escape.
    func end() {
        if let drag {  // cut off mid-drag: put it back rather than record a half-made move
            PDFMarks.setBounds(drag.original, of: drag.annotation)
            self.drag = nil
        }
        draft = nil
        overlay.draft = nil
        endTextBox()
        tool = .none
        overlay.ghost = nil
        select(nil, page: 0)
    }

    // MARK: Selection

    func select(_ id: String?, page: Int) {
        selectedID = id
        selectedPage = page
        overlay.refresh()
        onStripChange?()
    }

    // MARK: Strip

    /// What the markup strip shows: the box being typed, the selected text box or drawing, or the style the armed tool's
    /// next mark gets; nil when there's nothing of that, and the strip shows only while Markup is on.
    var stripState: StripState? {
        if let textBox { return .text(textBox.style, textBox.fontSize) }
        if let annotation = selectedAnnotation {
            if annotation.type == "FreeText" {
                return .text(PDFMarks.style(of: annotation), PDFMarks.fontSize(of: annotation) ?? TextBoxStyle.standardSize)
            }
            if let drawing = PDFMarks.drawing(of: annotation) { return .drawing(drawing.color, MarkupSize(of: drawing, in: annotation.bounds)) }
        }
        switch tool {
        case .textBox: return .text(document.textBoxStyle, document.textBoxSize)
        case .draw: return .drawing(document.markupColor, document.markupSize)
        default: return nil
        }
    }

    /// From the strip: recolors or resizes the selected drawing as one edit, and keeps the look for the next mark. A
    /// dot's size is its side, so a new size makes it that size around its center.
    func applyDrawingLook(color: RGBA, size: MarkupSize) {
        document.rememberMarkup(color: color, size: size)
        if let annotation = selectedAnnotation, let id = selectedID, let drawing = PDFMarks.drawing(of: annotation) {
            let bounds = annotation.bounds
            if drawing.shape == .dot, size != MarkupSize(of: drawing, in: bounds) {
                let side = size.stampSide
                document.change(
                    .setBounds(
                        id: id, type: .drawing, page: selectedPage,
                        rect: CGRect(x: bounds.midX - side / 2, y: bounds.midY - side / 2, width: side, height: side)))
            } else if color != drawing.color || (drawing.shape != .dot && size.width != drawing.width) {
                document.change(.setLook(id: id, page: selectedPage, color: color, width: drawing.shape == .dot ? drawing.width : size.width))
            }
            select(id, page: selectedPage)
        }
        onStripChange?()
    }

    /// From the strip: restyles the box being typed at once, or the selected box as one edit, and keeps the style
    /// for the next box.
    func applyTextBoxStyle(_ style: TextBoxStyle, size: Double) {
        let size = min(max(size, PDFMarks.fontSizes.lowerBound), PDFMarks.fontSizes.upperBound)
        document.rememberTextBox(style, size: size)
        if let textBox {
            textBox.style = style
            textBox.fontSize = size
        } else if let annotation = selectedAnnotation, annotation.type == "FreeText", let id = selectedID {
            // The look it already has changes nothing, so it's no edit and no undo step.
            guard style != PDFMarks.style(of: annotation) || size != PDFMarks.fontSize(of: annotation) ?? TextBoxStyle.standardSize else { return }
            let topLeft = CGPoint(x: annotation.bounds.minX, y: annotation.bounds.maxY)
            let rect = TextBoxEditor.fittedRect(text: annotation.contents ?? "", fontSize: size, style: style, topLeft: topLeft)
            document.change(
                .setText(id: id, page: selectedPage, text: annotation.contents ?? "", fontSize: size, rect: rect, style: style.nilIfStandard))
            select(id, page: selectedPage)
        }
        onStripChange?()
    }

    /// The selected mark's annotation, if it's still there (an undo may have removed it).
    var selectedAnnotation: PDFAnnotation? {
        guard let id = selectedID, let page = view.document?.page(at: selectedPage) else { return nil }
        return PDFMarks.find(id, on: page)
    }

    /// Removes the selected mark. False when nothing is selected.
    @discardableResult
    func deleteSelection() -> Bool {
        guard let annotation = selectedAnnotation, let id = selectedID, let type = PDFMarks.type(of: annotation) else { return false }
        document.change(.delete(id: id, type: type, page: selectedPage))
        select(nil, page: 0)
        return true
    }

    /// Records a finished move or resize, which the view already shows.
    private func finishDrag(id: String, type: MarkType, page: Int, from old: CGRect, to new: CGRect) {
        guard old != new else { return }
        document.record(.setBounds(id: id, type: type, page: page, rect: new), inverse: .setBounds(id: id, type: type, page: page, rect: old))
    }

    /// The topmost of Peeker's own marks at `point`, a pen stroke, line or arrow only near its line; others are never
    /// selected.
    /// `tolerance` is in page points: a few screen points at the view's scale.
    static func hit(_ annotations: [PDFAnnotation], at point: CGPoint, tolerance: CGFloat = 3) -> PDFAnnotation? {
        annotations.last { annotation in
            guard PDFMarks.id(of: annotation) != nil, PDFMarks.type(of: annotation) != nil, annotation.bounds.insetBy(dx: -2, dy: -2).contains(point)
            else {
                return false
            }
            guard let drawing = PDFMarks.drawing(of: annotation), drawing.shape.isHitAlongStrokes else { return true }
            let origin = annotation.bounds.origin
            return drawing.isNear(CGPoint(x: point.x - origin.x, y: point.y - origin.y), in: annotation.bounds.size, tolerance: tolerance)
        }
    }

    static func corner(at point: CGPoint, of rect: CGRect, tolerance: CGFloat) -> Corner? {
        let corners: [(Corner, CGPoint)] = [
            (.topLeft, CGPoint(x: rect.minX, y: rect.maxY)), (.topRight, CGPoint(x: rect.maxX, y: rect.maxY)),
            (.bottomLeft, CGPoint(x: rect.minX, y: rect.minY)), (.bottomRight, CGPoint(x: rect.maxX, y: rect.minY)),
        ]
        return corners.first { abs($0.1.x - point.x) <= tolerance && abs($0.1.y - point.y) <= tolerance }?.0
    }

    /// `rect` moved back just enough that `minimumSize` of it stays on the page: a mark off its page can't be saved.
    static func kept(_ rect: CGRect, on page: CGRect) -> CGRect {
        let x = min(max(rect.minX, page.minX - rect.width + minimumSize), page.maxX - minimumSize)
        let y = min(max(rect.minY, page.minY - rect.height + minimumSize), page.maxY - minimumSize)
        return CGRect(origin: CGPoint(x: x, y: y), size: rect.size)
    }

    /// `rect` with `corner` dragged by `delta` (page space, y up); the opposite corner stays put.
    static func resized(_ rect: CGRect, corner: Corner, by delta: CGSize) -> CGRect {
        var minX = rect.minX, maxX = rect.maxX, minY = rect.minY, maxY = rect.maxY
        switch corner {
        case .topLeft: minX = min(minX + delta.width, maxX - minimumSize); maxY = max(maxY + delta.height, minY + minimumSize)
        case .topRight: maxX = max(maxX + delta.width, minX + minimumSize); maxY = max(maxY + delta.height, minY + minimumSize)
        case .bottomLeft: minX = min(minX + delta.width, maxX - minimumSize); minY = min(minY + delta.height, maxY - minimumSize)
        case .bottomRight: maxX = max(maxX + delta.width, minX + minimumSize); minY = min(minY + delta.height, maxY - minimumSize)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    // MARK: Text boxes

    /// Ends typing into a text box: an empty one is removed, a new one added, a changed one updated.
    func commitTextBox(id: String?, page: Int, topLeft: CGPoint, text: String, fontSize: Double, style: TextBoxStyle = .standard) {
        let isEmpty = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let rect = TextBoxEditor.fittedRect(text: text, fontSize: fontSize, style: style, topLeft: topLeft)
        switch (id, isEmpty) {
        case (nil, true):
            break
        case (nil, false):
            let mark = PDFMark(
                id: PDFEdit.newID(), page: page, rect: rect, kind: .textBox(text: text, fontSize: fontSize, style: style.nilIfStandard))
            if document.change(.add(mark)) { select(mark.id, page: page) }
        case (let id?, true):
            document.change(.delete(id: id, type: .textBox, page: page))
            select(nil, page: 0)
        case (let id?, false):
            document.change(.setText(id: id, page: page, text: text, fontSize: fontSize, rect: rect, style: style.nilIfStandard))
            select(id, page: page)
        }
    }

    private func editTextBox(_ annotation: PDFAnnotation?, page: PDFPage, at topLeft: CGPoint) {
        guard let index = view.document?.index(for: page) else { return }
        let id = annotation.flatMap(PDFMarks.id(of:))
        let start = annotation.map { CGPoint(x: $0.bounds.minX, y: $0.bounds.maxY) } ?? topLeft
        select(nil, page: 0)
        // An existing box keeps its own style; a new one takes the remembered style.
        let size = annotation.map { PDFMarks.fontSize(of: $0) ?? TextBoxStyle.standardSize } ?? document.textBoxSize
        let style = annotation.map(PDFMarks.style(of:)) ?? document.textBoxStyle
        textBox = TextBoxEditor(
            view: view, page: page, topLeft: start, text: annotation?.contents ?? "", fontSize: size, style: style,
            hiding: annotation
        ) { [weak self] text, size, style in
            self?.textBox = nil
            self?.commitTextBox(id: id, page: index, topLeft: start, text: text, fontSize: size, style: style)
        }
    }

    private func endTextBox() {
        textBox?.end()
        textBox = nil
    }

    // MARK: Events from the view

    func mouseDown(with event: NSEvent, at point: NSPoint) -> Bool {
        if let textBox {
            if textBox.contains(point) { return false }
            endTextBox()
            return true
        }
        guard let page = view.page(for: point, nearest: false), let index = view.document?.index(for: page) else {
            select(nil, page: 0)
            return false
        }
        let pagePoint = view.convert(point, to: page)
        switch tool {
        case .signature:
            return place(at: pagePoint, page: index)
        case .textBox:
            tool = .none
            editTextBox(nil, page: page, at: pagePoint)
            return true
        case .highlighter:
            select(nil, page: 0)
            return false  // PDFKit selects the text; selectionEnded highlights it
        case .none, .draw:
            break
        }
        let tolerance = Self.handleSize / max(view.scaleFactor, 0.01)
        if let selected = selectedAnnotation, selectedPage == index,
            let corner = Self.corner(at: pagePoint, of: selected.bounds, tolerance: tolerance)
        {
            drag = (corner, pagePoint, selected.bounds, selected)
            return true
        }
        guard let annotation = Self.hit(page.annotations, at: pagePoint, tolerance: 3 / max(view.scaleFactor, 0.01)),
            let id = PDFMarks.id(of: annotation)
        else {
            select(nil, page: 0)
            if case .draw(let shape) = tool {
                draft = (shape, page, index, [pagePoint])
                return true
            }
            return false
        }
        if event.clickCount == 2, annotation.type == "FreeText" {
            editTextBox(annotation, page: page, at: pagePoint)
            return true
        }
        select(id, page: index)
        drag = (nil, pagePoint, annotation.bounds, annotation)
        return true
    }

    func mouseDragged(with event: NSEvent) -> Bool {
        if var draft {
            draft.points.append(Self.clamped(view.convert(view.convert(event.locationInWindow, from: nil), to: draft.page), to: draft.page))
            self.draft = draft
            overlay.draft = drawn(draft, option: event.modifierFlags.contains(.option)).map { (draft.page, $0.rect, $0.drawing) }
            return true
        }
        guard let drag, let page = drag.annotation.page else { return false }
        let point = view.convert(view.convert(event.locationInWindow, from: nil), to: page)
        let delta = CGSize(width: point.x - drag.start.x, height: point.y - drag.start.y)
        let rect = drag.corner.map { Self.resized(drag.original, corner: $0, by: delta) } ?? drag.original.offsetBy(dx: delta.width, dy: delta.height)
        PDFMarks.setBounds(Self.kept(rect, on: page.bounds(for: .mediaBox)), of: drag.annotation)
        overlay.refresh()
        return true
    }

    func mouseUp(with event: NSEvent) -> Bool {
        if let draft {
            self.draft = nil
            overlay.draft = nil
            if let made = drawn(draft, option: event.modifierFlags.contains(.option)) {
                document.change(.add(PDFMark(id: PDFEdit.newID(), page: draft.index, rect: made.rect, kind: .drawing(made.drawing))))
            }
            return true
        }
        guard let drag else { return false }
        self.drag = nil
        if let id = PDFMarks.id(of: drag.annotation), let type = PDFMarks.type(of: drag.annotation), let page = drag.annotation.page,
            let index = view.document?.index(for: page)
        {
            finishDrag(id: id, type: type, page: index, from: drag.original, to: drag.annotation.bounds)
        }
        return true
    }

    /// The mark a draft makes with the strip's color and size: a stamp at the strip's size for a click, nothing for
    /// any other tool's click (under 3 points of movement), and with Option an ellipse for Box.
    private func drawn(_ draft: (shape: PDFDrawing.Shape, page: PDFPage, index: Int, points: [CGPoint]), option: Bool) -> (
        rect: CGRect, drawing: PDFDrawing
    )? {
        guard let start = draft.points.first, let end = draft.points.last else { return nil }
        var shape = draft.shape
        if shape == .box, option { shape = .ellipse }
        let size = document.markupSize
        // A click is a press that never went 3 points from where it started; a pen loop can end where it began.
        if !draft.points.contains(where: { hypot($0.x - start.x, $0.y - start.y) >= 3 }) {
            guard shape.isStamp else { return nil }
            let side = size.stampSide
            let square = Self.kept(
                CGRect(x: start.x - side / 2, y: start.y - side / 2, width: side, height: side), on: draft.page.bounds(for: .mediaBox))
            return PDFDrawing.make(
                shape, from: square.origin, to: CGPoint(x: square.maxX, y: square.maxY), points: [], color: document.markupColor, width: size.width)
        }
        return PDFDrawing.make(shape, from: start, to: end, points: draft.points, color: document.markupColor, width: size.width)
    }

    /// `point` kept within the page, so a drawing can't run off it.
    private static func clamped(_ point: CGPoint, to page: PDFPage) -> CGPoint {
        let box = page.bounds(for: .mediaBox)
        return CGPoint(x: min(max(point.x, box.minX), box.maxX), y: min(max(point.y, box.minY), box.maxY))
    }

    /// Shows the waiting tool over the page: a crosshair for Text Box and the drawing tools, a highlighter for Highlight, the signature itself
    /// following the pointer for Sign.
    func mouseMoved(with event: NSEvent) {
        let point = view.convert(event.locationInWindow, from: nil)
        let page = view.page(for: point, nearest: false)
        switch tool {
        case .textBox, .draw:
            if page != nil { NSCursor.crosshair.set() }
        case .highlighter:
            if page != nil { Self.highlighterCursor.set() }
        case .signature(let signature):
            guard let page else { overlay.ghost = nil; return }
            let mark = Self.signatureMark(signature, page: 0, centeredAt: view.convert(point, to: page))
            overlay.ghost = (signature, view.convert(mark.rect, from: page))
        case .none:
            break
        }
    }

    /// The `highlighter` symbol as a cursor, pointing with its tip at the bottom left.
    static let highlighterCursor: NSCursor = {
        let configuration = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        guard let image = NSImage(systemSymbolName: "highlighter", accessibilityDescription: "Highlight")?.withSymbolConfiguration(configuration)
        else {
            return .iBeam
        }
        return NSCursor(image: image, hotSpot: NSPoint(x: 2, y: image.size.height - 2))
    }()

    func keyDown(with event: NSEvent) -> Bool {
        switch event.keyCode {
        case 51, 117:  // Delete, Forward Delete
            return deleteSelection()
        case 53:  // Escape
            let busy = selectedID != nil || { if case .none = tool { false } else { true } }()
            end()
            return busy
        default:
            return false
        }
    }
}
