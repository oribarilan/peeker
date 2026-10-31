import AppKit
import PDFKit

/// A `PDFView` that keeps form fields read-only in the read view, and in Edit mode hands mouse and key events to
/// the edit tools first.
final class PeekerPDFView: PDFView, NSMenuItemValidation {
    var isEditing = false
    /// Gets the events in Edit mode; returns true when it handled one.
    weak var tools: EditController?
    /// A click in Edit mode ended, with the form field it hit, if any.
    var onInteraction: ((PDFAnnotation?) -> Void)?
    /// The document's undo history, set while in Edit mode.
    weak var editUndoManager: UndoManager?

    override var undoManager: UndoManager? { editUndoManager ?? super.undoManager }

    /// In the read view a click on a form field is swallowed: the field shows its value but takes no input. Links,
    /// text selection and everything else work as usual.
    func swallowsClick(at point: NSPoint) -> Bool {
        !isEditing && widget(at: point) != nil
    }

    func widget(at point: NSPoint) -> PDFAnnotation? {
        guard let page = page(for: point, nearest: false), let annotation = page.annotation(at: convert(point, to: page)),
              annotation.type == "Widget" else { return nil }
        return annotation
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if swallowsClick(at: point) { return }
        guard isEditing else { return super.mouseDown(with: event) }
        window?.makeFirstResponder(self)  // the tools may take the click, and Undo must still reach the document
        if tools?.mouseDown(with: event, at: point) == true { return }
        let widget = widget(at: point)
        super.mouseDown(with: event)
        onInteraction?(widget)
    }

    override func mouseDragged(with event: NSEvent) {
        if isEditing, tools?.mouseDragged(with: event) == true { return }
        super.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        if isEditing, tools?.mouseUp(with: event) == true { return }
        super.mouseUp(with: event)
        if isEditing { onInteraction?(nil) }
    }

    override func mouseMoved(with event: NSEvent) {
        if isEditing { tools?.mouseMoved(with: event) }
        super.mouseMoved(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if isEditing, tools?.keyDown(with: event) == true { return }
        super.keyDown(with: event)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if !trackingAreas.contains(where: { $0.owner === self && $0.options.contains(.mouseMoved) }) {
            addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect], owner: self))
        }
    }

    // Undo works only in Edit mode, where the edits are.

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
