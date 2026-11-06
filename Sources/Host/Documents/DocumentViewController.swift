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

/// One open file, shown by one plugin. Used by both Editor windows and the Peek panel.
final class DocumentViewController: NSSplitViewController {
    /// The file shown; it changes only with Save As.
    private(set) var url: URL
    let entry: PluginEntry
    private var config: Config
    private let content = HolderViewController()
    private var sidebarItem: NSSplitViewItem?
    private var sidebarHolder: HolderViewController?
    /// Editor windows share whether the sidebar shows and its width; the Peek panel and the benchmark don't.
    private let sidebarMemory: SidebarMemory?
    /// The app's preferences, where the plugin keeps its settings; nil in tests and benchmarks.
    private let preferences: UserDefaults?
    /// A document just opened: its sidebar is built after the content is on screen, so it doesn't delay it.
    private var sidebarPending = false
    /// Editor windows edit; the Peek panel and the benchmark only view.
    private let allowsEditing: Bool
    /// The open in progress, cancelled when the document closes.
    private var openTask: Task<Void, Never>?
    /// What the plugin opened; nil while opening and after a failure.
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
    /// The plugin's tools, each with its shortcut after config overrides.
    private(set) var tools: [(spec: ToolSpec, shortcut: Shortcut?)] = []

    /// First content on screen, with the time since `load()`.
    var onReady: ((DocumentViewController, Duration) -> Void)?
    /// Called once the first content is on screen, after `onReady` (which the benchmark owns): the window adds its
    /// tool buttons then, so building them isn't part of opening.
    var onContentShown: ((DocumentViewController) -> Void)?
    /// Whether the first content has been on screen.
    private(set) var hasShownContent = false
    var onFailure: ((DocumentViewController, String) -> Void)?
    /// Called when the tools change, or whether there's a sidebar: the window rebuilds its toolbar.
    var onToolsChanged: ((DocumentViewController) -> Void)?
    /// Called when the document's active tool changes.
    var onActiveToolChanged: ((DocumentViewController) -> Void)?
    var onRecovery: ((DocumentViewController, RecoveryResult) -> Void)?
    /// An edit tool was run on a read-only document; the string says why.
    var onEditRefused: ((DocumentViewController, String) -> Void)?
    /// A document that follows links handed over a link to a local file.
    var onFollowLink: ((DocumentViewController, URL) -> Void)?

    /// `journalDelay` is how long after the last edit the recovery copy is written.
    init(url: URL, entry: PluginEntry, config: Config, allowsEditing: Bool, recovery: RecoveryStore?, recoveryID: String = UUID().uuidString,
         journalDelay: TimeInterval = 2, sidebarMemory: SidebarMemory? = nil, preferences: UserDefaults? = nil) {
        self.url = url
        self.entry = entry
        self.config = config
        self.allowsEditing = allowsEditing
        self.sidebarMemory = sidebarMemory
        self.preferences = preferences
        super.init(nibName: nil, bundle: nil)
        if let sidebarMemory {
            NotificationCenter.default.addObserver(self, selector: #selector(applySidebarMemory), name: SidebarMemory.didChange, object: sidebarMemory)
        }
        journal = recovery.map { RecoveryJournal(store: $0, id: recoveryID, url: url, pluginID: entry.id, delay: journalDelay) { [weak self] in self?.journalContents } }
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        addSplitViewItem(NSSplitViewItem(viewController: content))
        if sidebarMemory != nil {
            NotificationCenter.default.addObserver(self, selector: #selector(sidebarResized), name: NSSplitView.didResizeSubviewsNotification, object: splitView)
        }
    }

    /// How long an open runs before its window shows a spinner; quicker opens never draw one.
    private static let spinnerDelay: Duration = .milliseconds(500)

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
        let context = OpenContext(maxPixels: Self.maxPixels, allowsEditing: allowsEditing,
                                  preferences: preferences.map { PluginPreferences(pluginID: entry.id, defaults: $0) })
        // Read before the plugin reads the file, so a write in between shows as a change and reloads.
        let modified = Self.modificationDate(of: url)
        // A window with nothing to show yet gets a spinner once the open is slow; the Peek panel never does.
        let spinner = allowsEditing && pluginDocument == nil ? Task { [weak self] in
            try? await Task.sleep(for: Self.spinnerDelay)
            guard let self, !Task.isCancelled, !isClosed, pluginDocument == nil else { return }
            content.show(LoadingView())
        } : nil
        // The result is shown inside the task, in the same main-actor turn the plugin returns in. Awaiting the task
        // and showing afterwards would take one more turn, which can land after a display pass and delay first paint.
        let task = Task.immediate { [weak self] in
            let result: Result<any PluginDocument, PluginError>
            do throws(PluginError) {
                result = .success(try await plugin.open(url, context: context))
            } catch {
                result = .failure(error)
            }
            spinner?.cancel()
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

    /// Runs the tool, unless it's an edit tool and the document is read-only: then the reason goes to `onEditRefused`.
    func run(_ spec: ToolSpec) {
        if let reason = unavailableReason(for: spec) {
            if spec.isEditTool, case .readOnly = editability, let onEditRefused { onEditRefused(self, reason) } else { NSSound.beep() }
            return
        }
        if pluginDocument?.perform(spec.id) != true { NSSound.beep() }
    }

    /// Runs one of `spec`'s choices, refused the way the tool itself is.
    func run(_ choice: ToolSpec.Choice, of spec: ToolSpec) {
        if let reason = unavailableReason(for: spec) {
            if spec.isEditTool, case .readOnly = editability, let onEditRefused { onEditRefused(self, reason) } else { NSSound.beep() }
            return
        }
        if pluginDocument?.perform(choice.id) != true { NSSound.beep() }
    }

    var editability: Editability { pluginDocument?.editability ?? .notEditable }

    /// Why the tool can't run now, shown as its tooltip while it's greyed out: a read-only document's reason for every
    /// edit tool, else whatever the document says.
    func unavailableReason(for spec: ToolSpec) -> String? {
        if spec.isEditTool, case .readOnly(let reason) = editability { return reason }
        return pluginDocument?.unavailableReason(for: spec.id)
    }

    /// The tools with a toolbar button.
    var toolbarTools: [(spec: ToolSpec, shortcut: Shortcut?)] {
        tools.filter(\.spec.showsInToolbar)
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
        if !isClosed { installSidebar(document.makeSidebar()) }
        return .saved
    }

    /// Save As: writes the file with its unsaved edits (or as it is, without any) to `destination`, then follows it:
    /// file watching, the recovery record and the modification baseline move to the new file. On failure nothing moves.
    func saveAs(to destination: URL) async -> SaveOutcome {
        while let running = runningSave {
            _ = await running.value
            if runningSave == running { runningSave = nil }
        }
        // Counted as the running save, so a Save or a close that comes meanwhile waits for it.
        let task = Task.immediate { await performSaveAs(to: destination) }
        runningSave = task
        let outcome = await task.value
        if runningSave == task { runningSave = nil }
        return outcome
    }

    private func performSaveAs(to destination: URL) async -> SaveOutcome {
        guard let document = pluginDocument else { return .failed("The file isn't open.") }
        isSaving = true
        defer { isSaving = false }
        let edits = document.unsavedEdits(), editsAtSave = editCount
        do throws(PluginError) {
            try await document.saveAs(edits, to: destination)
        } catch {
            Self.log.error("\(self.entry.id, privacy: .public): Save As of \(self.url.lastPathComponent, privacy: .private) failed: \(error.message, privacy: .private)")
            return .failed(error.message)
        }
        url = destination
        watcher?.stop()
        watcher = nil
        startWatching()
        journal?.url = destination
        knownModification = Self.modificationDate(of: destination)
        isEdited = editCount != editsAtSave  // edits made while it wrote stay unsaved
        journal?.write()
        if !isClosed { installSidebar(document.makeSidebar()) }
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
        let accepted = document.restore(encoded: record.editsData)
        if document.unsavedEdits() != nil {
            let changedSince = knownModification != record.fileModified
            // Saving then asks before replacing a file that changed since the edits were made.
            knownModification = record.fileModified
            didEdit()
            onRecovery?(self, .restored(fileChangedSince: changedSince))
        } else if accepted {
            // Taken, yet nothing differs: the recovered edits match the file.
            isEdited = false
            journal?.write()
        } else {
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
            installSidebar(document.makeSidebar())
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
        document.onEdit = { [weak self] in self?.didEdit() }
        document.onReplace = { [weak self] replacement in self?.show(replacement) }
        document.onSidebarChange = { [weak self, weak document] in
            guard let self, let document, !isClosed, pluginDocument === document, !sidebarPending else { return }
            installSidebar(document.makeSidebar())
        }
        document.onActiveToolChange = { [weak self] in self.map { $0.onActiveToolChanged?($0) } }
        (document as? any LinkFollowing)?.onFollowLink = { [weak self] link in self.map { $0.onFollowLink?($0, link) } }
        // The note is the Editor's; the Peek panel only views, so it has nothing to explain.
        if allowsEditing, case .readOnly(let reason) = document.editability {
            content.show(ReadOnlyNote(reason: reason, content: document.contentView))
        } else {
            content.show(document.contentView)
        }
        if let focus = document.focusView { view.window?.makeFirstResponder(focus) }
        let hadSidebar = hasSidebar
        firstOpenPending = false
        if isReady { installSidebar(document.makeSidebar(), notify: false) } else { sidebarPending = true }
        // The toolbar shows the sidebar button only with a sidebar.
        if !setTools(document.tools), hadSidebar != hasSidebar { onToolsChanged?(self) }
        markReady()
        applyRecoveredEdits()
    }

    /// Until the first open ends, a sidebar is assumed, so the window's first toolbar already has the sidebar button and
    /// isn't rebuilt on the way to the first paint.
    private var firstOpenPending = true

    /// Whether the document shows a sidebar, or will a frame after its content.
    var hasSidebar: Bool { sidebarItem != nil || sidebarPending || firstOpenPending }

    /// True when the tools changed, and the window was told.
    @discardableResult private func setTools(_ specs: [ToolSpec]) -> Bool {
        guard specs != tools.map(\.spec) else { return false }
        tools = specs.map(withShortcut)
        onToolsChanged?(self)
        return true
    }

    /// Takes a newly saved config: tool shortcuts change in place.
    func apply(_ config: Config) {
        self.config = config
        tools = tools.map { withShortcut($0.spec) }
        onToolsChanged?(self)
    }

    /// The tool with its shortcut: the config's override, else the plugin's default.
    private func withShortcut(_ spec: ToolSpec) -> (spec: ToolSpec, shortcut: Shortcut?) {
        (spec, config.shortcut(for: spec, of: entry.id))
    }

    /// Shows `panels` in the sidebar. After a save or reload the existing sidebar takes the new panels, so whether
    /// it's hidden and its width stay as they were.
    private func installSidebar(_ panels: [SidebarPanel], notify: Bool = true) {
        let hadSidebar = hasSidebar
        sidebarPending = false
        // A sidebar that comes or goes changes the toolbar's sidebar button.
        defer { if notify, hadSidebar != hasSidebar { onToolsChanged?(self) } }
        guard let view = Sidebar.make(panels) else { return removeSidebar() }
        if let sidebarHolder { return sidebarHolder.show(view) }
        let holder = HolderViewController()
        holder.loadViewIfNeeded()
        holder.show(view)
        if let width = sidebarMemory?.width { holder.view.frame.size.width = width }
        let item = NSSplitViewItem(sidebarWithViewController: holder)
        item.minimumThickness = 170
        item.maximumThickness = 320
        item.isCollapsed = sidebarMemory?.isHidden ?? false
        insertSplitViewItem(item, at: 0)
        sidebarItem = item
        sidebarHolder = holder
    }

    private func removeSidebar() {
        if let sidebarItem { removeSplitViewItem(sidebarItem) }
        sidebarItem = nil
        sidebarHolder = nil
    }

    /// The user hid, showed or resized the sidebar here (or the memory's own change arrived, which changes nothing).
    @objc private func sidebarResized() {
        guard let item = sidebarItem, let memory = sidebarMemory else { return }
        let width = item.viewController.view.frame.width
        memory.remember(hidden: item.isCollapsed, width: item.isCollapsed || width < item.minimumThickness ? nil : width)
    }

    /// Another window changed the choice: follow it.
    @objc private func applySidebarMemory() {
        guard let item = sidebarItem, let memory = sidebarMemory else { return }
        if item.isCollapsed != memory.isHidden { item.isCollapsed = memory.isHidden }
        if !memory.isHidden, let width = memory.width, abs(item.viewController.view.frame.width - width) >= 1 {
            splitView.setPosition(width, ofDividerAt: 0)
        }
    }

    /// Show/Hide Sidebar only where there's a sidebar.
    override func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(toggleSidebar(_:)), sidebarItem == nil { return false }
        return super.validateUserInterfaceItem(item)
    }

    /// Same rule for every plugin: ready once the window has drawn the content and the run loop has turned.
    /// The sidebar follows a frame later: inserting it cost about 6 ms before the first paint of a small file.
    private func markReady() {
        guard !isReady else { return }
        isReady = true
        view.window?.displayIfNeeded()
        DispatchQueue.main.async {
            self.onReady?(self, .now - self.opened)
            self.hasShownContent = true
            self.onContentShown?(self)
            self.startWatching()  // after the timing: watching isn't part of showing the file
            self.reloadIfChangedOnDisk()  // a change made before the watcher started
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.016) { [weak self] in
            guard let self, !isClosed, sidebarPending, let document = pluginDocument else { return }
            installSidebar(document.makeSidebar())
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
        let hadSidebar = hasSidebar
        firstOpenPending = false
        sidebarPending = false
        removeSidebar()
        if !setTools([]), hadSidebar { onToolsChanged?(self) }  // the failure view has nothing to run, and no sidebar
        content.show(FailureView(message: message) { [weak self] in
            guard let self else { return }
            Task.immediate { await self.load() }
        })
        onFailure?(self, message)
    }
}
