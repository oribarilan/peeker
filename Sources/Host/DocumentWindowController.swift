import AppKit
import PreviewPPKit

/// One open file in one tab. Owns the chrome (toolbar, "Open With", Commands menu); the plugin owns the content.
final class DocumentWindowController: NSWindowController, NSWindowDelegate, NSToolbarDelegate, PluginHost {
    let url: URL
    private let registry: PluginRegistry
    private let config: Config
    private(set) var entry: PluginEntry?
    private(set) var commands: [(command: Command, shortcut: Shortcut?)] = []
    private var viewer: Viewer?
    private var isReady = false
    private var openStarted = ContinuousClock.now

    /// Called once per plugin load when content is on screen, with the time `open` took to get there.
    var onReady: ((DocumentWindowController, Duration) -> Void)?
    var onFailure: ((DocumentWindowController, String) -> Void)?
    var onBecameKey: ((DocumentWindowController) -> Void)?

    init(url: URL, registry: PluginRegistry, config: Config) {
        self.url = url
        self.registry = registry
        self.config = config
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.tabbingIdentifier = "document"
        window.tabbingMode = .preferred
        window.title = url.lastPathComponent
        window.representedURL = url
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("DocumentWindow")
        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func load(_ entry: PluginEntry) {
        viewer?.onClose?()
        self.entry = entry
        isReady = false
        openStarted = .now
        window?.subtitle = "\(entry.manifest.name) · \(entry.runtime.rawValue)"
        do {
            let viewer = try entry.open(url, self)
            self.viewer = viewer
            commands = viewer.commands.map { ($0, config.keys["\(entry.manifest.id).\($0.id)"] ?? $0.shortcut) }
            install(viewer)
            if viewer.readiness == .immediate { contentDidBecomeReady() }
        } catch {
            viewer = nil
            commands = []
            viewerDidFail(error.localizedDescription)
        }
        rebuildToolbar()
        if window?.isKeyWindow == true { onBecameKey?(self) }
    }

    private func install(_ viewer: Viewer) {
        guard let sidebar = viewer.sidebar else {
            setContent(viewer.content)
            return
        }
        let split = NSSplitViewController()
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebar)
        sidebarItem.minimumThickness = 130
        split.addSplitViewItem(sidebarItem)
        split.addSplitViewItem(NSSplitViewItem(viewController: viewer.content))
        setContent(split)
    }

    /// Assigning contentViewController resizes the window to the view's frame; plugin views have no opinion on that.
    private func setContent(_ controller: NSViewController) {
        guard let window else { return }
        let frame = window.frame
        window.contentViewController = controller
        window.setFrame(frame, display: true)
    }

    // MARK: PluginHost

    /// Same rule for every runtime: ready means the window has drawn the content and the run loop has turned once.
    func contentDidBecomeReady() {
        guard !isReady else { return }
        isReady = true
        window?.displayIfNeeded()
        DispatchQueue.main.async { self.onReady?(self, .now - self.openStarted) }
    }

    func viewerDidFail(_ message: String) {
        setContent(MessageViewController(message))
        onFailure?(self, message)
    }

    // MARK: Window

    func windowDidBecomeKey(_ notification: Notification) {
        onBecameKey?(self)
    }

    func windowWillClose(_ notification: Notification) {
        viewer?.onClose?()
        viewer = nil
    }

    @objc func runCommand(_ sender: Any?) {
        let tag = (sender as? NSMenuItem)?.tag ?? (sender as? NSToolbarItem)?.tag ?? -1
        guard commands.indices.contains(tag) else { return }
        commands[tag].command.run()
    }

    @objc private func reopenWith(_ sender: NSPopUpButton) {
        let candidates = registry.candidates(for: url)
        guard candidates.indices.contains(sender.indexOfSelectedItem) else { return }
        load(candidates[sender.indexOfSelectedItem])
    }

    // MARK: Toolbar

    private static let openWith = NSToolbarItem.Identifier("openWith")

    private func rebuildToolbar() {
        // A fresh identifier per rebuild: toolbars sharing an identifier sync their items across windows.
        let toolbar = NSToolbar(identifier: "doc-\(UUID().uuidString)")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        window?.toolbar = toolbar
        window?.toolbarStyle = .unified
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.openWith, .flexibleSpace] + commands.indices.map { NSToolbarItem.Identifier("command.\($0)") }
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: identifier)
        if identifier == Self.openWith {
            let popup = NSPopUpButton(frame: .zero, pullsDown: false)
            let candidates = registry.candidates(for: url)
            popup.addItems(withTitles: candidates.map { "\($0.manifest.name) (\($0.id))" })
            if let index = candidates.firstIndex(where: { $0.id == entry?.id }) { popup.selectItem(at: index) }
            popup.target = self
            popup.action = #selector(reopenWith(_:))
            item.view = popup
            item.label = "Open With"
            return item
        }
        guard let index = Int(identifier.rawValue.dropFirst("command.".count)), commands.indices.contains(index) else { return nil }
        let command = commands[index].command
        item.label = command.title
        item.toolTip = command.title
        item.image = command.symbolName.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: command.title) }
        item.tag = index
        item.target = self
        item.action = #selector(runCommand(_:))
        return item
    }
}
