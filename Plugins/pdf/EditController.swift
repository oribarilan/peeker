import AppKit
import PDFKit

/// Edit mode's tools on the view: choosing, moving, resizing and removing Peeker's own marks, placing text boxes and
/// signatures. Created when Edit mode first turns on, so opening a PDF costs nothing extra.
final class EditController {
    enum Corner { case topLeft, topRight, bottomLeft, bottomRight }
    enum Tool { case none, textBox, signature(Signature), highlighter }

    static let minimumSize: CGFloat = 8
    /// About the width of a signature on a signature line.
    static let signatureWidth: CGFloat = 180
    private static let handleSize: CGFloat = 8

    private unowned let document: PDFPluginDocument
    private var view: PeekerPDFView { document.pdfView }
    private(set) var tool = Tool.none {
        didSet { onToolChange?() }
    }
    /// Called whenever the tool changes, for the window's selected toolbar button.
    var onToolChange: (() -> Void)?
    private(set) var selectedID: String?
    private var selectedPage = 0
    /// A move or resize in progress: what's dragged, from where, and its bounds when the drag began.
    private var drag: (corner: Corner?, start: CGPoint, original: CGRect, annotation: PDFAnnotation)?
    private let overlay = EditOverlay()
    private var textBox: TextBoxEditor?

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

    /// Edit mode turned off: finish what's in progress.
    func end() {
        if let drag {  // cut off by leaving Edit mode: put it back rather than record an edit in the read view
            PDFMarks.setBounds(drag.original, of: drag.annotation)
            self.drag = nil
        }
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
    func finishDrag(id: String, type: MarkType, page: Int, from old: CGRect, to new: CGRect) {
        guard old != new else { return }
        if let annotation = view.document?.page(at: page).flatMap({ PDFMarks.find(id, on: $0) }), annotation.bounds != new {
            PDFMarks.setBounds(new, of: annotation)
        }
        document.record(.setBounds(id: id, type: type, page: page, rect: new), inverse: .setBounds(id: id, type: type, page: page, rect: old))
    }

    /// The topmost of Peeker's own highlights, text boxes and signatures at `point`; others are never selected.
    static func hit(_ annotations: [PDFAnnotation], at point: CGPoint) -> PDFAnnotation? {
        annotations.last { PDFMarks.id(of: $0) != nil && PDFMarks.type(of: $0) != nil && $0.bounds.insetBy(dx: -2, dy: -2).contains(point) }
    }

    static func corner(at point: CGPoint, of rect: CGRect, tolerance: CGFloat) -> Corner? {
        let corners: [(Corner, CGPoint)] = [(.topLeft, CGPoint(x: rect.minX, y: rect.maxY)), (.topRight, CGPoint(x: rect.maxX, y: rect.maxY)),
                                            (.bottomLeft, CGPoint(x: rect.minX, y: rect.minY)), (.bottomRight, CGPoint(x: rect.maxX, y: rect.minY))]
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
    func commitTextBox(id: String?, page: Int, topLeft: CGPoint, text: String, fontSize: Double) {
        let isEmpty = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let rect = TextBoxEditor.fittedRect(text: text, fontSize: fontSize, topLeft: topLeft)
        switch (id, isEmpty) {
        case (nil, true):
            break
        case (nil, false):
            let mark = PDFMark(id: PDFEdit.newID(), page: page, rect: rect, kind: .textBox(text: text, fontSize: fontSize))
            if document.change(.add(mark)) { select(mark.id, page: page) }
        case (let id?, true):
            document.change(.delete(id: id, type: .textBox, page: page))
            select(nil, page: 0)
        case (let id?, false):
            document.change(.setText(id: id, page: page, text: text, fontSize: fontSize, rect: rect))
            select(id, page: page)
        }
    }

    private func editTextBox(_ annotation: PDFAnnotation?, page: PDFPage, at topLeft: CGPoint) {
        guard let index = view.document?.index(for: page) else { return }
        let id = annotation.flatMap(PDFMarks.id(of:))
        let start = annotation.map { CGPoint(x: $0.bounds.minX, y: $0.bounds.maxY) } ?? topLeft
        select(nil, page: 0)
        textBox = TextBoxEditor(view: view, page: page, topLeft: start, text: annotation?.contents ?? "",
                                fontSize: annotation.flatMap(PDFMarks.fontSize(of:)) ?? 12, hiding: annotation) { [weak self] text, size in
            self?.textBox = nil
            self?.commitTextBox(id: id, page: index, topLeft: start, text: text, fontSize: size)
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
        case .none:
            break
        }
        let tolerance = Self.handleSize / max(view.scaleFactor, 0.01)
        if let selected = selectedAnnotation, selectedPage == index, let corner = Self.corner(at: pagePoint, of: selected.bounds, tolerance: tolerance) {
            drag = (corner, pagePoint, selected.bounds, selected)
            return true
        }
        guard let annotation = Self.hit(page.annotations, at: pagePoint), let id = PDFMarks.id(of: annotation) else {
            select(nil, page: 0)
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
        guard let drag, let page = drag.annotation.page else { return false }
        let point = view.convert(view.convert(event.locationInWindow, from: nil), to: page)
        let delta = CGSize(width: point.x - drag.start.x, height: point.y - drag.start.y)
        let rect = drag.corner.map { Self.resized(drag.original, corner: $0, by: delta) } ?? drag.original.offsetBy(dx: delta.width, dy: delta.height)
        PDFMarks.setBounds(Self.kept(rect, on: page.bounds(for: .mediaBox)), of: drag.annotation)
        overlay.refresh()
        return true
    }

    func mouseUp(with event: NSEvent) -> Bool {
        guard let drag else { return false }
        self.drag = nil
        if let id = PDFMarks.id(of: drag.annotation), let type = PDFMarks.type(of: drag.annotation), let page = drag.annotation.page,
           let index = view.document?.index(for: page) {
            finishDrag(id: id, type: type, page: index, from: drag.original, to: drag.annotation.bounds)
        }
        return true
    }

    /// Shows the waiting tool over the page: a crosshair for Text Box, a highlighter for Highlight, the signature itself
    /// following the pointer for Sign.
    func mouseMoved(with event: NSEvent) {
        let point = view.convert(event.locationInWindow, from: nil)
        let page = view.page(for: point, nearest: false)
        switch tool {
        case .textBox:
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
        guard let image = NSImage(systemSymbolName: "highlighter", accessibilityDescription: "Highlight")?.withSymbolConfiguration(configuration) else {
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

/// Draws the selection with its corner handles, and the signature following the pointer. Never takes clicks.
final class EditOverlay: NSView {
    weak var controller: EditController?
    var ghost: (signature: Signature, rect: CGRect)? { didSet { needsDisplay = true } }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    @objc func refresh() { needsDisplay = true }

    override func draw(_ dirtyRect: NSRect) {
        guard let view = superview as? PDFView else { return }
        if let annotation = controller?.selectedAnnotation, let page = annotation.page {
            let rect = convert(view.convert(annotation.bounds, from: page), from: view).insetBy(dx: -2, dy: -2)
            NSColor.controlAccentColor.setStroke()
            let outline = NSBezierPath(rect: rect)
            outline.lineWidth = 1
            outline.stroke()
            for corner in [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY)] {
                let handle = NSBezierPath(rect: CGRect(x: corner.x - 4, y: corner.y - 4, width: 8, height: 8))
                NSColor.white.setFill()
                handle.fill()
                handle.stroke()
            }
        }
        if let ghost {
            let rect = convert(ghost.rect, from: view)
            NSColor.black.withAlphaComponent(0.5).setStroke()
            for path in PDFMarks.paths(ghost.signature.strokes, size: rect.size) {
                path.transform(using: AffineTransform(translationByX: rect.minX, byY: rect.minY))
                path.stroke()
            }
        }
    }
}
