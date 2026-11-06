import AppKit
import os
import PDFKit
import PeekerKit

/// A PDF in a continuous native view with thumbnails and info. In the Editor it has find and edit tools: highlights,
/// form fields, text boxes, signatures, and rotating, deleting and reordering pages, saved on Cmd+S.
final class PDFPluginDocument: PluginDocument {
    let pdfView = PeekerPDFView()
    /// The PDF shown, unsaved edits included.
    let document: PeekerPDFDocument
    private(set) var url: URL
    private let editable: Bool
    /// The file's details for the info panel, read again after a save.
    private var info: [InfoRow]
    let editability: Editability
    private var isEditing: Bool { editability == .editable }
    var onEdit: (() -> Void)?
    var onActiveToolChange: (() -> Void)?
    /// The edit tools' parts, made when a tool or a form field is first used, so opening doesn't pay for them.
    private(set) var editController: EditController?
    private var fields: FormFields?
    /// Edits made since the file was loaded or last saved, oldest first, each numbered and with the edit that undoes it.
    private var pending: [(number: Int, edit: PDFEdit, inverse: PDFEdit)] = []
    private var lastNumber = 0
    /// The document's own undo history, which the view hands out only in the Editor. Not the window's: that one
    /// outlives the document (Open With, reload), and its actions would then run on a freed document.
    private(set) lazy var undoManager = UndoManager()
    /// Pages deleted in this view, for their undo.
    private let stash = PageStash()
    /// The highlight color in use, one of `PDFPlugin.highlightColors` by id, remembered in the app's preferences.
    private var highlightChoice = PDFPlugin.highlightColors[0].id
    private var highlightColor = PDFPlugin.highlightColors[0].color ?? RGBA(red: 1, green: 0.8, blue: 0, alpha: 1)
    private let preferences: PluginPreferences?
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "dev.peeker", category: "pdf")

    /// `uneditableReason` makes a file that can't be safely changed read-only.
    init(url: URL, document: PeekerPDFDocument, info: [InfoRow], editable: Bool, uneditableReason: String? = nil,
         preferences: PluginPreferences? = nil) {
        self.preferences = preferences
        let remembered = preferences?.string("highlightColor").map { "highlight-\($0)" }
        if let choice = PDFPlugin.highlightColors.first(where: { $0.id == remembered }), let color = choice.color {
            (highlightChoice, highlightColor) = (choice.id, color)
        }
        self.url = url
        self.document = document
        self.info = info
        self.editable = editable
        editability = !editable ? .notEditable : uneditableReason.map(Editability.readOnly) ?? .editable
        pdfView.document = document
        document.onForeignChange = { [weak self] before in self?.pagesDragged(before: before) }
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        if isEditing {
            // Flags only: the edit parts wait for their first use.
            pdfView.isEditing = true
            pdfView.editUndoManager = undoManager
            pdfView.onFirstUse = { [weak self] in self?.prepareEditing() }
            if document.allowsDocumentAssembly {
                pdfView.onDropFiles = { [weak self] urls in
                    Task { await self?.insertPages(from: urls) }
                    return true
                }
                pdfView.registerForDraggedTypes([.fileURL])
            }
        }
    }

    /// The thumbnails last made for the sidebar, for the selected pages.
    private weak var thumbnails: PageThumbnails?
    private static let pageTools: Set = ["rotate-left", "rotate-right", "delete-page", "insert-pages", "save-selected-pages", "split"]

    /// The pages, with the find bar above them from the first Cmd+F. No find in the Peek panel.
    private lazy var container = PDFFindContainer(pdfView: pdfView, allowsFind: editable)
    var contentView: NSView { container }
    var focusView: NSView? { pdfView }

    func makeSidebar() -> [SidebarPanel] {
        let pageTools = PDFPlugin.tools.filter { Self.pageTools.contains($0.id) }
        let thumbnails = PageThumbnails(tools: pageTools.map { ($0.id, $0.title) })
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
        guard !document.isLocked, document.allowsPrinting else { return nil }
        return { [document] info in document.printOperation(for: info, scalingMode: .pageScaleToFit, autoRotate: true) }
    }

    /// A view-only document (the Peek panel) leaves out the edit tools.
    var tools: [ToolSpec] {
        editable ? PDFPlugin.tools : PDFPlugin.tools.filter { !$0.isEditTool }
    }


    /// Makes the edit tools' parts and starts watching the form fields, once: before the first tool runs, and before
    /// the view handles the first click on an annotation or field, so that click's change is recorded.
    @discardableResult func prepareEditing() -> EditController? {
        guard isEditing else { return nil }
        if let editController { return editController }
        let controller = EditController(document: self)
        controller.onToolChange = { [weak self] in self?.onActiveToolChange?() }
        editController = controller
        pdfView.editController = controller
        let fields = FormFields(view: pdfView)
        fields.onChange = { [weak self] name, new, old in self?.record(.field(name: name, value: new), inverse: .field(name: name, value: old)) }
        self.fields = fields
        pdfView.onInteraction = { [weak fields] widget in
            if let widget { fields?.clicked(widget) }
            fields?.check()  // records the fields the click changed
        }
        return controller
    }

    /// The tool waiting for its click or drag, by id.
    var activeTool: String? {
        switch editController?.tool ?? .none {
        case .textBox: "text-box"
        case .signature: "sign"
        case .highlighter: "highlight"
        case .none: nil
        }
    }

    /// The highlight color in use is on.
    func isOn(_ tool: String) -> Bool? {
        tool.hasPrefix("highlight-") ? tool == highlightChoice : nil
    }

    func perform(_ id: String) -> Bool {
        switch id {
        case "insert-pages" where isEditing && unavailableReason(for: id) == nil: chooseFilesToInsert()
        case "save-selected-pages" where isEditing && unavailableReason(for: id) == nil: chooseWhereToSavePages()
        case "split" where isEditing && unavailableReason(for: id) == nil: askHowToSplit()
        case "zoom-in": pdfView.zoomIn(nil)
        case "zoom-out": pdfView.zoomOut(nil)
        case "zoom-fit": pdfView.autoScales = true
        case "zoom-actual":
            pdfView.autoScales = false
            pdfView.scaleFactor = 1
        case "text-box" where isEditing:
            prepareEditing()?.chooseTextBox()
        case "sign" where isEditing:
            guard let window = pdfView.window else { return true }
            prepareEditing()
            SignaturePad.present(on: window) { [weak self] signature in self?.editController?.startPlacing(signature) }
        case "highlight" where isEditing:
            highlightSelection()
            prepareEditing()?.armHighlighter()
        case let id where isEditing && id.hasPrefix("highlight-"):
            guard let color = PDFPlugin.highlightColors.first(where: { $0.id == id })?.color else { return false }
            (highlightChoice, highlightColor) = (id, color)
            preferences?.set(String(id.dropFirst("highlight-".count)), for: "highlightColor")
            return perform("highlight")
        case "rotate-left" where isEditing, "rotate-right" where isEditing:
            guard unavailableReason(for: id) == nil else { return false }
            change(.rotatePages(pages: targetPages, by: id == "rotate-left" ? -90 : 90))
        case "delete-page" where isEditing:
            guard unavailableReason(for: id) == nil else { return false }
            change(.deletePages(pages: targetPages, token: UUID().uuidString))
        default:
            return false
        }
        if PDFPlugin.tools.contains(where: { $0.id == id && $0.isEditTool }) { takeKeyboard() }
        return true
    }

    /// After an edit tool, Undo must reach the document's history: the pages take the keyboard back from the find
    /// field, while the thumbnails keep it and pass Undo on themselves.
    private func takeKeyboard() {
        guard let window = pdfView.window else { return }
        if let thumbnails, let focused = window.firstResponder as? NSView, focused.isDescendant(of: thumbnails) { return }
        window.makeFirstResponder(pdfView)
    }

    /// Covers each line of the text selection with a highlight, as one undo step, and clears the selection.
    func highlightSelection() {
        let lines = pdfView.currentSelection?.selectionsByLine() ?? []
        pdfView.clearSelection()
        undoManager.beginUndoGrouping()  // one undo step for every line
        defer { undoManager.endUndoGrouping() }
        for line in lines {
            for page in line.pages {
                change(.add(PDFMark(id: PDFEdit.newID(), page: document.index(for: page), rect: line.bounds(for: page), kind: .highlight(highlightColor))))
            }
        }
    }

    func unavailableReason(for tool: String) -> String? {
        guard Self.pageTools.contains(tool), editability == .editable else { return nil }
        if !allowsPageChanges { return "This PDF's permissions don't allow page changes." }
        if tool == "delete-page", targetPages.count >= document.pageCount { return "A PDF needs at least one page." }
        if tool == "split", document.pageCount < 2 { return "There's only one page." }
        return nil
    }

    private var allowsPageChanges: Bool { document.allowsDocumentAssembly }

    /// The pages selected in the sidebar, or the current page when none are.
    var targetPages: [Int] {
        let selected = (thumbnails?.selectedPages ?? []).map(document.index(for:)).filter { $0 != NSNotFound }
        if !selected.isEmpty { return selected.sorted() }
        return pdfView.currentPage.map { [document.index(for: $0)] } ?? []
    }

    /// The unsaved edits, folded; empty when there are none.
    var pendingEdits: [PDFEdit] { PDFEdit.folded(pending.map(\.edit)) }

    func unsavedEdits() -> UnsavedEdits? {
        let edits = pendingEdits
        guard !edits.isEmpty, let last = pending.last else { return nil }
        return UnsavedEdits(PDFSnapshot(edits: edits, through: last.number))
    }

    func restore(encoded edits: Data) -> Bool {
        // A file signed or locked since the record was written must not take its edits.
        guard editability == .editable, let decoded = try? JSONDecoder().decode([PDFEdit].self, from: edits) else { return false }
        var applied = false
        for edit in decoded {
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
        try await PDFPlugin.write(snapshot.edits, to: url.path)
        pending.removeAll { $0.number <= snapshot.through }  // edits made during the save stay pending
        if let checked = try? await PDFPlugin.check(url) { info = checked.info }
    }

    func saveAs(_ unsaved: UnsavedEdits?, to destination: URL, accepting offer: SaveOffer?) async throws(PluginError) {
        if let snapshot = unsaved?.value as? PDFSnapshot {
            try await PDFPlugin.write(snapshot.edits, from: url.path, to: destination.path)
            pending.removeAll { $0.number <= snapshot.through }
        } else {
            try await FileReplacement.copy(url, to: destination)
        }
        url = destination
        if let checked = try? await PDFPlugin.check(url) { info = checked.info }
    }

    func revertEdits() {
        endInteraction()  // typing in progress becomes a pending edit, taken back with the rest
        for entry in pending.reversed() {
            do throws(PluginError) {
                try applyLive(entry.inverse)
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
        if edit.isPageEdit { endInteraction() }  // typing ends first, so a deleted page keeps the finished text
        var edit = edit
        if case .restorePages(let pages, let token, let data) = edit, data.isEmpty, let kept = stash.pages[token] {
            // An undone deletion: saving and crash recovery restore from a copy, since they don't have these page objects.
            guard let copy = PDFEditing.copy(of: kept) else {
                Self.log.error("couldn't copy the deleted pages for their restore")
                return false
            }
            edit = .restorePages(pages: pages, token: token, data: copy)
        }
        guard let inverse = PDFEditing.inverse(of: edit, in: document) else {
            Self.log.error("skipped an edit for something no longer in the file")
            return false
        }
        do throws(PluginError) {
            try applyLive(edit)
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
        editController?.end()
        container.finder.cancel()
    }

    /// Applies an edit to the document shown, as Peeker's own change rather than a thumbnail drag, then lays out the
    /// pages again after a page edit, animating it, and tells the form fields a value they now show.
    private func applyLive(_ edit: PDFEdit) throws(PluginError) {
        let motion = PageMotion(for: edit, in: pdfView)
        let selected = thumbnails?.selectedPages ?? []
        try document.own { () throws(PluginError) in
            try PDFEditing.apply(edit, to: document, fileName: url.lastPathComponent, stash: stash)
        }
        if edit.isPageEdit {
            pagesChanged()
            thumbnails?.reselect(selected)
        }
        motion?.play()
        pdfView.sharpenAnnotations()
        if case .field(let name, let value) = edit { fields?.applied(name, value) }
    }

    /// Pages were moved by a drag in the thumbnails. Puts the old order back with the original page objects (PDFKit
    /// leaves copies), then makes a real move an edit like any other; one that isn't a move, or isn't allowed, beeps.
    private func pagesDragged(before: [PDFPage]) {
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
        // A group of its own: in a window it nests in the event's group, so one tool run is one undo step.
        undoManager.beginUndoGrouping()
        undoManager.registerUndo(withTarget: self) { [weak self] _ in self?.change(inverse) }
        undoManager.endUndoGrouping()
        onEdit?()
    }
}

/// What `unsavedEdits()` hands out: the folded edits, and the number of the last one, so saving knows which pending
/// edits it wrote. Encodes as the edits alone.
nonisolated struct PDFSnapshot: Encodable, Sendable {
    let edits: [PDFEdit]
    let through: Int

    func encode(to encoder: any Encoder) throws {
        try edits.encode(to: encoder)
    }
}
