import AppKit
import os
import PDFKit
import PeekerKit

/// A PDF in a continuous native view with thumbnails and info. In a window it has an edit mode: highlights, form
/// fields, text boxes and signatures, saved on Cmd+S.
final class PDFPluginDocument: PluginDocument {
    let pdfView = PeekerPDFView()
    private let url: URL
    private let editable: Bool
    private let info: [InfoRow]
    let editMode: EditMode
    private(set) var isEditing = false
    var onEdit: (() -> Void)?
    /// Edit mode's parts, made when it first turns on.
    private(set) var tools: EditController?
    private var fields: FormFields?
    /// Edits made since the file was loaded or last saved, oldest first, each numbered and with the edit that undoes it.
    private var pending: [(number: Int, edit: PDFEdit, inverse: PDFEdit)] = []
    private var lastNumber = 0
    /// The document's own undo history, which the view hands out only in Edit mode. Not the window's: that one
    /// outlives the document (Open With, reload), and its actions would then run on a freed document.
    private(set) lazy var undoManager = UndoManager()
    /// Opaque: PDFKit drops alpha when writing and draws highlights with multiply, so text stays readable and the
    /// highlight looks the same before and after saving.
    static let highlightColor = RGBA(red: 1, green: 0.8, blue: 0, alpha: 1)
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "dev.peeker", category: "pdf")

    /// `uneditableReason` keeps Edit mode off for a file that can't be safely changed.
    init(url: URL, document: PDFDocument, info: [InfoRow], editable: Bool, uneditableReason: String? = nil) {
        self.url = url
        self.info = info
        self.editable = editable
        editMode = !editable ? .none : uneditableReason.map { .unavailable(reason: $0) } ?? .available
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
    }

    var contentView: NSView { pdfView }

    var sidebar: [SidebarPanel] {
        let thumbnails = PDFThumbnailView()
        thumbnails.pdfView = pdfView
        thumbnails.thumbnailSize = NSSize(width: 90, height: 120)
        thumbnails.backgroundColor = .clear
        return [SidebarPanel(thumbnails, sizing: .fill)] + (InfoPanel.make(info).map { [$0] } ?? [])
    }

    /// A view-only document (the Space panel) leaves out the edit tools.
    var commands: [CommandSpec] {
        editable ? PDFPlugin.commands : PDFPlugin.commands.filter { !$0.isEditTool }
    }


    func setEditing(_ on: Bool) {
        guard editMode == .available, on != isEditing else { return }
        isEditing = on
        pdfView.isEditing = on
        pdfView.editUndoManager = on ? undoManager : nil
        if on, tools == nil {
            let tools = EditController(document: self)
            self.tools = tools
            pdfView.tools = tools
            let fields = FormFields(view: pdfView)
            fields.onChange = { [weak self] name, new, old in self?.record(.field(name: name, value: new), inverse: .field(name: name, value: old)) }
            self.fields = fields
            pdfView.onInteraction = { [weak self] widget in
                if let widget { self?.widgetClicked(widget) }
                self?.checkFields()
            }
        }
        if on { pdfView.window?.makeFirstResponder(pdfView) }  // so Undo reaches the document's history
        if !on { tools?.end() }
    }

    /// Records the form fields the user changed since the last check. Only in Edit mode.
    func checkFields() {
        guard isEditing else { return }
        fields?.check()
    }

    /// The user clicked a form field in Edit mode.
    func widgetClicked(_ widget: PDFAnnotation) {
        guard isEditing else { return }
        fields?.clicked(widget)
    }

    func perform(_ id: String) -> Bool {
        switch id {
        case "zoom-in": pdfView.zoomIn(nil)
        case "zoom-out": pdfView.zoomOut(nil)
        case "text-box" where isEditing:
            tools?.chooseTextBox()
        case "sign" where isEditing:
            guard let window = pdfView.window else { return true }
            SignaturePad.present(on: window) { [weak self] signature in self?.tools?.startPlacing(signature) }
        case "highlight" where isEditing:
            guard let document = pdfView.document else { return true }
            let lines = pdfView.currentSelection?.selectionsByLine() ?? []
            pdfView.clearSelection()
            undoManager.beginUndoGrouping()  // one undo step for every line
            defer { undoManager.endUndoGrouping() }
            for line in lines {
                for page in line.pages {
                    change(.add(PDFMark(id: PDFEdit.newID(), page: document.index(for: page), rect: line.bounds(for: page), kind: .highlight(Self.highlightColor))))
                }
            }
        default:
            return false
        }
        return true
    }

    /// The unsaved edits, folded; empty when there are none.
    var pendingEdits: [PDFEdit] { PDFEdit.folded(pending.map(\.edit)) }

    func unsavedEdits() -> UnsavedEdits? {
        let edits = pendingEdits
        guard !edits.isEmpty, let last = pending.last else { return nil }
        return UnsavedEdits(PDFSnapshot(edits: .operations(edits), through: last.number))
    }

    func restore(encoded edits: Data) -> Bool {
        // Old records come from builds that highlighted any PDF; a signed or locked one must not take them.
        guard editMode == .available, let decoded = try? JSONDecoder().decode(PDFEdits.self, from: edits) else { return false }
        return decoded.operations.reduce(false) { change($1) || $0 }
    }

    func save(_ edits: UnsavedEdits, accepting offer: SaveOffer?) async throws(PluginError) {
        guard let snapshot = edits.value as? PDFSnapshot else { throw PluginError("These changes aren't PDF edits.") }
        try await PDFPlugin.write(snapshot.edits.operations, to: url.path)
        pending.removeAll { $0.number <= snapshot.through }  // edits made during the save stay pending
    }

    func revertEdits() {
        guard let document = pdfView.document else { return }
        for entry in pending.reversed() {
            do throws(PluginError) {
                try PDFMarks.apply(entry.inverse, to: document, fileName: url.lastPathComponent)
                noteApplied(entry.inverse)
            } catch {
                Self.log.error("couldn't take back an edit: \(error.message, privacy: .private)")
            }
        }
        pending = []
        undoManager.removeAllActions()
    }

    /// Applies `edit` to the view, makes it pending and undoable. False, changing nothing, when it doesn't fit the
    /// file (recovered edits for a file that changed, say).
    @discardableResult
    func change(_ edit: PDFEdit) -> Bool {
        guard let document = pdfView.document, let inverse = inverse(of: edit, in: document) else {
            Self.log.error("skipped an edit for something no longer in the file")
            return false
        }
        do throws(PluginError) {
            try PDFMarks.apply(edit, to: document, fileName: url.lastPathComponent)
        } catch {
            // Saving refuses the whole file over one edit it can't write, so such an edit never becomes pending.
            Self.log.error("skipped an edit: \(error.message, privacy: .private)")
            return false
        }
        noteApplied(edit)
        record(edit, inverse: inverse)
        return true
    }

    private func noteApplied(_ edit: PDFEdit) {
        if case .field(let name, let value) = edit { fields?.applied(name, value) }
    }

    /// Makes an edit the view already shows (a form field the user filled in) pending and undoable.
    func record(_ edit: PDFEdit, inverse: PDFEdit) {
        lastNumber += 1
        pending.append((lastNumber, edit, inverse))
        // A group of its own: in a window it nests in the event's group, so one command is one undo step.
        undoManager.beginUndoGrouping()
        undoManager.registerUndo(withTarget: self) { [weak self] _ in self?.change(inverse) }
        undoManager.endUndoGrouping()
        onEdit?()
    }

    /// The edit that takes `edit` back, read from the document as it is now; nil when its target is missing.
    private func inverse(of edit: PDFEdit, in document: PDFDocument) -> PDFEdit? {
        func annotation(_ id: String, _ page: Int) -> PDFAnnotation? {
            guard (0..<document.pageCount).contains(page), let page = document.page(at: page) else { return nil }
            return PDFMarks.find(id, on: page)
        }
        switch edit {
        case .add(let mark):
            return .delete(id: mark.id, type: mark.type, page: mark.page)
        case .setBounds(let id, let type, let page, _):
            return annotation(id, page).map { .setBounds(id: id, type: type, page: page, rect: $0.bounds) }
        case .setText(let id, let page, _, _, _):
            return annotation(id, page).map {
                .setText(id: id, page: page, text: $0.contents ?? "", fontSize: PDFMarks.fontSize(of: $0) ?? 12, rect: $0.bounds)
            }
        case .delete(let id, _, let page):
            return annotation(id, page).flatMap { PDFMarks.mark(of: $0, page: page) }.map { .add($0) }
        case .field(let name, _):
            let widget = (0..<document.pageCount).lazy.compactMap { document.page(at: $0)?.annotations.first { $0.fieldName == name } }.first
            return widget.map { .field(name: name, value: $0.widgetStringValue ?? "") }
        }
    }
}

/// What `unsavedEdits()` hands out: the folded edits, and the number of the last one, so saving knows which pending
/// edits it wrote. Encodes as the edits alone.
nonisolated struct PDFSnapshot: Encodable, Sendable {
    let edits: PDFEdits
    let through: Int

    func encode(to encoder: any Encoder) throws {
        try edits.encode(to: encoder)
    }
}
