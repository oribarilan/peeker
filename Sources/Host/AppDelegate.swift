import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let config = Config.load()
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
    private let commandsMenu = NSMenu(title: "Commands")
    private var benchStarted = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let files = CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("-") && FileManager.default.fileExists(atPath: $0) }.map { URL(filePath: $0) }
        if let bench = Bench.current {
            // Launched from a terminal the file is an argument; through LaunchServices it arrives in application(_:open:).
            if let file = files.first, !benchStarted {
                benchStarted = true
                runBench(bench, url: file, remaining: bench.repeats, index: 0)
            }
            return
        }
        files.forEach(openInWindow)
        startHotkey()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        if let bench = Bench.current {
            guard let url = urls.first, !benchStarted else { return }
            benchStarted = true
            runBench(bench, url: url, remaining: bench.repeats, index: 0)
            return
        }
        urls.forEach(openInWindow)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // MARK: Quick look

    private func startHotkey() {
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
        let document = DocumentViewController(url: url, entry: entry, process: catalog.process(for: entry), config: config)
        panel.show(document)
    }

    // MARK: Windows

    func openInWindow(_ url: URL) {
        if let existing = windows.first(where: { $0.url == url }) {
            existing.window?.makeKeyAndOrderFront(nil)
            return
        }
        guard let entry = catalog.defaultPlugin(for: url) else {
            let alert = NSAlert()
            alert.messageText = "No enabled plugin opens \(url.lastPathComponent)"
            alert.informativeText = "Enable a plugin that supports this file type in your config."
            alert.runModal()
            return
        }
        let controller = DocumentWindowController(url: url, catalog: catalog, config: config)
        controller.onBecameKey = { [weak self] in self?.rebuildCommandsMenu(for: $0) }
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
        controller.show(with: entry)
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
    }

    @objc func showOpenPanel(_ sender: Any?) {
        let open = NSOpenPanel()
        open.allowsMultipleSelection = true
        guard open.runModal() == .OK else { return }
        open.urls.forEach(openInWindow)
    }

    // MARK: Benchmark mode

    /// Opens the same file `remaining` times in a row (closing it in between), recording each open.
    /// Run 0 is a cold app and a cold plugin, run 1 finds both warm, and before run 2 the plugin process is
    /// stopped, so run 2 minus run 1 is the cost of starting a plugin on demand.
    private func runBench(_ bench: Bench, url: URL, remaining: Int, index: Int) {
        guard remaining > 0 else {
            NSApp.terminate(nil)
            return
        }
        guard let entry = catalog.defaultPlugin(for: url) else {
            bench.record(["file": url.lastPathComponent, "failure": "no plugin"])
            NSApp.terminate(nil)
            return
        }
        let process = catalog.process(for: entry)
        if index == 2 { process.stopAndWait() }
        let onReady: (DocumentViewController, Duration, Bool) -> Void = { [weak self] document, duration, wasRunning in
            bench.record([
                "file": url.lastPathComponent, "plugin": entry.id, "mode": bench.mode, "run": index,
                "pluginWasRunning": wasRunning, "openToReadyMs": Bench.ms(duration), "replyMs": Bench.ms(document.replyDuration), "launchMs": wasRunning ? NSNull() : Bench.ms(process.lastLaunch),
                "processToReadyMs": index == 0 ? Bench.msSinceProcessStart() : NSNull(),
                "hostFootprintMB": Bench.footprintMB(), "pluginFootprintMB": process.footprintMB ?? NSNull(),
            ])
            self?.closeBenchDocument(mode: bench.mode)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self?.runBench(bench, url: url, remaining: remaining - 1, index: index + 1) }
        }
        let onFailure: (DocumentViewController, String) -> Void = { _, message in
            bench.record(["file": url.lastPathComponent, "plugin": entry.id, "run": index, "failure": message])
            NSApp.terminate(nil)
        }
        if bench.mode == "panel" {
            let document = DocumentViewController(url: url, entry: entry, process: process, config: config)
            document.onReady = onReady
            document.onFailure = onFailure
            panel.show(document)
        } else {
            let controller = DocumentWindowController(url: url, catalog: catalog, config: config)
            controller.onDocument = { $0.onReady = onReady; $0.onFailure = onFailure }
            windows = [controller]
            controller.showWindow(nil)
            controller.show(with: entry)
        }
    }

    private func closeBenchDocument(mode: String) {
        if mode == "panel" {
            panel.dismiss()
        } else {
            windows.forEach { $0.close() }
            windows.removeAll()
        }
    }

    // MARK: Menus

    private func rebuildCommandsMenu(for controller: DocumentWindowController) {
        commandsMenu.removeAllItems()
        for (index, command) in (controller.current?.commands ?? []).enumerated() {
            let item = NSMenuItem(title: command.spec.title, action: #selector(DocumentWindowController.runCommand(_:)), keyEquivalent: command.shortcut?.keyEquivalent ?? "")
            item.keyEquivalentModifierMask = command.shortcut?.modifiers ?? []
            item.tag = index
            item.target = controller
            commandsMenu.addItem(item)
        }
    }

    private func makeMainMenu() -> NSMenu {
        let main = NSMenu()
        func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenu {
            let menu = NSMenu(title: title)
            items.forEach(menu.addItem)
            main.addItem(withTitle: title, action: nil, keyEquivalent: "").submenu = menu
            return menu
        }
        func item(_ title: String, _ action: Selector?, _ key: String = "", _ modifiers: NSEvent.ModifierFlags = .command, tag: Int = 0) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.keyEquivalentModifierMask = modifiers
            item.tag = tag
            return item
        }

        _ = submenu("Preview++", [
            item("About Preview++", #selector(NSApplication.orderFrontStandardAboutPanel(_:))),
            .separator(),
            item("Hide Preview++", #selector(NSApplication.hide(_:)), "h"),
            item("Quit Preview++", #selector(NSApplication.terminate(_:)), "q"),
        ])
        _ = submenu("File", [
            item("Open…", #selector(showOpenPanel(_:)), "o"),
            item("Close", #selector(NSWindow.performClose(_:)), "w"),
        ])
        _ = submenu("Edit", [
            item("Copy", #selector(NSText.copy(_:)), "c"),
            item("Select All", #selector(NSText.selectAll(_:)), "a"),
            .separator(),
            item("Find…", #selector(NSTextView.performFindPanelAction(_:)), "f", tag: Int(NSFindPanelAction.showFindPanel.rawValue)),
            item("Find Next", #selector(NSTextView.performFindPanelAction(_:)), "g", tag: Int(NSFindPanelAction.next.rawValue)),
        ])
        main.addItem(withTitle: "Commands", action: nil, keyEquivalent: "").submenu = commandsMenu
        NSApp.windowsMenu = submenu("Window", [
            item("Minimize", #selector(NSWindow.performMiniaturize(_:)), "m"),
            item("Show Previous Tab", #selector(NSWindow.selectPreviousTab(_:)), "{"),
            item("Show Next Tab", #selector(NSWindow.selectNextTab(_:)), "}"),
        ])
        return main
    }
}
