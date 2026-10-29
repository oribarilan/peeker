import AppKit

/// A document window (tabbed). Owns the chrome: "Open With" and the plugin's commands in the toolbar.
final class DocumentWindowController: NSWindowController, NSWindowDelegate, NSToolbarDelegate {
    let url: URL
    private let catalog: PluginCatalog
    private let config: Config
    private(set) var current: DocumentViewController?
    /// Called for every new document view controller (first open and "Open With" switches).
    var onDocument: ((DocumentViewController) -> Void)?
    var onBecameKey: ((DocumentWindowController) -> Void)?

    init(url: URL, catalog: PluginCatalog, config: Config) {
        self.url = url
        self.catalog = catalog
        self.config = config
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 720),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
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

    func show(with entry: PluginEntry) {
        current?.close()
        let document = DocumentViewController(url: url, entry: entry, process: catalog.process(for: entry), config: config)
        document.onCommandsChanged = { [weak self] _ in
            self?.rebuildToolbar()
            if let self, self.window?.isKeyWindow == true { self.onBecameKey?(self) }
        }
        self.current = document
        window?.subtitle = entry.manifest.name
        if let window {
            let frame = window.frame
            window.contentViewController = document
            window.setFrame(frame, display: false)
        }
        onDocument?(document)
        rebuildToolbar()
        document.load()
    }

    @objc func runCommand(_ sender: Any?) {
        let tag = (sender as? NSMenuItem)?.tag ?? (sender as? NSToolbarItem)?.tag ?? -1
        guard let document = current, document.commands.indices.contains(tag) else { return }
        document.run(document.commands[tag].spec)
    }

    @objc private func reopenWith(_ sender: NSPopUpButton) {
        let candidates = catalog.candidates(for: url)
        guard candidates.indices.contains(sender.indexOfSelectedItem) else { return }
        show(with: candidates[sender.indexOfSelectedItem])
    }

    func windowDidBecomeKey(_ notification: Notification) { onBecameKey?(self) }

    func windowWillClose(_ notification: Notification) {
        current?.close()
        current = nil
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
        [Self.openWith, .flexibleSpace] + (current?.commands.indices.map { NSToolbarItem.Identifier("command.\($0)") } ?? [])
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: identifier)
        if identifier == Self.openWith {
            let popup = NSPopUpButton(frame: .zero, pullsDown: false)
            let candidates = catalog.candidates(for: url)
            popup.addItems(withTitles: candidates.map(\.manifest.name))
            if let index = candidates.firstIndex(where: { $0.id == current?.entry.id }) { popup.selectItem(at: index) }
            popup.target = self
            popup.action = #selector(reopenWith(_:))
            item.view = popup
            item.label = "Open With"
            return item
        }
        guard let document = current, let index = Int(identifier.rawValue.dropFirst("command.".count)), document.commands.indices.contains(index) else { return nil }
        let spec = document.commands[index].spec
        item.label = spec.title
        item.toolTip = spec.title
        item.image = spec.symbol.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: spec.title) }
        item.tag = index
        item.target = self
        item.action = #selector(runCommand(_:))
        return item
    }
}
