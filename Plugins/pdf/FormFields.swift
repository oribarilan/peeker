import AppKit
import PDFKit

/// Notices form-field changes in Edit mode. PDFKit edits fields itself and reports nothing, so each field's value is
/// compared with the last one known after every interaction, and a text field is read from its editor as the user types.
final class FormFields: NSObject {
    /// A field changed from `old` to `new`; the view already shows it.
    var onChange: ((_ name: String, _ new: String, _ old: String) -> Void)?
    private weak var view: PDFView?
    /// The last value seen for each field on the pages looked at so far.
    private var known: [String: String] = [:]
    private var seenPages = Set<ObjectIdentifier>()
    /// The text field being typed into, if any.
    private weak var editing: PDFAnnotation?

    init(view: PDFView) {
        self.view = view
        super.init()
        // Selector-based observers go away with the object.
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(textChanged(_:)), name: NSText.didChangeNotification, object: nil)
        center.addObserver(self, selector: #selector(textEnded(_:)), name: NSText.didEndEditingNotification, object: nil)
        center.addObserver(self, selector: #selector(visiblePagesChanged(_:)), name: .PDFViewVisiblePagesChanged, object: view)
        noteVisiblePages()
    }

    /// Takes the values of fields on pages now on screen as their starting point: only those can be clicked.
    func noteVisiblePages() {
        for page in view?.visiblePages ?? [] where seenPages.insert(ObjectIdentifier(page)).inserted {
            for widget in widgets(on: page) where known[widget.name] == nil { known[widget.name] = widget.value }
        }
    }

    /// Compares the fields on the visible pages with what's known and reports each change.
    func check() {
        noteVisiblePages()
        for page in view?.visiblePages ?? [] {
            for widget in widgets(on: page) { report(widget.name, widget.value) }
        }
    }

    /// The user clicked `widget`; a text field is then read from its editor while they type.
    func clicked(_ widget: PDFAnnotation) {
        editing = widget.widgetFieldType == .text && !widget.isReadOnly ? widget : nil
    }

    /// A value set by Peeker (undo, recovery, Don't Save) is known, not a change.
    func applied(_ name: String, _ value: String) {
        known[name] = value
    }

    @objc private func visiblePagesChanged(_ note: Notification) {
        noteVisiblePages()
    }

    @objc private func textChanged(_ note: Notification) {
        // A text box's editor is in the view too, but its text is the box's, not the field's.
        guard let text = note.object as? NSText, let view, text.isDescendant(of: view), !(text.delegate is TextBoxEditor),
              let name = editing?.fieldName else { return }
        report(name, text.string)
    }

    @objc private func textEnded(_ note: Notification) {
        guard let text = note.object as? NSText, let view, text.isDescendant(of: view) else { return }
        editing = nil
        check()
    }

    private func report(_ name: String, _ value: String) {
        let old = known[name] ?? ""
        guard value != old else { return }
        known[name] = value
        onChange?(name, value, old)
    }

    private func widgets(on page: PDFPage) -> [(name: String, value: String)] {
        page.annotations.compactMap { annotation in
            guard annotation.type == "Widget", annotation.widgetFieldType != .signature, let name = annotation.fieldName else { return nil }
            // A radio button's group value shows on each of its buttons, so any one of them reports the group.
            return (name, annotation.widgetStringValue ?? "")
        }
    }
}
