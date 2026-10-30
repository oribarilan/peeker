import AppKit
import os

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private var config = AppDelegate.loadAtLaunch()
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "dev.peeker", category: "config")

    /// A config that can't be read at launch falls back to defaults; the problem goes to the log.
    private static func loadAtLaunch() -> Config {
        do { return try Config.load() } catch {
            log.error("can't read config: \(error.localizedDescription, privacy: .public)")
            return Config()
        }
    }

    private lazy var catalog = PluginCatalog.load(from: .main, config: config)
    private var windows: [DocumentWindowController] = []
    private lazy var panel: QuickLookPanel = {
        let panel = QuickLookPanel()
        panel.onOpenInWindow = { [weak self] url in self?.openInWindow(url) }
        return panel
    }()
    private lazy var finder = FinderBridge()
    private var hotkey: HotkeyMonitor?
    private var trustTimer: Timer?
    private var commandsMenu: NSMenu?
    private var benchRunner: BenchRunner?
    private var benchStarted = false
    private var recoveryRestored = false
    /// One for the whole app, so recovered texts that land on the clipboard during a launch don't replace each other.
    private lazy var recoveryClipboard = RecoveryClipboard(pasteboard: .general, store: .shared)

    func applicationWillFinishLaunching(_ notification: Notification) {
        let menu = MainMenu.make(target: self)
        commandsMenu = menu.item(withTitle: "Commands")?.submenu
        NSApp.mainMenu = menu
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        if item.action == #selector(toggleOpenAtLogin(_:)) { item.state = LoginItem.isEnabled ? .on : LoginItem.needsApproval ? .mixed : .off }
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
        restoreRecoveredDocuments()
        files.forEach(openInWindow)
        startHotkey()
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
        trustTimer?.invalidate()
        guard let shortcut = config.quickLookKey else { return }
        let monitor = HotkeyMonitor(shortcut: shortcut)
        monitor.isPanelVisible = { [weak self] in self?.panel.isVisible == true }
        monitor.onTrigger = { [weak self] in self?.quickLookFinderSelection() }
        monitor.onDismiss = { [weak self] in self?.panel.dismiss() }
        monitor.onSelectionMayHaveChanged = { [weak self] in self?.followFinderSelection() }
        hotkey = monitor
        if monitor.start() { return }
        // Until Accessibility is granted the tap can't be created; ask once, then retry quietly.
        HotkeyMonitor.requestTrust()
        trustTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.hotkey?.start() == true else { return }
                self.trustTimer?.invalidate()
            }
        }
    }

    /// Re-reads the config for documents opened from now on. A file that can't be read leaves the current config in place.
    @objc func reloadConfig(_ sender: Any?) {
        let new: Config
        do { new = try Config.load() } catch {
            Self.log.error("can't reload config: \(error.localizedDescription, privacy: .public)")
            let alert = NSAlert()
            alert.messageText = "Couldn't read the config file"
            alert.informativeText = "\(error.localizedDescription)\nThe previous settings are still in use."
            alert.runModal()
            return
        }
        let keyChanged = new.quickLookKey != config.quickLookKey
        config = new
        catalog.reload(config: new)
        guard keyChanged else { return }
        hotkey?.stop()
        hotkey = nil
        startHotkey()
    }

    @objc func toggleOpenAtLogin(_ sender: Any?) {
        do { try LoginItem.toggle() } catch {
            Self.log.error("can't change Open at Login: \(error.localizedDescription, privacy: .public)")
            let alert = NSAlert()
            alert.messageText = "Couldn't change Open at Login"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    private func quickLookFinderSelection() {
        guard let url = finder.selection().first, let entry = catalog.defaultPlugin(for: url) else {
            hotkey?.passKeyToFinder()
            return
        }
        showInPanel(url, entry: entry)
    }

    private func followFinderSelection() {
        guard panel.isVisible, let url = finder.selection().first, url != panel.url else { return }
        guard let entry = catalog.defaultPlugin(for: url) else {
            panel.dismiss()
            return
        }
        showInPanel(url, entry: entry)
    }

    private func showInPanel(_ url: URL, entry: PluginEntry) {
        let document = DocumentViewController(url: url, entry: entry, process: catalog.process(for: entry), config: config, allowsEditing: false, recovery: nil)
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
            let alert = NSAlert()
            alert.messageText = "No enabled plugin opens \(url.lastPathComponent)"
            alert.informativeText = "Enable a plugin that supports this file type in your config."
            alert.runModal()
            return
        }
        let controller = DocumentWindowController(url: url, catalog: catalog, config: config, allowsEditing: true, recovery: .shared, recoveryClipboard: recoveryClipboard)
        controller.onBecameKey = { [weak self] in if let menu = self?.commandsMenu { MainMenu.rebuildCommands(menu, for: $0) } }
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: controller.window, queue: .main) { [weak self, weak controller] _ in
            MainActor.assumeIsolated { self?.windows.removeAll { $0 === controller } }
        }
        windows.append(controller)
        if let window = controller.window, let current = NSApp.keyWindow, current.tabbingIdentifier == window.tabbingIdentifier {
            current.addTabbedWindow(window, ordered: .above)
            window.makeKeyAndOrderFront(nil)
        } else {
            controller.showWindow(nil)
        }
        controller.show(with: entry, restoring: record)
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
    }

    /// The record's plugin if it's still enabled and supports the file, else the default one.
    private func plugin(for url: URL, restoring record: RecoveryRecord?) -> PluginEntry? {
        let recordedPlugin = record.flatMap { record in catalog.candidates(for: url).first { $0.id == record.pluginID } }
        return recordedPlugin ?? catalog.defaultPlugin(for: url)
    }

    // MARK: Crash recovery

    /// Reopens each document that had unsaved edits when the app last stopped without quitting, once per launch.
    private func restoreRecoveredDocuments() {
        guard !recoveryRestored else { return }
        recoveryRestored = true
        let store = RecoveryStore.shared
        var restored: Set<URL> = []
        var missingText: [RecoveryRecord] = [], unopenableText: [RecoveryRecord] = []
        for record in store.all() {   // newest first, so a file's newest record wins
            guard restored.insert(record.url.standardizedFileURL).inserted else {
                store.remove(id: record.id)
                continue
            }
            let exists = FileManager.default.fileExists(atPath: record.url.path)
            if exists, plugin(for: record.url, restoring: record) != nil {
                openInWindow(record.url, restoring: record)
                continue
            }
            // Without its file or an enabled plugin for it, the record can't go back into a window; kept, it would
            // come back every launch.
            let name = "“\(record.url.lastPathComponent)”"
            switch record.edits {
            case .text:
                if exists { unopenableText.append(record) } else { missingText.append(record) }
            case .pdfHighlights:
                store.remove(id: record.id)
                let alert = NSAlert()
                alert.messageText = exists ? "No enabled plugin opens \(name). Its unsaved highlights couldn't be restored."
                                           : "\(name) no longer exists. Its unsaved highlights couldn't be restored."
                alert.runModal()
            }
        }
        copyToClipboard(missingText) { names, count in "\(names) \(count == 1 ? "no longer exists" : "no longer exist")." }
        copyToClipboard(unopenableText) { names, _ in "No enabled plugin opens \(names)." }
    }

    /// Puts the records' text on the clipboard and says why; the records stay if the clipboard refuses.
    private func copyToClipboard(_ records: [RecoveryRecord], reason: (_ names: String, _ count: Int) -> String) {
        guard !records.isEmpty, recoveryClipboard.add(records) else { return }
        let names = ListFormatter.localizedString(byJoining: records.map { "“\($0.url.lastPathComponent)”" })
        let alert = NSAlert()
        alert.messageText = reason(names, records.count) + " Your unsaved text was copied to the clipboard."
        alert.runModal()
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
