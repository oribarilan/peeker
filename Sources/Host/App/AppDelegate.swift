import AppKit
import os

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "dev.peeker", category: "config")
    /// The settings in use, re-read whenever the file is saved.
    private lazy var configStore: ConfigStore = {
        let store = ConfigStore(plugins: PluginCatalog.builtIn.map { PluginEntry($0) })
        store.onChange = { [weak self] in self?.configChanged($0) }
        Self.logProblems(store.problems)
        return store
    }()
    private var config: Config { configStore.config }

    private lazy var catalog = PluginCatalog.builtIn(config: config)
    private var windows: [DocumentWindowController] = []
    private lazy var panel: QuickLookPanel = {
        let panel = QuickLookPanel()
        panel.onOpenInWindow = { [weak self] url in self?.openInWindow(url) }
        return panel
    }()
    private lazy var finder = FinderBridge()
    private var hotkey: HotkeyMonitor?
    /// The key the hotkey monitor was started with; nil when it's off.
    private var hotkeyShortcut: Shortcut?
    private let accessibility = AccessibilityStatus()
    private var askedForTrust = false
    private var commandsMenu: NSMenu?
    private var benchRunner: BenchRunner?
    private var settings: SettingsWindowController?
    private var menuBarItem: MenuBarItem?
    private var benchStarted = false
    /// Sparkle starts only on the turn after launch, so it never delays the first window.
    private(set) lazy var updater: Updater = {
        let updater = Updater()
        updater.apply(config)
        return updater
    }()
    private var recoveryRestored = false
    /// One for the whole app, so recovered texts that land on the clipboard during a launch don't replace each other.
    private lazy var recoveryClipboard = RecoveryClipboard(pasteboard: .general, store: .shared) { [weak self] in self?.catalog.recoveryText($0) }

    /// Whether macOS launched Peeker as a login item, from the launch's Apple event (only current until launching ends).
    private var launchedAtLogin = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        let launch = NSAppleEventManager.shared().currentAppleEvent
        launchedAtLogin = launch?.eventID == kAEOpenApplication
            && launch?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        let menu = MainMenu.make(target: self)
        commandsMenu = menu.item(withTitle: "Commands")?.submenu
        NSApp.mainMenu = menu
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        if item.action == #selector(toggleOpenAtLogin(_:)) { item.state = LoginItem.isEnabled ? .on : LoginItem.needsApproval ? .mixed : .off }
        if item.action == #selector(checkForUpdates(_:)) { return updater.canCheck }
        return true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let files = CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("-") && FileManager.default.fileExists(atPath: $0) }.map { URL(filePath: $0) }
        if let bench = Bench.current {
            // Launched from a terminal the file is an argument; through LaunchServices it arrives in application(_:open:).
            if let file = files.first, !benchStarted {
                benchStarted = true
                startBench(bench, url: file)
            }
            return
        }
        menuBarItem = MenuBarItem(target: self)
        accessibility.onChange = { [weak self] in self?.accessibilityChanged() }
        restoreRecoveredDocuments()
        files.forEach(openInWindow)
        startHotkey()
        if Self.showsSettingsAtLaunch(openedWindows: windows.count, atLogin: launchedAtLogin) { showSettings(nil) }
        DispatchQueue.main.async { [weak self] in self?.updater.start() }
        do {
            try ConfigSchema.write(nextTo: Config.defaultURL, plugins: catalog.entries)
        } catch {
            Self.log.error("can't write the config schema: \(error.localizedDescription, privacy: .public)")
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        if let bench = Bench.current {
            guard let url = urls.first, !benchStarted else { return }
            benchStarted = true
            startBench(bench, url: url)
            return
        }
        // Files opened at launch arrive before applicationDidFinishLaunching; a recovered window for one must come first.
        restoreRecoveredDocuments()
        urls.forEach(openInWindow)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// Opening Peeker by hand with nothing to show brings up Settings, so it doesn't look as if it didn't start. A launch
    /// at login stays quiet.
    static func showsSettingsAtLaunch(openedWindows: Int, atLogin: Bool) -> Bool {
        openedWindows == 0 && !atLogin
    }

    /// Opening Peeker again while it runs with no window showing (from the Dock, Launchpad or Spotlight) shows Settings.
    static func showsSettingsOnReopen(hasVisibleWindows: Bool) -> Bool { !hasVisibleWindows }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if Self.showsSettingsOnReopen(hasVisibleWindows: flag) { showSettings(nil) }
        return true
    }

    /// Asks about each window with unsaved edits in turn, bringing it to the front; the first Cancel stops the quit.
    /// A window is closed as soon as it's resolved, so a cancelled quit leaves no window whose edits were discarded.
    /// The list is checked again after each answer, so edits typed in another window meanwhile are asked about too.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard windows.contains(where: { $0.current?.isEdited == true }) else { return .terminateNow }
        Task {
            var resolved: Set<ObjectIdentifier> = []
            while let controller = windows.first(where: { $0.current?.isEdited == true && !resolved.contains(ObjectIdentifier($0)) }) {
                controller.window?.makeKeyAndOrderFront(nil)
                guard await controller.resolveUnsavedEdits() else {
                    sender.reply(toApplicationShouldTerminate: false)
                    return
                }
                resolved.insert(ObjectIdentifier(controller))
                controller.window?.close()
            }
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    // MARK: Quick look

    private func startHotkey() {
        hotkeyShortcut = config.quickLookKey
        accessibility.watch(config.quickLookKey != nil)
        updateMenuBar()
        guard let shortcut = config.quickLookKey else { return }
        let monitor = HotkeyMonitor(shortcut: shortcut)
        monitor.isPanelVisible = { [weak self] in self?.panel.isVisible == true }
        monitor.onTrigger = { [weak self] in self?.quickLookFinderSelection() }
        monitor.onDismiss = { [weak self] in self?.panel.dismiss() }
        monitor.onSelectionMayHaveChanged = { [weak self] in self?.followFinderSelection() }
        hotkey = monitor
        // Until Accessibility is granted the tap can't be created: ask once per launch, and start it when the
        // permission shows up (accessibilityChanged).
        if !monitor.start(), !askedForTrust {
            askedForTrust = true
            HotkeyMonitor.requestTrust()
        }
    }

    private func accessibilityChanged() {
        if accessibility.isTrusted { hotkey?.start() }
        updateMenuBar()
    }

    private func updateMenuBar() {
        menuBarItem?.show(MenuBarItem.State(problems: configStore.problems.count, needsAccessibility: accessibility.isMissing))
    }

    /// Applies a saved config everywhere: routing for files opened next, the quick-look key, and command shortcuts in
    /// open windows.
    private func configChanged(_ store: ConfigStore) {
        Self.logProblems(store.problems)
        updateMenuBar()
        catalog.reload(config: store.config)
        updater.apply(store.config)
        windows.forEach { $0.apply(store.config) }
        guard store.config.quickLookKey != hotkeyShortcut else { return }
        hotkey?.stop()
        hotkey = nil
        startHotkey()
    }

    private static func logProblems(_ problems: [ConfigProblem]) {
        for problem in problems { log.error("config: \(problem.path, privacy: .public): \(problem.message, privacy: .public)") }
    }

    private func updatePresence() {
        Presence.update(documentWindows: windows.count, settingsOpen: settings != nil)
    }

    @objc func checkForUpdates(_ sender: Any?) { updater.checkNow() }
    @objc func showSettings(_ sender: Any?) { showSettings(pane: nil) }
    @objc func showConfigFileSettings(_ sender: Any?) { showSettings(pane: .configFile) }
    @objc func showPermissionsSettings(_ sender: Any?) { showSettings(pane: .permissions) }

    /// Opens Settings, or brings it forward, on `pane` (or where it was).
    private func showSettings(pane: SettingsPane?) {
        let controller = settings ?? makeSettings()
        if let pane { controller.select(pane) }
        settings = controller
        updatePresence()
        controller.showWindow(nil)
        NSApp.activate()
    }

    private func makeSettings() -> SettingsWindowController {
        let model = SettingsModel(store: configStore, accessibility: accessibility, updater: updater)
        // While a recorder listens, the current quick-look key must reach it rather than open the panel.
        model.onRecordingChange = { [weak self] recording in
            if recording { self?.hotkey?.stop() } else { self?.hotkey?.start() }
        }
        let controller = SettingsWindowController(model: model)
        controller.onClose = { [weak self] in
            self?.settings = nil
            self?.updatePresence()
        }
        return controller
    }

    @objc func toggleOpenAtLogin(_ sender: Any?) { LoginItem.toggleReportingErrors() }

    private func quickLookFinderSelection() {
        guard let url = finder.selection().first, let entry = catalog.owner(for: url) else {
            hotkey?.passKeyToFinder()
            return
        }
        showInPanel(url, entry: entry)
    }

    private func followFinderSelection() {
        guard panel.isVisible, let url = finder.selection().first, url != panel.url else { return }
        guard let entry = catalog.owner(for: url) else {
            panel.dismiss()
            return
        }
        showInPanel(url, entry: entry)
    }

    private func showInPanel(_ url: URL, entry: PluginEntry) {
        let document = DocumentViewController(url: url, entry: entry, config: config, allowsEditing: false, recovery: nil)
        panel.show(document)
    }

    // MARK: Windows

    func openInWindow(_ url: URL) {
        openInWindow(url, restoring: nil)
    }

    /// With a record, opens it with the record's plugin if that's still enabled and applies its edits.
    private func openInWindow(_ url: URL, restoring record: RecoveryRecord?) {
        if let existing = windows.first(where: { $0.url == url }) {
            existing.window?.makeKeyAndOrderFront(nil)
            return
        }
        guard let entry = plugin(for: url, restoring: record) else {
            NSApp.activate()  // with no windows open, Peeker isn't the frontmost app
            let alert = NSAlert()
            alert.messageText = "No enabled plugin opens \(url.lastPathComponent)"
            alert.informativeText = "Add its extension to a plugin's extensions in your config, or turn on the plugin that has it."
            alert.runModal()
            return
        }
        let controller = DocumentWindowController(url: url, catalog: catalog, config: config, recovery: .shared, recoveryClipboard: recoveryClipboard)
        controller.onBecameKey = { [weak self] in if let menu = self?.commandsMenu { MainMenu.rebuildCommands(menu, for: $0) } }
        controller.onClose = { [weak self] closed in
            self?.windows.removeAll { $0 === closed }
            self?.updatePresence()
        }
        windows.append(controller)
        updatePresence()  // before the window shows, so the menus are there with it
        if let window = controller.window, let current = NSApp.keyWindow, current.tabbingIdentifier == window.tabbingIdentifier {
            current.addTabbedWindow(window, ordered: .above)
            window.makeKeyAndOrderFront(nil)
        } else {
            controller.showWindow(nil)
        }
        controller.show(with: entry, restoring: record)
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
    }

    /// The record's plugin if it's still enabled (Open With may have picked any), else the file's owner.
    private func plugin(for url: URL, restoring record: RecoveryRecord?) -> PluginEntry? {
        let recordedPlugin = record.flatMap { record in catalog.enabled.first { $0.id == record.pluginID } }
        return recordedPlugin ?? catalog.owner(for: url)
    }

    // MARK: Crash recovery

    /// Reopens each document that had unsaved edits when the app last stopped without quitting, once per launch.
    private func restoreRecoveredDocuments() {
        guard !recoveryRestored else { return }
        recoveryRestored = true
        RecoveryRestore(store: .shared, clipboard: recoveryClipboard,
                        canOpen: { [self] in plugin(for: $0.url, restoring: $0) != nil },
                        hasText: { [self] in catalog.recoveryText($0) != nil },
                        open: { [self] in openInWindow($0.url, restoring: $0) }).run()
    }

    private func startBench(_ bench: Bench, url: URL) {
        let runner = BenchRunner(bench: bench, catalog: catalog, config: config, panel: panel)
        benchRunner = runner
        runner.start(url: url)
    }

    @objc func showOpenPanel(_ sender: Any?) {
        let open = NSOpenPanel()
        open.allowsMultipleSelection = true
        guard open.runModal() == .OK else { return }
        open.urls.forEach(openInWindow)
    }
}
