import AppKit
import os
import PDFKit
import PeekerKit

/// A PDF in a continuous native view with thumbnails and info. In the Editor it has find and edit tools: highlights,
/// form fields, text boxes, signatures, and rotating, deleting and reordering pages, saved on Cmd+S.
final class PDFPluginDocument: PluginDocument, Zooming {
    let pdfView = PeekerPDFView()
    /// The PDF shown, unsaved edits included.
    let document: PeekerPDFDocument
    private(set) var url: URL
    private let editable: Bool
    /// The file's details for the info panel, read again after a save.
    private var info: [InfoRow]
    let editability: Editability
    var isEditing: Bool { editability == .editable }
    var onEdit: (() -> Void)?
    var onActiveToolChange: (() -> Void)?
    var onZoomChange: (() -> Void)?
    /// Reports every scale change to `onZoomChange`, whether the menu, `setZoom` or a resize made it.
    private var scaleObserver: NSObjectProtocol?
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
    let preferences: PluginPreferences?
    /// Markup's strip is on, whether or not a tool is armed.
    var isMarkingUp = false
    /// The drawing color and size without preferences (tests).
    var unrememberedMarkup = (color: PDFMarkupStrip.palette[0].color, size: MarkupSize.medium)
    /// Where marks are copied and pasted; tests use one of their own.
    lazy var pasteboard = NSPasteboard.general
    /// The passwords of a password-protected PDF, for saving it locked; nil for any other PDF.
    private(set) var lock: PDFLock?
    /// Encrypts the crash-recovery copy of a password-protected PDF's edits.
    private let recoveryKey: RecoveryKey?
    /// Asks for one of the PDF's passwords when a save needs it; tests answer for the user.
    lazy var askForPassword: (_ kind: PDFPasswordKind) async -> String? = { [weak self] kind in await self?.passwordSheet(kind) }
    /// Notes about a save already shown in this window, each said once.
    private(set) var shownNotes: [String] = []
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "dev.peeker", category: "pdf")

    /// `uneditableReason` makes a file that can't be safely changed read-only.
    init(url: URL, document: PeekerPDFDocument, info: [InfoRow], editable: Bool, uneditableReason: String? = nil,
         preferences: PluginPreferences? = nil, lock: PDFLock? = nil, recoveryKey: RecoveryKey? = nil) {
        self.preferences = preferences
        self.lock = lock
        self.recoveryKey = recoveryKey ?? lock.map { RecoveryKey(password: $0.password) }
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
            pdfView.onCopy = { [weak self] in self?.copyMark() == true }
            pdfView.onPaste = { [weak self] in self?.pasteMark() == true }
            pdfView.canPaste = { [weak self] in self?.canPasteMark == true }
            if document.allowsDocumentAssembly {
                pdfView.onDropFiles = { [weak self] urls in
                    Task { await self?.insertPages(from: urls) }
                    return true
                }
                pdfView.registerForDraggedTypes([.fileURL])
            }
        }
        scaleObserver = NotificationCenter.default.addObserver(forName: .PDFViewScaleChanged, object: pdfView, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.onZoomChange?() }
        }
    }

    isolated deinit {
        scaleObserver.map(NotificationCenter.default.removeObserver)
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
        controller.onStripChange = { [weak self] in self?.showMarkupStrip() }
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

    /// The tool waiting for its click or drag, by id; Markup while its strip is on.
    var activeTool: String? {
        switch editController?.tool ?? .none {
        case .textBox, .draw: "markup"
        case .signature: "sign"
        case .highlighter: "highlight"
        case .none: isMarkingUp ? "markup" : nil
        }
    }

    /// The highlight color in use, and the armed markup tool, are on.
    func isOn(_ tool: String) -> Bool? {
        if tool.hasPrefix("highlight-") { return tool == highlightChoice }
        return PDFPlugin.markupTools.contains { $0.id == tool } ? tool == armedToolID : nil
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
        case "markup" where isEditing:
            toggleMarkup()
        case let id where isEditing && PDFPlugin.markupTools.contains { $0.id == id }:
            armMarkupTool(id)
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
        if let lock, !lock.password.isEmpty, tool == "save-selected-pages" || tool == "split" { return "Peeker can't yet save a password-protected PDF's pages as new files." }
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
        return UnsavedEdits(PDFSnapshot(edits: edits, through: last.number, key: recoveryKey))
    }

    func restore(encoded edits: Data) -> Bool {
        // A file signed or locked since the record was written must not take its edits.
        // A sealed record goes to the lock screen, which opens it before handing this document over.
        guard editability == .editable, let decoded = try? JSONDecoder().decode([PDFEdit].self, from: edits) else { return false }
        var applied = false
        for edit in decoded {
            if change(edit) {
                applied = true
            } else if edit.movesPages {
                break  // every later page index would point at the wrong page
            }
        }
        // A record whose only edit was a signature is empty: nothing to restore, so the host can drop it.
        return applied || decoded.isEmpty
    }

    func save(_ edits: UnsavedEdits, accepting offer: SaveOffer?) async throws(PluginError) {
        guard let snapshot = edits.value as? PDFSnapshot else { throw PluginError("These changes aren't PDF edits.") }
        let note = try await writeLocked(snapshot.edits, from: url.path, to: url.path)
        pending.removeAll { $0.number <= snapshot.through }  // edits made during the save stay pending
        await show(note)
        if let checked = try? await PDFPlugin.check(url) { info = checked.info }
    }

    func saveAs(_ unsaved: UnsavedEdits?, to destination: URL, accepting offer: SaveOffer?) async throws(PluginError) {
        if let snapshot = unsaved?.value as? PDFSnapshot {
            let note = try await writeLocked(snapshot.edits, from: url.path, to: destination.path)
            pending.removeAll { $0.number <= snapshot.through }
            await show(note)
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
        if case .rotatePages = edit {
            // PDFKit lays out a turned page on a later main queue turn, holding the view only weakly, and reads a
            // missing view when the window closed in between: the view stays until that layout has run.
            DispatchQueue.main.async { [pdfView] in withExtendedLifetime(pdfView) {} }
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
        editController?.onStripChange?()  // an undone restyle changes what the strip shows
    }

    // MARK: Text box style

    /// The style and size the next text box gets, read from the app's preferences each time, so a change in another
    /// window counts here too; without preferences (tests), kept here.
    var textBoxStyle: TextBoxStyle {
        guard let preferences else { return unrememberedStyle.style }
        return preferences.string("textBoxStyle").flatMap { try? JSONDecoder().decode(TextBoxStyle.self, from: Data($0.utf8)) }
            .flatMap { $0.isValid ? $0 : nil } ?? .standard
    }
    var textBoxSize: Double {
        guard let preferences else { return unrememberedStyle.size }
        return preferences.double("textBoxSize").flatMap { PDFMarks.fontSizes.contains($0) ? $0 : nil } ?? TextBoxStyle.standardSize
    }
    private var unrememberedStyle = (style: TextBoxStyle.standard, size: TextBoxStyle.standardSize)

    func rememberTextBox(_ style: TextBoxStyle, size: Double) {
        unrememberedStyle = (style, size)
        if let json = try? JSONEncoder().encode(style) { preferences?.set(String(decoding: json, as: UTF8.self), for: "textBoxStyle") }
        preferences?.set(size, for: "textBoxSize")
    }
}

/// What `unsavedEdits()` hands out: the folded edits, and the number of the last one, so saving knows which pending
/// edits it wrote. Encodes, for the crash-recovery copy, as the edits a recovery may hold, sealed with `key` for a
/// password-protected PDF.
nonisolated struct PDFSnapshot: Encodable, Sendable {
    let edits: [PDFEdit]
    let through: Int
    var key: RecoveryKey?

    func encode(to encoder: any Encoder) throws {
        if let key {
            try key.seal(try JSONEncoder().encode(Self.recoverable(edits))).encode(to: encoder)
        } else {
            try Self.recoverable(edits).encode(to: encoder)
        }
    }

    /// `edits` with no signature strokes in them, since a signature goes only into the PDF it's placed in: one placed
    /// since the last save is left out and has to be placed again after a crash. A saved signature removed and put back
    /// is kept as a move. A deleted page put back carries no copy when its deletion is in the list too, since replaying
    /// that keeps the pages; the copy of a saved deletion loses Peeker's signatures, or its pages when it can't be
    /// rewritten. Pages inserted from another PDF are a copy of that file, kept as they are.
    static func recoverable(_ edits: [PDFEdit]) -> [PDFEdit] {
        var removed = Set<String>(), deletedPages = Set<String>(), kept: [PDFEdit] = []
        for edit in edits {
            switch edit {
            case .delete(let id, .signature, _):
                removed.insert(id)
                kept.append(edit)
            case .add(let mark):
                guard case .signature = mark.kind else { kept.append(edit); continue }
                if removed.contains(mark.id) {
                    kept.removeAll { if case .delete(mark.id, _, _) = $0 { true } else { false } }
                    kept.append(.setBounds(id: mark.id, type: .signature, page: mark.page, rect: mark.rect))
                }
            case .deletePages(_, let token):
                deletedPages.insert(token)
                kept.append(edit)
            case .restorePages(let pages, let token, let data) where !data.isEmpty:
                kept.append(.restorePages(pages: pages, token: token, data: deletedPages.contains(token) ? Data() : withoutSignatures(data)))
            default:
                kept.append(edit)
            }
        }
        return kept
    }

    /// The pages in `data` without Peeker's signatures; empty when they can't be read or written.
    private static func withoutSignatures(_ data: Data) -> Data {
        guard let copy = PDFDocument(data: data) else { return Data() }
        var removed = false
        for page in (0..<copy.pageCount).compactMap(copy.page(at:)) {
            for annotation in page.annotations where PDFMarks.id(of: annotation) != nil && PDFMarks.type(of: annotation) == .signature {
                page.removeAnnotation(annotation)
                removed = true
            }
        }
        return removed ? copy.dataRepresentation() ?? Data() : data
    }
}

// MARK: Saving a password-protected PDF

extension PDFPluginDocument {
    static let notOpenPassword = "That isn't this PDF's open password. The permissions password can't stand in for it."

    /// Writes `edits` keeping the PDF's lock, asking for a password the save needs and trying again.
    fileprivate func writeLocked(_ edits: [PDFEdit], from source: String, to path: String) async throws(PluginError) -> String? {
        while true {
            do {
                return try await PDFPlugin.write(edits, from: source, to: path, lock: lock)
            } catch let error where error.offer == PDFPlugin.openPasswordOffer {
                try await takePassword(.open)
            } catch let error where error.offer == PDFPlugin.permissionsPasswordOffer {
                try await takePassword(.permissions)
            }
        }
    }

    /// Asks for one of the passwords, checks it on the file and keeps it for later saves. The open password must open
    /// the file as its reader, so the permissions password can't stand in for it.
    fileprivate func takePassword(_ kind: PDFPasswordKind) async throws(PluginError) {
        guard let typed = await askForPassword(kind) else { throw PluginError.cancelled }
        let check = PDFDocument(url: url)
        var lock = lock ?? PDFLock(password: "", isPermissionsPassword: false)  // a PDF that opens without a password
        switch kind {
        case .open:
            guard let check, check.isLocked, check.unlock(withPassword: typed), check.permissionsStatus == .user else {
                throw PluginError(Self.notOpenPassword)
            }
            lock.openPassword = typed
        case .permissions:
            // A file whose permissions password is empty opens with its rights already; any string would pass.
            guard let check, check.permissionsStatus != .owner, check.unlock(withPassword: typed), check.permissionsStatus == .owner else {
                throw PluginError("That isn't this PDF's permissions password.")
            }
            lock.permissionsPassword = typed
        }
        self.lock = lock
    }

    /// A note about how the file was saved, once per window, waiting for it to be read so a save that closes the
    /// window doesn't take it away unseen.
    fileprivate func show(_ note: String?) async {
        guard let note, !shownNotes.contains(note) else { return }
        shownNotes.append(note)
        guard let window = pdfView.window else { return }
        let alert = NSAlert()
        alert.messageText = "“\(url.lastPathComponent)” was saved."
        alert.informativeText = note
        await alert.beginSheetModal(for: window)
    }

    fileprivate func passwordSheet(_ kind: PDFPasswordKind) async -> String? {
        guard let window = pdfView.window else { return nil }
        let alert = NSAlert()
        alert.messageText = kind == .open ? "Enter the open password for “\(url.lastPathComponent)”" : "Enter the permissions password for “\(url.lastPathComponent)”"
        alert.informativeText = kind == .open ? PDFPlugin.needsOpenPassword : PDFPlugin.needsPermissionsPassword
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 22))
        field.placeholderString = kind == .open ? "Open password" : "Permissions password"
        alert.accessoryView = field
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        let response = await alert.beginSheetModal(for: window)
        return response == .alertFirstButtonReturn ? field.stringValue : nil
    }
}

/// Which of a PDF's two passwords a save asks for.
enum PDFPasswordKind { case open, permissions }
