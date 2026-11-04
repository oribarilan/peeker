import AppKit
import os
import PeekerKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "dev.peeker", category: "config")
    private let entries = PluginCatalog.builtIn.map { PluginEntry($0) }
    /// The settings in use, re-read whenever the file is saved.
    private lazy var configStore: ConfigStore = {
        let store = ConfigStore(plugins: entries)
        store.onChange = { [weak self] in self?.configChanged($0) }
        Self.logProblems(store.problems)
        return store
    }()
    private var config: Config { configStore.config }

    private lazy var catalog = PluginCatalog(entries: entries, config: config)
    private var windows: [DocumentWindowController] = []
    private lazy var panel: PeekPanel = {
        let panel = PeekPanel()
        panel.onOpenInWindow = { [weak self] url, place in self?.openInWindow(url, place: place) }
        panel.owner = { [weak self] in self?.catalog.owner(for: $0)?.id }
        panel.onDismiss = { [weak self] in self?.updater.installIfIdle() }
        panelIsMade = true
        return panel
    }()
    private var panelIsMade = false
    private lazy var finder = FinderBridge()
    private var hotkey: HotkeyMonitor?
    /// The key the hotkey monitor was started with; nil when it's off.
    private var hotkeyShortcut: Shortcut?
    private let accessibility = AccessibilityStatus()
    private var askedForTrust = false
    /// The menus the front document's tools fill.
    private var viewMenu: NSMenu?
    private var toolsMenu: NSMenu?
    private var openWithMenu: NSMenu?
    private lazy var recentFiles = RecentFiles { [weak self] in self?.openInWindow($0) }
    static let helpURL = URL(string: "https://github.com/oribarilan/peeker")!
    private var benchRunner: BenchRunner?
    private var settings: SettingsWindowController?
    private var menuBarItem: MenuBarItem?
    private var benchStarted = false
    /// Sparkle starts only on the turn after launch, so it never delays the first window.
    private(set) lazy var updater: Updater = {
        let updater = Updater()
        updater.apply(config)
        updater.isIdle = { [weak self] in self?.isIdle ?? false }
        updater.onAutomaticDownloadsChosen = { [weak self] on in self?.saveAutomaticUpdates(on ? "download" : "check") }
        updater.onUpdateAvailable = { [weak self] version in
            self?.waitingUpdate = version
            self?.updateMenuBar()
        }
        return updater
    }()
    /// Nothing open that a relaunch would close: no Editor window, no Settings window, no Peek panel. Unsaved edits
    /// live in Editor windows, so there are none either.
    private var isIdle: Bool { windows.isEmpty && settings == nil && !(panelIsMade && panel.isVisible) }
    /// The version of an update a scheduled check found while Peeker wasn't active, until the user sees it.
    private var waitingUpdate: String?
    private var recoveryRestored = false
    /// One for the whole app, so recovered texts that land on the clipboard during a launch don't replace each other.
    private lazy var recoveryClipboard = RecoveryClipboard(pasteboard: .general, store: .shared) { [weak self] in self?.catalog.recoveryText($0) }

    /// Whether macOS launched Peeker as a login item, from the launch's Apple event (only current until launching ends).
    private var launchedAtLogin = false
    /// The "Updated to Peeker" window, kept so it stays open.
    private var whatsNew: WhatsNewWindowController?
    /// Releases to list in that window when the user next opens an Editor or Settings window.
    private var whatsNewForFirstWindow: [Changelog.Release]?

    func applicationWillFinishLaunching(_ notification: Notification) {
        config.applyLooks()  // before any window or the Peek panel draws
        let launch = NSAppleEventManager.shared().currentAppleEvent
        launchedAtLogin = launch?.eventID == kAEOpenApplication
            && launch?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        let menu = MainMenu.make(target: self)
        viewMenu = menu.item(withTitle: "View")?.submenu
        toolsMenu = menu.item(withTitle: "Tools")?.submenu
        openWithMenu = menu.item(withTitle: "File")?.submenu?.item(withTitle: "Open With")?.submenu
        menu.item(withTitle: "File")?.submenu?.item(withTitle: "Open Recent")?.submenu?.delegate = recentFiles
        NSApp.mainMenu = menu
        NSApp.windowsMenu = menu.item(withTitle: "Window")?.submenu
        NSApp.helpMenu = menu.item(withTitle: "Help")?.submenu
    }

    /// Fills View and Tools with the front document's tools, or leaves only their fixed items, and File > Open With
    /// with its plugins. Filled ahead of time, not as the menus open, so Accessibility sees them too.
    private func showCommands(of controller: DocumentWindowController?) {
        guard let viewMenu, let toolsMenu, let openWithMenu else { return }
        MainMenu.rebuildTools(view: viewMenu, tools: toolsMenu, for: controller)
        if let controller { controller.fillOpenWith(openWithMenu) } else { openWithMenu.removeAllItems() }
    }

    @objc func showHelp(_ sender: Any?) {
        NSWorkspace.shared.open(Self.helpURL)
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
        let marks = WhatsNew.takeMarks(from: .standard)
        let whatsNewNow = prepareWhatsNew(installedQuietly: marks.installedQuietly)
        restoreRecoveredDocuments()
        files.forEach(openInWindow)
        startHotkey()
        let afterUpdate = marks.relaunched || marks.installedQuietly
        if Self.showsSettingsAtLaunch(openedWindows: windows.count, atLogin: launchedAtLogin, afterUpdate: afterUpdate) { showSettings(nil) }
        if let whatsNewNow { showWhatsNew(whatsNewNow) }
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
    /// at login, or a relaunch to finish an update, stays quiet.
    static func showsSettingsAtLaunch(openedWindows: Int, atLogin: Bool, afterUpdate: Bool = false) -> Bool {
        openedWindows == 0 && !atLogin && !afterUpdate
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

    // MARK: Peek panel

    private func startHotkey() {
        hotkeyShortcut = config.peekPanelKey
        accessibility.watch(config.peekPanelKey != nil)
        updateMenuBar()
        guard let shortcut = config.peekPanelKey else { return }
        let monitor = HotkeyMonitor(shortcut: shortcut)
        monitor.isPanelVisible = { [weak self] in self?.panel.isVisible == true }
        monitor.onTrigger = { [weak self] in self?.peekFinderSelection() }
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
        menuBarItem?.show(MenuBarItem.State(problems: configStore.problems.count, needsAccessibility: accessibility.isMissing, update: waitingUpdate))
    }

    /// Applies a saved config everywhere: routing for files opened next, the Peek panel key, and tool shortcuts in
    /// open windows.
    private func configChanged(_ store: ConfigStore) {
        Self.logProblems(store.problems)
        updateMenuBar()
        catalog.reload(config: store.config)
        updater.apply(store.config)
        store.config.applyLooks()
        windows.forEach { $0.apply(store.config) }
        guard store.config.peekPanelKey != hotkeyShortcut else { return }
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

    /// Writes the update mode chosen in Sparkle's window to the config, as Settings would.
    private func saveAutomaticUpdates(_ mode: String) {
        do {
            try configStore.save { $0.automaticUpdates = mode }
        } catch {
            Self.log.error("can't save updates.automatic: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: What's new

    /// Decides whether this launch follows an update and records the version for the next one. Returns the releases
    /// to show at once, or keeps them for the first window.
    private func prepareWhatsNew(installedQuietly: Bool) -> [Changelog.Release]? {
        guard updater.updatesThisBuild else { return nil }
        let defaults = UserDefaults.standard
        let lastRun = defaults.string(forKey: WhatsNew.lastRunKey)
        defaults.set(updater.version, forKey: WhatsNew.lastRunKey)
        let timing = WhatsNew.timing(lastRun: lastRun, running: updater.version, enabled: config.showWhatsNew,
                                     installedQuietly: installedQuietly, atLogin: launchedAtLogin)
        guard timing != .never, let lastRun, let url = Bundle.main.url(forResource: "CHANGELOG", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let releases = Changelog.releases(in: text, after: lastRun, upTo: updater.version)
        guard !releases.isEmpty else { return nil }
        if timing == .withFirstWindow { whatsNewForFirstWindow = releases; return nil }
        return releases
    }

    private func showWhatsNew(_ releases: [Changelog.Release]) {
        let controller = WhatsNewWindowController(version: updater.version, releases: releases)
        whatsNew = controller
        controller.showWindow(nil)
        // After a relaunch macOS may not let Peeker become active, so the window comes forward either way.
        controller.window?.orderFrontRegardless()
        NSApp.activate()
    }

    /// Shows the what's-new window kept for the first window, once.
    private func showWhatsNewForFirstWindow() {
        guard let releases = whatsNewForFirstWindow else { return }
        whatsNewForFirstWindow = nil
        showWhatsNew(releases)
    }

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
        showWhatsNewForFirstWindow()
    }

    private func makeSettings() -> SettingsWindowController {
        let model = SettingsModel(store: configStore, accessibility: accessibility, updater: updater, defaults: .standard)
        // While a recorder listens, the current Peek panel key must reach it rather than open the panel.
        model.onRecordingChange = { [weak self] recording in
            if recording { self?.hotkey?.stop() } else { self?.hotkey?.start() }
        }
        let controller = SettingsWindowController(model: model)
        controller.onClose = { [weak self] in
            self?.settings = nil
            self?.updatePresence()
            self?.updater.installIfIdle()
        }
        return controller
    }

    @objc func toggleOpenAtLogin(_ sender: Any?) { LoginItem.toggleReportingErrors() }

    private func peekFinderSelection() {
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
        openInWindow(url, place: nil)
    }

    /// The Editor window showing `url`, seeing through symlinks. A tab's file changes as links are followed in it.
    static func window(showing url: URL, in windows: [DocumentWindowController]) -> DocumentWindowController? {
        windows.first { LinkRoute.sameFile($0.url, url) }
    }

    /// With a record, opens it with the record's plugin if that's still enabled and applies its edits. With a place,
    /// such as a heading a link named, goes there once the file shows.
    private func openInWindow(_ url: URL, restoring record: RecoveryRecord? = nil, place: String?) {
        if let existing = Self.window(showing: url, in: windows) {
            existing.window?.makeKeyAndOrderFront(nil)
            if let place { Task { await existing.jump(to: place) } }
            return
        }
        guard let entry = plugin(for: url, restoring: record) else {
            NSApp.activate()  // with no windows open, Peeker isn't the frontmost app
            let alert = NSAlert()
            alert.messageText = "No enabled plugin opens “\(url.lastPathComponent)”"
            alert.informativeText = "Add its extension to a plugin in Settings, or turn on the plugin that has it."
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "OK")
            if alert.runModal() == .alertFirstButtonReturn { showSettings(pane: Self.settingsPane(forUnopenable: url, in: catalog)) }
            return
        }
        let controller = DocumentWindowController(url: url, catalog: catalog, config: config, recovery: .shared, recoveryClipboard: recoveryClipboard)
        controller.onBecameKey = { [weak self] in self?.showCommands(of: $0) }
        controller.openInOwnTab = { [weak self] in self?.openInWindow($0, place: $1) }
        controller.otherWindow = { [weak self, weak controller] url in
            self.flatMap { Self.window(showing: url, in: $0.windows.filter { $0 !== controller }) }
        }
        controller.onClose = { [weak self] closed in
            self?.windows.removeAll { $0 === closed }
            if self?.windows.isEmpty == true { self?.showCommands(of: nil) }
            self?.updatePresence()
            self?.updater.installIfIdle()
        }
        windows.append(controller)
        updatePresence()  // before the window shows, so the menus are there with it
        if let window = controller.window, let current = NSApp.keyWindow, current.tabbingIdentifier == window.tabbingIdentifier {
            current.addTabbedWindow(window, ordered: .above)
            window.makeKeyAndOrderFront(nil)
        } else {
            controller.showWindow(nil)
        }
        controller.pendingArrival = place.map { .place($0) }
        controller.show(with: entry, restoring: record)
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
        showWhatsNewForFirstWindow()
    }

    /// Where Open Settings goes for a file no enabled plugin opens: the turned-off plugin whose list has its extension,
    /// or else Plain Text, where the extension can be added.
    static func settingsPane(forUnopenable url: URL, in catalog: PluginCatalog) -> SettingsPane {
        .plugin(catalog.listing(url)?.id ?? "text")
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
                        open: { [self] in openInWindow($0.url, restoring: $0, place: nil) }).run()
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
