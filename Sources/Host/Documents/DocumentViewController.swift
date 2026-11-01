import AppKit
import os
import PeekerKit

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
    private var config: Config
    private let content = HolderViewController()
    private var sidebarItem: NSSplitViewItem?
    /// A document just opened: its sidebar is built after the content is on screen, so it doesn't delay it.
    private var sidebarPending = false
    /// Document windows edit; the quick-look panel and the benchmark only view.
    private let allowsEditing: Bool
    /// The open in progress, cancelled when the document closes.
    private var openTask: Task<Void, Never>?
    /// What the plugin opened; nil while opening and after a failure. Readable so tests can drive edits.
    private(set) var pluginDocument: (any PluginDocument)?
    private(set) var isEdited = false {
        didSet {
            guard isEdited != oldValue else { return }
            view.window?.isDocumentEdited = isEdited
        }
    }
    private(set) var isSaving = false
    /// The save in progress; a second save waits for it instead of writing at the same time.
    private var runningSave: Task<SaveOutcome, Never>?
    /// Counts edits, so a save can tell whether the user typed while it was in flight.
    private var editCount = 0
    /// The file's modification date when it was last loaded or saved here (for recovered edits, when they were made).
    /// A different date means someone else wrote it.
    private(set) var knownModification: Date?
    private var watcher: FileWatcher?
    /// A reload is running; `reloadAgain` notes a change that arrived meanwhile, checked once it ends.
    private var isReloading = false
    private var reloadAgain = false
    /// Keeps the unsaved edits for crash recovery; nil for view-only documents, and once recovered edits were refused.
    private var journal: RecoveryJournal?
    /// Recovered edits waiting for content: the open is still running, or it failed and a Reopen may succeed.
    private var unappliedRecord: RecoveryRecord?
    private var opened = ContinuousClock.now
    private var isReady = false
    private var isClosed = false
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "dev.peeker", category: "documents")
    /// Time from `load()` until the plugin finished opening, before anything was drawn.
    private(set) var openDuration: Duration = .zero
    /// The plugin's commands, each with its shortcut after config overrides.
    private(set) var commands: [(spec: CommandSpec, shortcut: Shortcut?)] = []
    /// For a document with an edit mode: whether it's on. Documents open in their read view.
    private(set) var isEditing = false

    /// First content on screen, with the time since `load()`.
    var onReady: ((DocumentViewController, Duration) -> Void)?
    var onFailure: ((DocumentViewController, String) -> Void)?
    var onCommandsChanged: ((DocumentViewController) -> Void)?
    /// Called when the document's active command changes.
    var onActiveCommandChanged: ((DocumentViewController) -> Void)?
    var onRecovery: ((DocumentViewController, RecoveryResult) -> Void)?
    /// Edit mode was asked for but the document can't be edited; the string says why.
    var onEditRefused: ((DocumentViewController, String) -> Void)?

    /// `journalDelay` is how long after the last edit the recovery copy is written.
    init(url: URL, entry: PluginEntry, config: Config, allowsEditing: Bool, recovery: RecoveryStore?, recoveryID: String = UUID().uuidString,
         journalDelay: TimeInterval = 2) {
        self.url = url
        self.entry = entry
        self.config = config
        self.allowsEditing = allowsEditing
        super.init(nibName: nil, bundle: nil)
        journal = recovery.map { RecoveryJournal(store: $0, id: recoveryID, url: url, pluginID: entry.id, delay: journalDelay) { [weak self] in self?.journalContents } }
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

    /// Opens the file with the plugin. Returns once the content or the failure view is showing; a document closed
    /// meanwhile gets nothing.
    func load() async {
        opened = .now
        openTask?.cancel()
        let plugin = entry.plugin, url = url
        let context = OpenContext(maxPixels: Self.maxPixels, allowsEditing: allowsEditing)
        // Read before the plugin reads the file, so a write in between shows as a change and reloads.
        let modified = Self.modificationDate(of: url)
        // The result is shown inside the task, in the same main-actor turn the plugin returns in. Awaiting the task
        // and showing afterwards would take one more turn, which can land after a display pass and delay first paint.
        let task = Task.immediate { [weak self] in
            let result: Result<any PluginDocument, PluginError>
            do throws(PluginError) {
                result = .success(try await plugin.open(url, context: context))
            } catch {
                result = .failure(error)
            }
            guard let self, !isClosed, !Task.isCancelled else { return }
            openTask = nil
            openDuration = .now - opened
            switch result {
            case .success(let document):
                // Opened again after a change on disk: edits made meanwhile win, as in `reload`, and the known date
                // stays old, so saving still asks.
                guard !isEdited || pluginDocument == nil else { return }
                knownModification = modified
                isReady = false
                show(document)
            case .failure(let error):
                fail(error.message)
            }
        }
        openTask = task
        await task.value
    }

    func run(_ spec: CommandSpec) {
        if spec.isEditTool, !isEditing {
            switch editMode {
            case .none: break
            case .available: setEditing(true)
            case .unavailable(let reason): return refuseEditing(reason)
            }
        }
        if pluginDocument?.perform(spec.id) != true { NSSound.beep() }
    }

    var editMode: EditMode { pluginDocument?.editMode ?? .none }

    /// The commands the toolbar shows: edit tools only while Edit mode is on, or when there's no edit mode.
    var toolbarCommands: [(spec: CommandSpec, shortcut: Shortcut?)] {
        commands.filter { !$0.spec.isEditTool || isEditing || editMode == .none }
    }

    /// The Edit button and Cmd+E. Leaving calls `resolve`, which asks about unsaved edits and saves or drops them;
    /// it returns false to stay in Edit mode.
    func toggleEditing(resolve: () async -> Bool) async {
        switch editMode {
        case .none: return
        case .unavailable(let reason): refuseEditing(reason)
        case .available:
            if !isEditing {
                setEditing(true)
            } else if await resolve(), !isClosed {
                setEditing(false)
            }
        }
    }

    private func setEditing(_ on: Bool) {
        guard on != isEditing, editMode == .available, let document = pluginDocument else { return }
        isEditing = on
        document.setEditing(on)
        onCommandsChanged?(self)
    }

    private func refuseEditing(_ reason: String) {
        if let onEditRefused { onEditRefused(self, reason) } else { NSSound.beep() }
    }

    /// Without edits the recovery record goes; with edits (closed without the prompt) or recovered edits still waiting
    /// to be applied, it's kept so nothing is lost.
    func close() {
        if unappliedRecord == nil { journal?.write() }
        isClosed = true
        watcher?.stop()
        watcher = nil
        openTask?.cancel()
        openTask = nil
    }

    /// Has the plugin write the pending edits. On anything but `.saved` the edits stay pending. While a save is
    /// running, a second one waits for it and then saves whatever changed since.
    func save(prompts: any SavePrompts) async -> SaveOutcome {
        while let running = runningSave {
            let outcome = await running.value
            if runningSave == running { runningSave = nil }
            guard outcome == .saved else { return outcome }
        }
        // Immediate, so the edits are captured now: anything typed after this call stays pending.
        let task = Task.immediate { await performSave(prompts: prompts) }
        runningSave = task
        let outcome = await task.value
        if runningSave == task { runningSave = nil }
        return outcome
    }

    private func performSave(prompts: any SavePrompts) async -> SaveOutcome {
        guard let document = pluginDocument, let edits = document.unsavedEdits() else {
            // Edited, then changed back: nothing differs from what was loaded.
            isEdited = false
            journal?.write()
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
        do throws(PluginError) {
            do {
                try await document.save(edits, accepting: nil)
            } catch let error where error.offer != nil {
                guard let offer = error.offer, await prompts.confirm(offer, reason: error.message) else { return .cancelled }
                try await document.save(edits, accepting: offer)
            }
        } catch {
            Self.log.error("\(self.entry.id, privacy: .public): saving \(self.url.lastPathComponent, privacy: .private) failed: \(error.message, privacy: .private)")
            return .failed(error.message)
        }
        knownModification = Self.modificationDate(of: url)
        isEdited = editCount != editsAtSave
        journal?.write()  // removes the record, or keeps only edits made during the save
        if !isClosed { installSidebar(document.sidebar) }
        return .saved
    }

    /// "Don't Save": goes back to the file as last loaded or saved.
    func discardEdits() {
        pluginDocument?.revertEdits()
        isEdited = false
        journal?.write()
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
        guard let record = unappliedRecord, let document = pluginDocument, !isClosed else { return }
        unappliedRecord = nil
        let wasEditing = isEditing
        setEditing(true)  // recovered edits come back in Edit mode
        let accepted = document.restore(encoded: record.editsData)
        if document.unsavedEdits() != nil {
            let changedSince = knownModification != record.fileModified
            // Saving then asks before replacing a file that changed since the edits were made.
            knownModification = record.fileModified
            didEdit()
            onRecovery?(self, .restored(fileChangedSince: changedSince))
        } else if accepted {
            // Taken, yet nothing differs: the recovered edits match the file.
            if !wasEditing { setEditing(false) }
            isEdited = false
            journal?.write()
        } else {
            if !wasEditing { setEditing(false) }
            journal = nil
            onRecovery?(self, .rejected(record))
        }
    }

    /// What the journal keeps: nothing without edits.
    private var journalContents: RecoveryJournal.Contents? {
        guard isEdited, let edits = pluginDocument?.unsavedEdits() else { return nil }
        return RecoveryJournal.Contents(edits: edits, fileModified: knownModification)
    }

    private func didEdit() {
        editCount += 1
        isEdited = true
        journal?.schedule()
    }

    /// Reloads when someone else changed the file. Never while there are unsaved edits: saving asks about it instead.
    /// Internal so tests can start a reload at a chosen moment.
    func reloadIfChangedOnDisk() {
        guard !isEdited, !isSaving, !isClosed, isReady else { return }
        // One at a time: an older read finishing last would show older text.
        guard !isReloading else {
            reloadAgain = true
            return
        }
        let modified = Self.modificationDate(of: url)
        guard modified != knownModification else { return }
        isReloading = true
        Task.immediate {
            await reload(modified: modified)
            isReloading = false
            if reloadAgain {
                reloadAgain = false
                reloadIfChangedOnDisk()
            }
        }
    }

    /// Has the document re-read its file in place, or opens the file again when it can't.
    private func reload(modified: Date?) async {
        guard let document = pluginDocument else { return await load() }
        do throws(PluginError) {
            let reloaded = try await document.reload()
            // Edits made while the reload ran win; the known date stays old, so saving still asks.
            guard !isClosed, pluginDocument === document, !isEdited else { return }
            guard reloaded else { return await load() }
            knownModification = modified
            installSidebar(document.sidebar)
        } catch {
            guard !isClosed, pluginDocument === document else { return }
            fail(error.message)
        }
    }

    /// Follows symlinks, as the plugin does when it saves. Nil when the file is gone.
    private static func modificationDate(of url: URL) -> Date? {
        var info = stat()
        guard stat(url.path, &info) == 0 else { return nil }
        let time = info.st_mtimespec
        return Date(timeIntervalSince1970: TimeInterval(time.tv_sec) + TimeInterval(time.tv_nsec) / 1_000_000_000)
    }

    private func show(_ document: any PluginDocument) {
        pluginDocument = document
        let wasEditing = isEditing
        isEditing = false
        document.onEdit = { [weak self] in self?.didEdit() }
        document.onReplace = { [weak self] replacement in self?.show(replacement) }
        document.onActiveCommandChange = { [weak self] in self.map { $0.onActiveCommandChanged?($0) } }
        content.show(document.contentView)
        if let focus = document.focusView { view.window?.makeFirstResponder(focus) }
        if isReady { installSidebar(document.sidebar) } else { sidebarPending = true }
        setCommands(document.commands)
        if wasEditing { onCommandsChanged?(self) }  // the toolbar drops the tools even when the commands are the same
        markReady()
        applyRecoveredEdits()
    }

    private func setCommands(_ specs: [CommandSpec]) {
        guard specs != commands.map(\.spec) else { return }
        commands = specs.map(withShortcut)
        onCommandsChanged?(self)
    }

    /// Takes a newly saved config: command shortcuts change in place.
    func apply(_ config: Config) {
        self.config = config
        commands = commands.map { withShortcut($0.spec) }
        onCommandsChanged?(self)
    }

    /// The command with its shortcut: the config's override, else the plugin's default.
    private func withShortcut(_ spec: CommandSpec) -> (spec: CommandSpec, shortcut: Shortcut?) {
        (spec, config.shortcut(for: spec, of: entry.id))
    }

    private func installSidebar(_ panels: [SidebarPanel]) {
        sidebarPending = false
        if let sidebarItem { removeSplitViewItem(sidebarItem) }
        sidebarItem = nil
        guard let view = Sidebar.make(panels) else { return }
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
            self.onReady?(self, .now - self.opened)
            self.startWatching()  // after the timing: watching isn't part of showing the file
            self.reloadIfChangedOnDisk()  // a change made before the watcher started
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.016) { [weak self] in
            guard let self, !isClosed, sidebarPending, let document = pluginDocument else { return }
            installSidebar(document.sidebar)
        }
    }

    private func startWatching() {
        guard watcher == nil, !isClosed else { return }
        watcher = FileWatcher(url: url) { [weak self] in self?.reloadIfChangedOnDisk() }
    }

    private func fail(_ message: String) {
        if isEdited, pluginDocument != nil {
            // A reload failed, but the edits on screen can still be saved.
            Self.log.error("\(self.entry.id, privacy: .public): \(self.url.lastPathComponent, privacy: .private): \(message, privacy: .private); keeping unsaved edits")
            return
        }
        pluginDocument = nil
        sidebarPending = false
        isEditing = false
        setCommands([])  // the failure view has nothing to run
        content.show(FailureView(message: message) { [weak self] in
            guard let self else { return }
            Task.immediate { await self.load() }
        })
        if let sidebarItem { removeSplitViewItem(sidebarItem) }
        sidebarItem = nil
        onFailure?(self, message)
    }
}
