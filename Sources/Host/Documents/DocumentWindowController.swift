import AppKit
import PeekerKit

/// An Editor window (tabbed). Owns the chrome: "Open With" and the plugin's tools in the toolbar, and the save
/// prompts as sheets.
final class DocumentWindowController: NSWindowController, NSWindowDelegate, NSToolbarDelegate, NSMenuItemValidation, NSToolbarItemValidation, SavePrompts {
    let url: URL
    private let catalog: PluginCatalog
    private var config: Config
    private let recovery: RecoveryStore?
    private let recoveryClipboard: RecoveryClipboard?
    private let sidebarMemory: SidebarMemory
    private(set) var current: DocumentViewController?
    /// Called for every new document view controller (first open and "Open With" switches).
    var onDocument: ((DocumentViewController) -> Void)?
    var onBecameKey: ((DocumentWindowController) -> Void)?
    var onClose: ((DocumentWindowController) -> Void)?

    enum UnsavedChoice { case save, discard, cancel }
    /// Asks Save, Don't Save or Cancel about unsaved edits, as a sheet on the window. Tests answer directly.
    var askToSave: (DocumentWindowController) async -> UnsavedChoice = { await $0.askToSaveInSheet() }
    /// Shows a notice with a short title and its reason, as a sheet. Tests read it instead.
    var present: (DocumentWindowController, _ title: String, _ detail: String) async -> Void = { await $0.showInSheet($1, $2) }
    /// Asks whether to drop the unsaved edits for Revert to Saved, as a sheet. Tests answer directly.
    var confirmRevert: (DocumentWindowController) async -> Bool = {
        await $0.confirm("Revert to the last saved version?", "Your unsaved changes will be lost.", button: "Revert")
    }
    private var keyMonitor: Any?

    init(url: URL, catalog: PluginCatalog, config: Config, recovery: RecoveryStore?, recoveryClipboard: RecoveryClipboard?,
         sidebarMemory: SidebarMemory = .shared) {
        self.sidebarMemory = sidebarMemory
        self.url = url
        self.catalog = catalog
        self.config = config
        self.recovery = recovery
        self.recoveryClipboard = recoveryClipboard
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 720),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.tabbingIdentifier = "document"
        window.tabbingMode = .preferred
        window.title = url.lastPathComponent
        window.representedURL = url
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("DocumentWindow")
        window.contentMinSize = NSSize(width: 480, height: 320)  // room for the toolbar's first items and some content
        super.init(window: window)
        window.delegate = self
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleToolKey(event) == true ? nil : event
        }
    }

    /// Handles an edit tool's shortcut before the menus do. In an editable document it runs a tool whose shortcut is a
    /// single key, such as C for Crop, unless a text field or text view has the keyboard (a single key would swallow
    /// typing as a menu key). In a read-only one any edit tool's shortcut says why, since its greyed-out menu item can't.
    /// True when it took the key.
    func handleToolKey(_ event: NSEvent) -> Bool {
        guard event.window === window, let document = current, let pressed = Shortcut(event: event),
              let tool = document.tools.first(where: { $0.spec.isEditTool && $0.shortcut == pressed }) else { return false }
        let typing = window?.firstResponder is NSText
        switch document.editability {
        case .editable: guard pressed.isSingleKey, !typing else { return false }
        case .readOnly: guard !(pressed.isSingleKey && typing) else { return false }
        case .notEditable: return false
        }
        document.run(tool.spec)
        return true
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// Opens the file with `entry`. With a recovery record, its edits are applied once the file is showing.
    func show(with entry: PluginEntry, restoring record: RecoveryRecord? = nil) {
        current?.close()
        let document = DocumentViewController(url: url, entry: entry, config: config,
                                              allowsEditing: true, recovery: recovery, recoveryID: record?.id ?? UUID().uuidString,
                                              sidebarMemory: sidebarMemory)
        document.onToolsChanged = { [weak self] document in
            // While a file opens, its tools wait for its content (onContentShown); a failure shows at once.
            guard document.hasShownContent || document.pluginDocument == nil else { return }
            self?.toolsChanged()
        }
        document.onContentShown = { [weak self] _ in self?.toolsChanged() }
        document.onRecovery = { [weak self] _, result in self?.report(result) }
        document.onEditRefused = { [weak self] _, reason in self?.showMessage(reason) }
        document.onActiveToolChanged = { [weak self] _ in self?.showActiveTool() }
        // Before loading, so closing the window while the file opens keeps the record for the next launch.
        if let record { document.restore(record) }
        self.current = document
        window?.subtitle = entry.name
        if let window {
            let frame = window.frame
            window.contentViewController = document
            window.setFrame(frame, display: false)
        }
        onDocument?(document)
        rebuildToolbar()
        Task.immediate { await document.load() }
    }

    /// Tells the user when recovered edits went onto a newer file, or couldn't be applied in this view.
    func report(_ result: RecoveryResult) {
        let name = url.lastPathComponent
        let message: String
        switch result {
        case .restored(fileChangedSince: false):
            return
        case .restored(fileChangedSince: true):
            message = "“\(name)” changed on disk after these edits were made. Saving will replace the newer version."
        case .rejected(let record):
            if catalog.recoveryText(record) != nil {
                // The record stays when the clipboard refuses the text; the clipboard logs it.
                guard recoveryClipboard?.add([record]) == true else { return }
                message = "“\(name)” can't be edited in this view, so your unsaved text was copied to the clipboard."
            } else {
                // The record stays, so the changes come back when the file opens where they can be shown.
                message = "“\(name)” can't take back its unsaved changes in this view."
            }
        }
        showMessage("Recovered edits for “\(name)”", message)
    }

    private func showMessage(_ title: String, _ detail: String = "") {
        Task { await present(self, title, detail) }
    }

    private func showInSheet(_ title: String, _ detail: String) async {
        guard let window, window.attachedSheet == nil else { return }
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        _ = await alert.beginSheetModal(for: window)
    }

    /// Puts the document's tools in the toolbar, and in the menus when this window is in front.
    private func toolsChanged() {
        rebuildToolbar()
        if window?.isKeyWindow == true { onBecameKey?(self) }
    }

    /// Reached when the window itself has the keyboard, so the split view controller isn't in the responder chain.
    @objc func toggleSidebar(_ sender: Any?) {
        current?.toggleSidebar(sender)
    }

    @objc func runTool(_ sender: Any?) {
        let tag = (sender as? NSMenuItem)?.tag ?? (sender as? NSToolbarItem)?.tag ?? (sender as? NSControl)?.tag ?? -1
        guard let document = current, document.tools.indices.contains(tag) else { return }
        document.run(document.tools[tag].spec)
        showActiveTool()  // clicking a toolbar tool selects it; only the document's active one stays selected
        showToolStates()
    }

    /// Presses the toolbar buttons of tools that are on, and releases the others.
    private func showToolStates() {
        guard let document = current?.pluginDocument else { return }
        for item in window?.toolbar?.items ?? [] {
            guard let button = item.view as? NSButton, let index = toolIndex(item.itemIdentifier), let tools = current?.tools,
                  tools.indices.contains(index), let on = document.isOn(tools[index].spec.id) else { continue }
            button.state = on ? .on : .off
        }
    }

    private func toolIndex(_ identifier: NSToolbarItem.Identifier) -> Int? {
        identifier.rawValue.hasPrefix("tool.") ? Int(identifier.rawValue.dropFirst("tool.".count)) : nil
    }

    /// Shows the document's active tool as the toolbar's selected item, or none.
    private func showActiveTool() {
        let active = current?.pluginDocument?.activeTool
        let index = current?.tools.firstIndex { $0.spec.id == active }
        window?.toolbar?.selectedItemIdentifier = index.map { NSToolbarItem.Identifier("tool.\($0)") }
    }

    @objc private func reopenWith(_ sender: NSPopUpButton) {
        let candidates = catalog.openWithChoices(for: url)
        guard candidates.indices.contains(sender.indexOfSelectedItem) else { return }
        reopen(with: candidates[sender.indexOfSelectedItem]) { [weak self] in
            if let index = candidates.firstIndex(where: { $0.id == self?.current?.entry.id }) { sender.selectItem(at: index) }
        }
    }

    /// File > Open With: the submenu's items, by their tag in the choices. The submenu itself is filled as it's checked.
    @objc func reopenWithMenu(_ sender: NSMenuItem) {
        let candidates = catalog.openWithChoices(for: url)
        guard sender.submenu == nil, candidates.indices.contains(sender.tag) else { return }
        reopen(with: candidates[sender.tag])
    }

    /// Reopens the tab with `entry` once unsaved edits are resolved; `onCancel` runs when the user cancels.
    private func reopen(with entry: PluginEntry, onCancel: @escaping () -> Void = {}) {
        Task {
            guard await resolveUnsavedEdits() else { return onCancel() }
            show(with: entry)
        }
    }

    /// Lists the plugins in File > Open With's submenu; the check on the current one comes with each menu check.
    func fillOpenWith(_ menu: NSMenu) {
        menu.removeAllItems()
        for (index, entry) in catalog.openWithChoices(for: url).enumerated() {
            let item = NSMenuItem(title: entry.name, action: #selector(reopenWithMenu(_:)), keyEquivalent: "")
            item.tag = index
            item.target = self
            menu.addItem(item)
        }
    }

    // MARK: Saving

    @objc func saveDocument(_ sender: Any?) {
        guard let document = current else { return }
        finishTyping()
        Task { _ = await save(document) }
    }

    @objc func revertDocument(_ sender: Any?) {
        Task { await revert() }
    }

    /// Goes back to the file as last saved or loaded, once the user confirms.
    func revert() async {
        finishTyping()
        guard let document = current, document.isEdited, window?.attachedSheet == nil, await confirmRevert(self) else { return }
        document.discardEdits()
    }

    // MARK: Printing

    /// Shows the print panel for what's on screen, as a sheet. The document's plugin decides what prints.
    @objc func printDocument(_ sender: Any?) {
        guard let window, let job = current?.pluginDocument?.printJob else { return }
        finishTyping()
        guard let operation = job(NSPrintInfo.shared.copy() as! NSPrintInfo) else { return NSSound.beep() }
        operation.jobTitle = url.lastPathComponent
        operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
    }

    /// Ends typing in progress, such as in a PDF text box or form field, so it counts as an edit before a save or the
    /// unsaved-changes question. Only for documents with edit tools: a text document's own view keeps its focus.
    private func finishTyping() {
        guard let window, let document = current, document.tools.contains(where: \.spec.isEditTool) else { return }
        window.makeFirstResponder(nil)
        if let plugin = document.pluginDocument {
            let view = plugin.focusView ?? plugin.contentView
            if view.acceptsFirstResponder { window.makeFirstResponder(view) }
        }
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(saveDocument(_:)), #selector(revertDocument(_:)):
            return current?.isEdited == true && current?.isSaving == false
        case #selector(runTool(_:)):
            let id = current.flatMap { $0.tools.indices.contains(menuItem.tag) ? $0.tools[menuItem.tag].spec.id : nil }
            let on = id.flatMap { current?.pluginDocument?.isOn($0) } ?? false
            menuItem.state = on || (id != nil && id == current?.pluginDocument?.activeTool) ? .on : .off
            return unavailableReason(forToolAt: menuItem.tag) == nil
        case #selector(printDocument(_:)):
            return current?.pluginDocument?.printJob != nil
        case #selector(reopenWithMenu(_:)):
            if let submenu = menuItem.submenu { fillOpenWith(submenu); return current != nil }
            let candidates = catalog.openWithChoices(for: url)
            menuItem.state = candidates.indices.contains(menuItem.tag) && candidates[menuItem.tag].id == current?.entry.id ? .on : .off
            return true
        case #selector(NSSplitViewController.toggleSidebar(_:)):
            return current?.validateUserInterfaceItem(menuItem) ?? false
        default:
            return true
        }
    }

    /// Greys out a tool that can't run now, with the reason as the tooltip.
    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        guard item.action == #selector(runTool(_:)) else { return true }
        let reason = unavailableReason(forToolAt: item.tag)
        item.toolTip = reason ?? current.flatMap { $0.tools.indices.contains(item.tag) ? $0.tools[item.tag].spec.title : nil }
        return reason == nil
    }

    private func unavailableReason(forToolAt index: Int) -> String? {
        guard let document = current, document.tools.indices.contains(index) else { return nil }
        return document.unavailableReason(for: document.tools[index].spec)
    }

    /// Asks Save / Don't Save / Cancel when the document has unsaved edits. True when the caller may close or replace it.
    func resolveUnsavedEdits() async -> Bool {
        finishTyping()
        guard let document = current, document.isEdited else { return true }
        guard let window, window.attachedSheet == nil else { return false }
        switch await askToSave(self) {
        case .save:
            return await save(document)
        case .discard:
            document.discardEdits()
            return true
        case .cancel:
            return false
        }
    }

    private func askToSaveInSheet() async -> UnsavedChoice {
        guard let window else { return .cancel }
        let alert = NSAlert()
        alert.messageText = "Save changes to “\(url.lastPathComponent)”?"
        alert.informativeText = "Your changes will be lost if you don't save them."
        alert.addButton(withTitle: "Save")
        let dontSave = alert.addButton(withTitle: "Don't Save")
        dontSave.keyEquivalent = "d"
        dontSave.keyEquivalentModifierMask = .command
        alert.addButton(withTitle: "Cancel")
        switch await alert.beginSheetModal(for: window) {
        case .alertFirstButtonReturn: return .save
        case .alertSecondButtonReturn: return .discard
        default: return .cancel
        }
    }

    /// Saves, showing an alert if the save fails. True once the edits are on disk.
    private func save(_ document: DocumentViewController) async -> Bool {
        switch await document.save(prompts: self) {
        case .saved: return true
        case .cancelled: return false
        case .failed(let message):
            await present(self, "Couldn't save “\(url.lastPathComponent)”", message)
            return false
        }
    }

    func confirmOverwriteNewerFile(named name: String) async -> Bool {
        await confirm("“\(name)” changed on disk since you opened it.", "Saving will replace the newer version.", button: "Save Anyway")
    }

    func confirmRecreateMissingFile(named name: String) async -> Bool {
        await confirm("“\(name)” no longer exists on disk.", "Saving will create it again.", button: "Save")
    }

    func confirm(_ offer: SaveOffer, reason: String) async -> Bool {
        await confirm(reason, offer.detail, button: offer.button)
    }

    private func confirm(_ message: String, _ detail: String, button: String) async -> Bool {
        guard let window else { return false }
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = detail
        alert.addButton(withTitle: button)
        alert.addButton(withTitle: "Cancel")
        return await alert.beginSheetModal(for: window) == .alertFirstButtonReturn
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        finishTyping()
        guard current?.isEdited == true else { return true }
        Task {
            if await resolveUnsavedEdits() { sender.close() }
        }
        return false
    }

    func windowDidBecomeKey(_ notification: Notification) { onBecameKey?(self) }

    /// Takes a newly saved config; Open With switches use it too.
    func apply(_ config: Config) {
        self.config = config
        current?.apply(config)
    }

    func windowWillClose(_ notification: Notification) {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        current?.close()
        current = nil
        onClose?(self)
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
        showActiveTool()
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        guard let document = current else { return [Self.openWith] }
        let shown = document.tools.indices.filter { document.tools[$0].spec.showsInToolbar }
        let identifier = { (index: Int) in NSToolbarItem.Identifier("tool.\(index)") }
        let view = shown.filter { !document.tools[$0].spec.isEditTool }.map(identifier)
        let tools = shown.filter { document.tools[$0].spec.isEditTool }.map(identifier)
        // A space between the two runs puts view tools and edit tools on separate pieces of glass.
        return (document.hasSidebar ? [.toggleSidebar] : []) + [Self.openWith] + [.flexibleSpace]
            + view + (view.isEmpty || tools.isEmpty ? [] : [.space]) + tools
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    /// The tools: the document's active one shows selected, the toolbar's native look for one choice at a time.
    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar).filter { identifier in
            toolIndex(identifier).map { isSwitch(at: $0) == false } ?? false
        }
    }

    /// Whether the tool turns something on and off, so its button shows that instead of being selectable.
    private func isSwitch(at index: Int) -> Bool {
        guard let document = current, document.tools.indices.contains(index) else { return false }
        return document.pluginDocument?.isOn(document.tools[index].spec.id) != nil
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: identifier)
        if identifier == Self.openWith {
            let popup = NSPopUpButton(frame: .zero, pullsDown: false)
            let candidates = catalog.openWithChoices(for: url)
            popup.addItems(withTitles: candidates.map(\.name))
            if let index = candidates.firstIndex(where: { $0.id == current?.entry.id }) { popup.selectItem(at: index) }
            popup.target = self
            popup.action = #selector(reopenWith(_:))
            item.view = popup
            item.label = "Open With"
            item.toolTip = "Open With"
            return item
        }
        guard let document = current, let index = Int(identifier.rawValue.dropFirst("tool.".count)), document.tools.indices.contains(index) else { return nil }
        let spec = document.tools[index].spec
        item.label = spec.title
        item.toolTip = spec.title
        let image = spec.symbol.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: spec.title) }
        if let on = document.pluginDocument?.isOn(spec.id) {
            let button = NSButton(image: image ?? NSImage(), target: self, action: #selector(runTool(_:)))
            button.setButtonType(.pushOnPushOff)
            button.bezelStyle = .toolbar
            button.state = on ? .on : .off
            button.tag = index
            item.view = button
        } else {
            item.image = image
        }
        item.tag = index
        item.target = self
        item.action = #selector(runTool(_:))
        return item
    }
}
