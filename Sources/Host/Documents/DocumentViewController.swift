import AppKit
import os

/// What became of recovered edits once the document had content to apply them to.
enum RecoveryResult: Equatable {
    case restored(fileChangedSince: Bool)
    /// This view can't take the edits (it's view-only, or the file now opens read-only). The record is left on disk
    /// for the handler, and this document stops journaling, so it never replaces or removes that record.
    case rejected(RecoveryRecord)
}

/// One open file, shown by one plugin. Used by both document windows and the quick-look panel.
final class DocumentViewController: NSSplitViewController {
    let url: URL
    let entry: PluginEntry
    private let process: PluginProcess
    private let config: Config
    private let docID = UUID().uuidString
    private let content = HolderViewController()
    private var sidebarItem: NSSplitViewItem?
    /// Panels from the first reply, installed after the content is on screen so they don't delay it.
    private var pendingSidebar: [Panel]?
    /// Document windows edit; the quick-look panel and the benchmark only view.
    private let allowsEditing: Bool
    /// Readable so tests can drive edits.
    private(set) var component: Component?
    private(set) var isEdited = false {
        didSet {
            guard isEdited != oldValue else { return }
            view.window?.isDocumentEdited = isEdited
            onEditedChanged?(self)
        }
    }
    private(set) var isSaving = false
    /// Counts edits, so a save can tell whether the user typed while it was in flight.
    private var editCount = 0
    /// The file's modification date when it was last loaded or saved here (for recovered edits, when they were made).
    /// A different date means someone else wrote it.
    private(set) var knownModification: Date?
    /// The plugin lost this document (it crashed while there were edits), so a save must open it there again first.
    private var pluginNeedsReopen = false
    private var watcher: FileWatcher?
    /// Where unsaved edits are journaled for crash recovery; nil for view-only documents.
    private var recovery: RecoveryStore?
    private let recoveryID: String
    private var pendingJournal: DispatchWorkItem?
    /// Recovered edits waiting for content: the open is still running, or it failed and a Reopen may succeed.
    private var unappliedRecord: RecoveryRecord?
    private static let journalDelay = 2.0
    private var opened = ContinuousClock.now
    private var pluginWasRunning = false
    private var isReady = false
    private var isClosed = false
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "dev.previewpp", category: "documents")
    /// Time from `load()` until the plugin's reply arrived, before the host drew anything.
    private(set) var replyDuration: Duration = .zero
    /// The plugin's commands, each with its shortcut after config overrides.
    private(set) var commands: [(spec: CommandSpec, shortcut: Shortcut?)] = []

    /// First content on screen: time since `load()`, and whether the plugin process was already running.
    var onReady: ((DocumentViewController, Duration, Bool) -> Void)?
    var onFailure: ((DocumentViewController, String) -> Void)?
    var onCommandsChanged: ((DocumentViewController) -> Void)?
    var onEditedChanged: ((DocumentViewController) -> Void)?
    var onRecovery: ((DocumentViewController, RecoveryResult) -> Void)?

    init(url: URL, entry: PluginEntry, process: PluginProcess, config: Config, allowsEditing: Bool, recovery: RecoveryStore?, recoveryID: String = UUID().uuidString) {
        self.url = url
        self.entry = entry
        self.process = process
        self.config = config
        self.allowsEditing = allowsEditing
        self.recovery = recovery
        self.recoveryID = recoveryID
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        addSplitViewItem(NSSplitViewItem(viewController: content))
    }

    /// Pixel size the image plugin should decode to: the largest screen, so fit-to-window stays sharp.
    private static var maxPixels: Int {
        let screens = NSScreen.screens.map { max($0.frame.width, $0.frame.height) * $0.backingScaleFactor }
        return Int(screens.max() ?? 2048)
    }

    /// Opens the file in the plugin. Returns once the content or the failure view is showing.
    func load() async {
        opened = .now
        isReady = false
        pluginWasRunning = process.isRunning
        knownModification = Self.modificationDate(of: url)
        process.attach(docID) { [weak self] message in self?.fail(message) }
        // Applied in the reply callback rather than after an await, so the content is drawn without waiting a turn.
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            process.send(.open(path: url.path, maxPixels: Self.maxPixels), doc: docID, timeout: PluginTimeout.open) { [self] result in
                replyDuration = .now - opened
                handle(result)
                done.resume()
            }
        }
    }

    func run(_ spec: CommandSpec) {
        if let verb = spec.verb {
            if component?.perform(verb) != true { NSSound.beep() }
            return
        }
        send(command: spec.id, args: [:])
    }

    /// Without edits the recovery record goes; with edits (closed without the prompt) or recovered edits still waiting
    /// to be applied, it's kept so nothing is lost.
    func close() {
        if unappliedRecord == nil { journal() }
        isClosed = true
        watcher?.stop()
        watcher = nil
        process.notifyClose(docID)
        process.detach(docID)
    }

    /// Sends the pending edits to the plugin, which writes the file. On anything but `.saved` the edits stay pending.
    func save(prompts: any SavePrompts) async -> SaveOutcome {
        guard !isSaving else { return .cancelled }
        guard let component, let edits = component.pendingEdits() else {
            // Edited, then changed back: nothing differs from what was loaded.
            isEdited = false
            journal()
            reloadIfChangedOnDisk()
            return .saved
        }
        isSaving = true
        defer { isSaving = false }
        switch Self.modificationDate(of: url) {
        case nil:
            guard await prompts.confirmRecreateMissingFile(named: url.lastPathComponent) else { return .cancelled }
        case let modified where modified != knownModification:
            guard await prompts.confirmOverwriteNewerFile(named: url.lastPathComponent) else { return .cancelled }
        default:
            break
        }
        let editsAtSave = editCount
        do throws(PluginFailure) {
            // Not running means it crashed since the open: attached documents keep a healthy plugin alive.
            if pluginNeedsReopen || !process.isRunning { try await reopenInPlugin() }
            let reply: Reply
            do {
                reply = try await requestSave(edits, convertToUTF8: false)
            } catch where error.code == .cannotEncode {
                guard await prompts.confirmSaveAsUTF8(reason: error.message) else { return .cancelled }
                reply = try await requestSave(edits, convertToUTF8: true)
            }
            component.didSave(edits)
            knownModification = Self.modificationDate(of: url)
            isEdited = editCount != editsAtSave
            journal()  // removes the record, or keeps only edits made during the save
            if let panels = reply.sidebar, !isClosed { installSidebar(panels) }
            return .saved
        } catch {
            // The plugin may have lost the document's state (a crash or timeout); opening it again is cheap.
            pluginNeedsReopen = true
            Self.log.error("\(self.entry.id, privacy: .public): saving \(self.url.lastPathComponent, privacy: .private) failed: \(error.message, privacy: .private)")
            return .failed(error.message)
        }
    }

    /// "Don't Save": goes back to the text as last loaded or saved.
    func discardEdits() {
        component?.revertEdits()
        isEdited = false
        journal()
        reloadIfChangedOnDisk()
    }

    /// Applies edits recovered after a crash, as if the user had just made them: now if the content is showing, else
    /// once it is. Reports through `onRecovery`.
    func restore(_ record: RecoveryRecord) {
        guard !isClosed else { return }
        unappliedRecord = record
        applyRecoveredEdits()
    }

    private func applyRecoveredEdits() {
        guard let record = unappliedRecord, let component, !isClosed else { return }
        unappliedRecord = nil
        component.restore(record.edits)
        if component.pendingEdits() != nil {
            let changedSince = knownModification != record.fileModified
            // Saving then asks before replacing a file that changed since the edits were made.
            knownModification = record.fileModified
            didEdit()
            onRecovery?(self, .restored(fileChangedSince: changedSince))
        } else if (component as? TextComponent)?.isEditable == true {
            // An editable text view reports no edits only when the recovered text matches the file.
            isEdited = false
            journal()
        } else {
            recovery = nil
            onRecovery?(self, .rejected(record))
        }
    }

    /// Writes the pending edits to the recovery store, or removes the record when there are none.
    private func journal() {
        pendingJournal?.cancel()
        pendingJournal = nil
        guard let recovery else { return }
        guard isEdited, let edits = component?.pendingEdits() else {
            recovery.remove(id: recoveryID)
            return
        }
        recovery.writeInBackground(RecoveryRecord(id: recoveryID, url: url, pluginID: entry.id, fileModified: knownModification, edits: edits))
    }

    /// Journals `journalDelay` after the last edit; each edit restarts the delay.
    private func scheduleJournal() {
        guard recovery != nil else { return }
        pendingJournal?.cancel()
        let work = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.journal() } }
        pendingJournal = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.journalDelay, execute: work)
    }

    private func requestSave(_ edits: Edits, convertToUTF8: Bool) async throws(PluginFailure) -> Reply {
        let payload: SavePayload
        switch edits {
        case .text(let text): payload = .text(try SharedFile.create(Data(text.utf8)), convertToUTF8: convertToUTF8)
        case .pdfHighlights(let highlights): payload = .pdfHighlights(highlights)
        }
        do {
            return try await process.request(.save(payload), doc: docID, timeout: PluginTimeout.save)
        } catch {
            // The plugin unlinks the file once it maps it; if it never got that far, the file is still there.
            if case .text(let ref, _) = payload { SharedFile.discard(ref) }
            throw error
        }
    }

    /// Opens the file in the plugin again without touching what's on screen, so it has the state a save needs.
    private func reopenInPlugin() async throws(PluginFailure) {
        let reply = try await process.request(.open(path: url.path, maxPixels: Self.maxPixels), doc: docID, timeout: PluginTimeout.open)
        reply.view?.sharedFile.map(SharedFile.discard)
        pluginNeedsReopen = false
    }

    private func didEdit() {
        editCount += 1
        isEdited = true
        scheduleJournal()
    }

    /// Reloads when someone else changed the file. Never while there are unsaved edits: saving asks about it instead.
    /// Internal so tests can start a reload at a chosen moment.
    func reloadIfChangedOnDisk() {
        guard !isEdited, !isSaving, !isClosed, isReady else { return }
        let modified = Self.modificationDate(of: url)
        guard modified != knownModification else { return }
        process.send(.open(path: url.path, maxPixels: Self.maxPixels), doc: docID, timeout: PluginTimeout.open) { [weak self] result in
            // Edits that started while the reload was in flight win. The known date stays old, so saving still asks.
            guard let self, !isEdited else {
                if case .success(let reply) = result { reply.view?.sharedFile.map(SharedFile.discard) }
                return
            }
            if case .success = result { knownModification = modified }
            handle(result)
        }
    }

    /// Follows symlinks, as the plugin does when it saves. Nil when the file is gone.
    private static func modificationDate(of url: URL) -> Date? {
        var info = stat()
        guard stat(url.path, &info) == 0 else { return nil }
        let time = info.st_mtimespec
        return Date(timeIntervalSince1970: TimeInterval(time.tv_sec) + TimeInterval(time.tv_nsec) / 1_000_000_000)
    }

    private func send(command: String, args: [String: Int]) {
        Task {
            do throws(PluginFailure) {
                handle(.success(try await process.request(.command(id: command, args: args), doc: docID, timeout: PluginTimeout.command)))
            } catch {
                handle(.failure(error))
            }
        }
    }

    private func handle(_ result: Result<Reply, PluginFailure>) {
        guard !isClosed else {
            if case .success(let reply) = result { reply.view?.sharedFile.map(SharedFile.discard) }
            return
        }
        switch result {
        case .failure(let failure): fail(failure.message)
        case .success(let reply): apply(reply)
        }
    }

    private func apply(_ reply: Reply) {
        do {
            if let view = reply.view {
                // A reply that arrives after the user started editing must not replace the edits, nor its sidebar.
                guard !isEdited else {
                    view.sharedFile.map(SharedFile.discard)
                    return
                }
                try install(view)
            }
        } catch {
            reply.view?.sharedFile.map(SharedFile.discard)
            Self.log.error("\(self.entry.id, privacy: .public): can't show view: \(error, privacy: .public)")
            fail("The \(entry.manifest.name) plugin sent something the app can't show.")
            return
        }
        if let panels = reply.sidebar {
            if isReady { installSidebar(panels) } else { pendingSidebar = panels }
        }
        if let specs = reply.commands, specs != commands.map(\.spec) {
            commands = specs.map { ($0, config.keys["\(entry.id).\($0.id)"] ?? $0.shortcut.flatMap(Shortcut.init(parsing:))) }
            onCommandsChanged?(self)
        }
        markReady()
        applyRecoveredEdits()
    }

    private func install(_ view: View) throws {
        switch view {
        case .markdown(let blocks):
            if let markdown = component as? MarkdownComponent {
                markdown.update(blocks: blocks)
                return
            }
            let markdown = MarkdownComponent(blocks: blocks)
            markdown.onToggleTask = { [weak self] line in self?.send(command: "toggle-task", args: ["line": line]) }
            setComponent(markdown)
        case .pdf(let path):
            // A plugin may only point the host at the file it was asked to open.
            guard URL(filePath: path).standardizedFileURL == url.standardizedFileURL else { throw CocoaError(.fileReadNoPermission) }
            setComponent(try PDFComponent(url: url))
        case .bitmap(let bitmap):
            setComponent(try BitmapComponent(bitmap: bitmap))
        case .text(let shared):
            let text = try SharedFile.withMapped(shared.file) { String(decoding: $0, as: UTF8.self) }
            let editable = allowsEditing && shared.editable
            let current = component as? TextComponent
            // A new view only when a reload crosses a size limit (editability or the note bar comes or goes);
            // a growing log's note just changes its size.
            if let current, current.isEditable == editable, (current.note == nil) == (shared.note == nil) {
                current.update(text: text)
                if let note = shared.note { current.setNote(note) }
                return
            }
            let replacement = TextComponent(text: text, editable: editable, note: shared.note)
            setComponent(replacement)
            if let current { replacement.takeViewState(from: current) }
        }
    }

    private func setComponent(_ new: Component) {
        component = new
        new.onEdit = { [weak self] in self?.didEdit() }
        content.show(new.view)
        if let focus = new.focusView { view.window?.makeFirstResponder(focus) }
    }

    private func installSidebar(_ panels: [Panel]) {
        pendingSidebar = nil
        if let sidebarItem { removeSplitViewItem(sidebarItem) }
        sidebarItem = nil
        let onAnchor: (Int) -> Void = { [weak self] line in (self?.component as? MarkdownComponent)?.scroll(toLine: line) }
        guard let view = Sidebar.make(panels, component: component, onAnchor: onAnchor) else { return }
        let holder = HolderViewController()
        holder.loadViewIfNeeded()
        holder.show(view)
        let item = NSSplitViewItem(sidebarWithViewController: holder)
        item.minimumThickness = 170
        item.maximumThickness = 320
        insertSplitViewItem(item, at: 0)
        sidebarItem = item
    }

    /// Same rule for every plugin: ready once the window has drawn the content and the run loop has turned.
    /// The sidebar follows a frame later: inserting it cost about 6 ms before the first paint of a small file.
    private func markReady() {
        guard !isReady else { return }
        isReady = true
        view.window?.displayIfNeeded()
        DispatchQueue.main.async {
            self.onReady?(self, .now - self.opened, self.pluginWasRunning)
            self.startWatching()  // after the timing: watching isn't part of showing the file
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.016) { [weak self] in
            guard let self, !isClosed, let panels = pendingSidebar else { return }
            installSidebar(panels)
        }
    }

    private func startWatching() {
        guard watcher == nil, !isClosed else { return }
        watcher = FileWatcher(url: url) { [weak self] in self?.reloadIfChangedOnDisk() }
    }

    private func fail(_ message: String) {
        if isEdited, component != nil {
            // The edits stay on screen so they can still be saved; the plugin no longer knows this document.
            pluginNeedsReopen = true
            Self.log.error("\(self.entry.id, privacy: .public): \(self.url.lastPathComponent, privacy: .private): \(message, privacy: .private); keeping unsaved edits")
            return
        }
        component = nil
        pendingSidebar = nil
        let label = NSTextField(wrappingLabelWithString: message)
        label.alignment = .center
        label.textColor = .secondaryLabelColor
        let retry = NSButton(title: "Reopen", target: self, action: #selector(reopen))
        let stack = NSStackView(views: [label, retry])
        stack.orientation = .vertical
        stack.alignment = .centerX
        let container = NSView()
        container.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualTo: container.widthAnchor, constant: -40),
        ])
        content.show(container)
        if let sidebarItem { removeSplitViewItem(sidebarItem) }
        sidebarItem = nil
        onFailure?(self, message)
    }

    @objc private func reopen() {
        process.detach(docID)
        Task.immediate { await load() }
    }
}
