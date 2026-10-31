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
    /// Pages deleted in this view, for their undo.
    private let stash = PageStash()
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
        (document as? PeekerPDFDocument)?.onForeignChange = { [weak self] before in self?.pagesDragged(before: before) }
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
    }

    /// The thumbnails last made for the sidebar, for the selected pages.
    private weak var thumbnails: PageThumbnails?
    private static let pageCommands: Set = ["rotate-left", "rotate-right", "delete-page"]

    /// The pages, with the find bar above them from the first Cmd+F. No find in the Space panel.
    private lazy var container = PDFFindContainer(pdfView: pdfView, allowsFind: editable)
    var contentView: NSView { container }
    var focusView: NSView? { pdfView }

    var sidebar: [SidebarPanel] {
        let pageCommands = PDFPlugin.commands.filter { Self.pageCommands.contains($0.id) }
        let thumbnails = PageThumbnails(commands: pageCommands.map { ($0.id, $0.title) })
        thumbnails.pdfView = pdfView
        thumbnails.allowsPageChanges = allowsPageChanges
        thumbnails.isEditing = isEditing
        thumbnails.onCommand = { [weak self] id in self?.perform(id) == true }
        thumbnails.canRun = { [weak self] id in self?.unavailableReason(for: id) == nil }
        self.thumbnails = thumbnails
        thumbnails.thumbnailSize = NSSize(width: 90, height: 120)
        thumbnails.backgroundColor = .clear
        return [SidebarPanel(thumbnails, sizing: .fill)] + (InfoPanel.make(info).map { [$0] } ?? [])
    }

    /// The pages as shown, unsaved marks and field values included, each fitted to the paper and turned to match it.
    /// None when the file's permissions forbid printing.
    var printJob: ((NSPrintInfo) -> NSPrintOperation?)? {
        guard let document = pdfView.document, !document.isLocked, document.allowsPrinting else { return nil }
        return { info in document.printOperation(for: info, scalingMode: .pageScaleToFit, autoRotate: true) }
    }

    /// A view-only document (the Space panel) leaves out the edit tools.
    var commands: [CommandSpec] {
        editable ? PDFPlugin.commands : PDFPlugin.commands.filter { !$0.isEditTool }
    }


    func setEditing(_ on: Bool) {
        guard editMode == .available, on != isEditing else { return }
        isEditing = on
        pdfView.isEditing = on
        thumbnails?.isEditing = on
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
        case "rotate-left" where isEditing, "rotate-right" where isEditing:
            guard unavailableReason(for: id) == nil else { return false }
            change(.rotatePages(pages: targetPages, by: id == "rotate-left" ? -90 : 90))
        case "delete-page" where isEditing:
            guard unavailableReason(for: id) == nil else { return false }
            change(.deletePages(pages: targetPages, token: UUID().uuidString))
        default:
            return false
        }
        return true
    }

    func unavailableReason(for command: String) -> String? {
        guard Self.pageCommands.contains(command), editMode == .available else { return nil }
        if !allowsPageChanges { return "This PDF's permissions don't allow page changes." }
        if command == "delete-page", targetPages.count >= pdfView.document?.pageCount ?? 0 { return "A PDF needs at least one page." }
        return nil
    }

    private var allowsPageChanges: Bool { pdfView.document?.allowsDocumentAssembly ?? false }

    /// The pages selected in the sidebar, or the current page when none are.
    private var targetPages: [Int] {
        guard let document = pdfView.document else { return [] }
        let selected = (thumbnails?.selectedPages ?? []).map(document.index(for:)).filter { $0 != NSNotFound }
        if !selected.isEmpty { return selected.sorted() }
        return pdfView.currentPage.map { [document.index(for: $0)] } ?? []
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
        var applied = false
        for edit in decoded.operations {
            if change(edit) {
                applied = true
            } else if edit.movesPages {
                break  // every later page index would point at the wrong page
            }
        }
        return applied
    }

    func save(_ edits: UnsavedEdits, accepting offer: SaveOffer?) async throws(PluginError) {
        guard let snapshot = edits.value as? PDFSnapshot else { throw PluginError("These changes aren't PDF edits.") }
        try await PDFPlugin.write(snapshot.edits.operations, to: url.path)
        pending.removeAll { $0.number <= snapshot.through }  // edits made during the save stay pending
    }

    func revertEdits() {
        guard let document = pdfView.document as? PeekerPDFDocument else { return }
        endInteraction()  // typing in progress becomes a pending edit, taken back with the rest
        for entry in pending.reversed() {
            do throws(PluginError) {
                try applyLive(entry.inverse, to: document)
            } catch {
                Self.log.error("couldn't take back an edit: \(error.message, privacy: .private)")
                if entry.inverse.movesPages { break }  // every earlier page index would point at the wrong page
            }
        }
        pending = []
        undoManager.removeAllActions()
    }

    /// Applies `edit` to the view, makes it pending and undoable. False, changing nothing, when it doesn't fit the
    /// file (recovered edits for a file that changed, say).
    @discardableResult
    func change(_ edit: PDFEdit) -> Bool {
        if edit.isPageEdit { endInteraction() }  // before reading the inverse: a deleted page's copy needs the finished text
        guard let document = pdfView.document as? PeekerPDFDocument, let inverse = inverse(of: edit, in: document) else {
            Self.log.error("skipped an edit for something no longer in the file")
            return false
        }
        do throws(PluginError) {
            try applyLive(edit, to: document)
        } catch {
            // Saving refuses the whole file over one edit it can't write, so such an edit never becomes pending.
            Self.log.error("skipped an edit: \(error.message, privacy: .private)")
            return false
        }
        record(edit, inverse: inverse)
        return true
    }

    /// Finishes typing and stops PDFKit's search, which reads the pages on another thread, before pages change.
    /// Ending the tools also drops the selection, whose page index a page edit may change.
    private func endInteraction() {
        tools?.end()
        container.finder.cancel()
    }

    /// Applies an edit to the document shown, as Peeker's own change rather than a thumbnail drag, then lays out the
    /// pages again after a page edit and tells the form fields a value they now show.
    private func applyLive(_ edit: PDFEdit, to document: PeekerPDFDocument) throws(PluginError) {
        try document.own { () throws(PluginError) in
            try PDFMarks.apply(edit, to: document, fileName: url.lastPathComponent, stash: stash)
        }
        if edit.isPageEdit { pagesChanged() }
        if case .field(let name, let value) = edit { fields?.applied(name, value) }
    }

    /// Pages were moved by a drag in the thumbnails. Puts the old order back with the original page objects (PDFKit
    /// leaves copies), then makes a real move an edit like any other; one that isn't a move, or isn't allowed, beeps.
    private func pagesDragged(before: [PDFPage]) {
        guard let document = pdfView.document as? PeekerPDFDocument else { return }
        endInteraction()
        let after = (0..<document.pageCount).compactMap(document.page(at:))
        let order = isEditing && allowsPageChanges ? PeekerPDFDocument.order(before: before, after: after) : nil
        document.own {
            for page in after where !before.contains(where: { $0 === page }) { document.removePage(at: document.index(for: page)) }
            for (index, page) in before.enumerated() where index >= document.pageCount || document.page(at: index) !== page {
                let at = document.index(for: page)
                if at != NSNotFound { document.removePage(at: at) }
                document.insert(page, at: index)
            }
        }
        if let order, order != Array(order.indices), change(.reorderPages(order: order)) { return }
        pagesChanged()
        if order == nil { NSSound.beep() }
    }

    private func pagesChanged() {
        pdfView.layoutDocumentView()
        container.finder.searchAgain()
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
        case .rotatePages(let pages, let by):
            return .rotatePages(pages: pages, by: -by)
        case .reorderPages(let order):
            guard order.count == document.pageCount, Set(order) == Set(order.indices) else { return nil }
            var back = order
            for (index, from) in order.enumerated() { back[from] = index }
            return .reorderPages(order: back)
        case .deletePages(let pages, let token):
            return copies(of: pages, in: document).map { .restorePages(pages: pages.sorted(), token: token, data: $0) }
        case .restorePages(let pages, let token, _):
            return .deletePages(pages: pages, token: token)
        }
    }

    /// The pages at `indices` as a PDF of copies, so a deletion can be undone after it was saved. Copying drops the
    /// annotations' names and styles, so they're put back as when saving moved pages.
    private func copies(of indices: [Int], in document: PDFDocument) -> Data? {
        let pages = indices.sorted().compactMap { (0..<document.pageCount).contains($0) ? document.page(at: $0) : nil }
        guard pages.count == indices.count else { return nil }
        let copy = PDFDocument()
        for (position, page) in pages.enumerated() {
            guard let duplicate = page.copy() as? PDFPage else { return nil }
            copy.insert(duplicate, at: position)
        }
        return copy.dataRepresentation().flatMap { MovedPageRepair.repaired($0, kept: MovedPageRepair.kept(on: pages)) }
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
