import AppKit
import PDFKit

/// A `PDFView` that keeps form fields read-only when it only views (the Peek panel, a read-only file), and in the
/// Editor hands mouse and key events to the edit tools first.
final class PeekerPDFView: PDFView, NSMenuItemValidation {
    /// True in the Editor for a PDF that can be edited.
    var isEditing = false
    /// Gets the events in the Editor once made; returns true when it handled one.
    weak var editController: EditController?
    /// Called before a click on an annotation or form field is handled, so the document can set up its edit parts.
    var onFirstUse: (() -> Void)?
    /// A click in the Editor ended, with the form field it hit, if any.
    var onInteraction: ((PDFAnnotation?) -> Void)?
    /// The document's undo history, set in the Editor.
    weak var editUndoManager: UndoManager?

    override var undoManager: UndoManager? { editUndoManager ?? super.undoManager }

    /// When the view only views, a click on a form field is swallowed: the field shows its value but takes no input.
    /// Links, text selection and everything else work as usual.
    func swallowsClick(at point: NSPoint) -> Bool {
        !isEditing && widget(at: point) != nil
    }

    func widget(at point: NSPoint) -> PDFAnnotation? {
        guard let page = page(for: point, nearest: false), let annotation = page.annotation(at: convert(point, to: page)),
              annotation.type == "Widget" else { return nil }
        return annotation
    }

    /// The first click on any annotation (a field, a mark) sets up the edit parts before anything handles it.
    func prepareForClick(at point: NSPoint) {
        guard editController == nil, let page = page(for: point, nearest: false) else { return }
        let onPage = convert(point, to: page)
        // The tools take a mark from 2 points outside it, as `EditController.hit` does.
        guard page.annotations.contains(where: { $0.bounds.insetBy(dx: -2, dy: -2).contains(onPage) }) else { return }
        onFirstUse?()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if swallowsClick(at: point) { return }
        guard isEditing else { return super.mouseDown(with: event) }
        window?.makeFirstResponder(self)  // the tools may take the click, and Undo must still reach the document
        prepareForClick(at: point)
        if editController?.mouseDown(with: event, at: point) == true { return }
        let widget = widget(at: point)
        super.mouseDown(with: event)
        onInteraction?(widget)
    }

    override func mouseDragged(with event: NSEvent) {
        if isEditing, editController?.mouseDragged(with: event) == true { return }
        super.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        if isEditing, editController?.mouseUp(with: event) == true { return }
        super.mouseUp(with: event)
        guard isEditing else { return }
        editController?.selectionEnded()
        onInteraction?(nil)
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        if isEditing { editController?.mouseMoved(with: event) }  // after PDFKit, so a waiting tool's cursor wins
    }

    override func keyDown(with event: NSEvent) {
        if isEditing, editController?.keyDown(with: event) == true { return }
        super.keyDown(with: event)
    }

    /// The most pixels an annotation's layer gets, so a large mark at a high zoom doesn't take a huge bitmap.
    private static let maxAnnotationPixels: CGFloat = 4_000_000
    private var sharpening = false
    private var watchesForSharpening = false

    /// PDFKit draws the page in tiles at the zoom's resolution, but annotations such as text boxes and signatures into
    /// layers of their own at one pixel per point, so they look pixelated zoomed in. This gives those layers the zoom's
    /// resolution after anything that can add one or change the zoom. PDFKit makes a layer a moment after the
    /// annotation appears, hence the wait. If PDFKit renames the layers, nothing changes and annotations stay soft.
    @objc func sharpenAnnotations() {
        guard !sharpening else { return }
        sharpening = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            sharpening = false
            let scale = scaleFactor * (window?.backingScaleFactor ?? 1)
            for layer in annotationLayers() {
                let points = layer.bounds.width * layer.bounds.height
                let wanted = points > 0 ? max(1, min(scale, (Self.maxAnnotationPixels / points).squareRoot())) : scale
                guard layer.contentsScale != wanted else { continue }
                layer.contentsScale = wanted
                layer.setNeedsDisplay()
            }
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil, !watchesForSharpening else { return }
        watchesForSharpening = true
        let center = NotificationCenter.default
        for name in [Notification.Name.PDFViewScaleChanged, .PDFViewVisiblePagesChanged, .PDFViewDocumentChanged] {
            center.addObserver(self, selector: #selector(sharpenAnnotations), name: name, object: self)
        }
        if let clip = (subviews.first { $0 is NSScrollView } as? NSScrollView)?.contentView {
            center.addObserver(self, selector: #selector(sharpenAnnotations), name: NSView.boundsDidChangeNotification, object: clip)
        }
        sharpenAnnotations()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        sharpenAnnotations()
    }

    /// The layers PDFKit draws annotations into, one each, found by PDFKit's class name for them.
    func annotationLayers() -> [CALayer] {
        var found: [CALayer] = []
        func walk(_ layer: CALayer) {
            if NSStringFromClass(type(of: layer)).hasSuffix("AnnotationEffect") { found.append(layer) }
            layer.sublayers?.forEach(walk)
        }
        if let layer { walk(layer) }
        return found
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if !trackingAreas.contains(where: { $0.owner === self && $0.options.contains(.mouseMoved) }) {
            addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect], owner: self))
        }
    }

    // Undo works only in the Editor, where the edits are.

    @objc func undo(_ sender: Any?) {
        if isEditing { undoManager?.undo() }
    }

    @objc func redo(_ sender: Any?) {
        if isEditing { undoManager?.redo() }
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(undo(_:)): isEditing && undoManager?.canUndo == true
        case #selector(redo(_:)): isEditing && undoManager?.canRedo == true
        default: true
        }
    }
}
