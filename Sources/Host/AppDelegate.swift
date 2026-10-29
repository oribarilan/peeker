import AppKit
import PreviewPPKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let config = Config.load()
    private lazy var registry = PluginRegistry(config: config)
    private var documents: [DocumentWindowController] = []
    private let commandsMenu = NSMenu(title: "Commands")

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()
        let started = ContinuousClock.now
        registerBuiltins(in: registry)
        registry.discover(in: pluginDirectories())
        Bench.discovery = .now - started
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Direct launches from a terminal pass files as arguments; LaunchServices uses application(_:open:).
        let fileArguments = CommandLine.arguments.dropFirst()
            .filter { !$0.hasPrefix("-") && FileManager.default.fileExists(atPath: $0) }
        fileArguments.forEach { open(URL(filePath: $0)) }
        NSApp.activate()
        if documents.isEmpty && Bench.outputURL == nil { showOpenPanel(nil) }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach(open)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    private func pluginDirectories() -> [URL] {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        var directories = [Bundle.main.builtInPlugInsURL, support.appending(path: "PreviewPP/Plugins")].compactMap { $0 }
        directories += config.pluginDirectories
        if let extra = ProcessInfo.processInfo.environment["PPP_PLUGINS_DIR"] { directories.append(URL(filePath: extra)) }
        return directories
    }

    // MARK: Documents

    func open(_ url: URL) {
        if let existing = documents.first(where: { $0.url == url }) {
            existing.window?.makeKeyAndOrderFront(nil)
            return
        }
        guard let entry = registry.defaultPlugin(for: url) else {
            if Bench.outputURL != nil {
                Bench.record(plugin: "-", runtime: "-", file: url, open: .zero, failure: "no enabled plugin for this file type")
                NSApp.terminate(nil)
                return
            }
            let alert = NSAlert()
            alert.messageText = "No plugin can open \(url.lastPathComponent)"
            alert.informativeText = "Install or enable a plugin for this file type."
            alert.runModal()
            return
        }
        let document = DocumentWindowController(url: url, registry: registry, config: config)
        document.onBecameKey = { [weak self] in self?.rebuildCommandsMenu(for: $0) }
        document.onReady = { document, duration in
            guard let entry = document.entry, Bench.outputURL != nil else { return }
            // Isolation test: run a plugin command, then report whether the host is still alive and responsive.
            if let id = Bench.commandToRun, let command = document.commands.first(where: { $0.command.id == id }) {
                command.command.run()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    Bench.record(plugin: entry.id, runtime: entry.runtime.rawValue, file: document.url, open: duration, note: "host survived \(id)")
                    NSApp.terminate(nil)
                }
                return
            }
            Bench.record(plugin: entry.id, runtime: entry.runtime.rawValue, file: document.url, open: duration)
            NSApp.terminate(nil)
        }
        document.onFailure = { document, message in
            guard Bench.outputURL != nil else { return }
            Bench.record(plugin: document.entry?.id ?? "?", runtime: document.entry?.runtime.rawValue ?? "?", file: document.url, open: .zero, failure: message)
            NSApp.terminate(nil)
        }
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: document.window, queue: .main) { [weak self, weak document] _ in
            MainActor.assumeIsolated { self?.documents.removeAll { $0 === document } }
        }
        documents.append(document)
        if let window = document.window, let current = NSApp.keyWindow, current.tabbingIdentifier == window.tabbingIdentifier {
            current.addTabbedWindow(window, ordered: .above)
            window.makeKeyAndOrderFront(nil)
        } else {
            document.showWindow(nil)
        }
        document.load(entry)
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
    }

    @objc func showOpenPanel(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        panel.urls.forEach(open)
    }

    // MARK: Menus

    private func rebuildCommandsMenu(for document: DocumentWindowController) {
        commandsMenu.removeAllItems()
        for (index, entry) in document.commands.enumerated() {
            let item = NSMenuItem(title: entry.command.title, action: #selector(DocumentWindowController.runCommand(_:)), keyEquivalent: entry.shortcut?.key ?? "")
            item.keyEquivalentModifierMask = entry.shortcut?.modifiers ?? []
            item.tag = index
            item.target = document
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
            item("Undo", Selector(("undo:")), "z"),
            item("Redo", Selector(("redo:")), "z", [.command, .shift]),
            .separator(),
            item("Cut", #selector(NSText.cut(_:)), "x"),
            item("Copy", #selector(NSText.copy(_:)), "c"),
            item("Paste", #selector(NSText.paste(_:)), "v"),
            item("Select All", #selector(NSText.selectAll(_:)), "a"),
            .separator(),
            item("Find…", #selector(NSTextView.performFindPanelAction(_:)), "f", tag: Int(NSFindPanelAction.showFindPanel.rawValue)),
            item("Find Next", #selector(NSTextView.performFindPanelAction(_:)), "g", tag: Int(NSFindPanelAction.next.rawValue)),
            item("Find Previous", #selector(NSTextView.performFindPanelAction(_:)), "g", [.command, .shift], tag: Int(NSFindPanelAction.previous.rawValue)),
        ])
        main.addItem(withTitle: "Commands", action: nil, keyEquivalent: "").submenu = commandsMenu
        let window = submenu("Window", [
            item("Minimize", #selector(NSWindow.performMiniaturize(_:)), "m"),
            item("Show Previous Tab", #selector(NSWindow.selectPreviousTab(_:)), "{"),
            item("Show Next Tab", #selector(NSWindow.selectNextTab(_:)), "}"),
        ])
        NSApp.windowsMenu = window
        return main
    }
}
