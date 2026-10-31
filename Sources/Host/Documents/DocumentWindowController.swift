import AppKit
import PeekerKit

/// A document window (tabbed). Owns the chrome: "Open With" and the plugin's commands in the toolbar, and the save
/// prompts as sheets.
final class DocumentWindowController: NSWindowController, NSWindowDelegate, NSToolbarDelegate, NSMenuItemValidation, SavePrompts {
    let url: URL
    private let catalog: PluginCatalog
    private var config: Config
    private let allowsEditing: Bool
    private let recovery: RecoveryStore?
    private let recoveryClipboard: RecoveryClipboard?
    private(set) var current: DocumentViewController?
    /// Called for every new document view controller (first open and "Open With" switches).
    var onDocument: ((DocumentViewController) -> Void)?
    var onBecameKey: ((DocumentWindowController) -> Void)?

    init(url: URL, catalog: PluginCatalog, config: Config, allowsEditing: Bool, recovery: RecoveryStore?, recoveryClipboard: RecoveryClipboard?) {
        self.url = url
        self.catalog = catalog
        self.config = config
        self.allowsEditing = allowsEditing
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
        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// Opens the file with `entry`. With a recovery record, its edits are applied once the file is showing.
    func show(with entry: PluginEntry, restoring record: RecoveryRecord? = nil) {
        current?.close()
        let document = DocumentViewController(url: url, entry: entry, config: config,
                                              allowsEditing: allowsEditing, recovery: recovery, recoveryID: record?.id ?? UUID().uuidString)
        document.onCommandsChanged = { [weak self] _ in
            self?.rebuildToolbar()
            if let self, self.window?.isKeyWindow == true { self.onBecameKey?(self) }
        }
        document.onRecovery = { [weak self] _, result in self?.report(result) }
        document.onEditRefused = { [weak self] _, reason in self?.showMessage(reason) }
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
    private func report(_ result: RecoveryResult) {
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
        showMessage(message)
    }

    private func showMessage(_ message: String) {
        Task {
            guard let window, window.attachedSheet == nil else { return }
            let alert = NSAlert()
            alert.messageText = message
            _ = await alert.beginSheetModal(for: window)
        }
    }

    /// The Edit button and Edit Mode (Cmd+E).
    @objc func toggleEditMode(_ sender: Any?) {
        guard let document = current else { return }
        Task {
            await document.toggleEditing(resolve: resolveUnsavedEdits)
            // The button flipped when clicked; after Cancel or a failed save it must show the mode as it is.
            let button = window?.toolbar?.items.first { $0.itemIdentifier == Self.edit }?.view as? NSButton
            button?.state = current?.isEditing == true ? .on : .off
        }
    }

    @objc func runCommand(_ sender: Any?) {
        let tag = (sender as? NSMenuItem)?.tag ?? (sender as? NSToolbarItem)?.tag ?? -1
        guard let document = current, document.commands.indices.contains(tag) else { return }
        document.run(document.commands[tag].spec)
    }

    @objc private func reopenWith(_ sender: NSPopUpButton) {
        let candidates = catalog.openWithChoices(for: url)
        guard candidates.indices.contains(sender.indexOfSelectedItem) else { return }
        let entry = candidates[sender.indexOfSelectedItem]
        Task {
            guard await resolveUnsavedEdits() else {
                if let index = candidates.firstIndex(where: { $0.id == current?.entry.id }) { sender.selectItem(at: index) }
                return
            }
            show(with: entry)
        }
    }

    // MARK: Saving

    @objc func saveDocument(_ sender: Any?) {
        guard let document = current else { return }
        finishTyping()
        Task { _ = await save(document) }
    }

    /// Ends typing in progress, such as in a PDF text box or form field, so it counts as an edit before a save or the
    /// unsaved-changes question. Only for documents with an edit mode: a text document's own view keeps its focus.
    private func finishTyping() {
        guard let window, let document = current, document.editMode != .none else { return }
        window.makeFirstResponder(nil)
        if let view = document.pluginDocument?.contentView, view.acceptsFirstResponder { window.makeFirstResponder(view) }
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(saveDocument(_:)):
            return current?.isEdited == true && current?.isSaving == false
        case #selector(toggleEditMode(_:)):
            menuItem.state = current?.isEditing == true ? .on : .off
            return current.map { $0.editMode != .none } ?? false  // enabled when unavailable, to say why
        default:
            return true
        }
    }

    /// Asks Save / Don't Save / Cancel when the document has unsaved edits. True when the caller may close or replace it.
    func resolveUnsavedEdits() async -> Bool {
        finishTyping()
        guard let document = current, document.isEdited else { return true }
        guard let window, window.attachedSheet == nil else { return false }
        let alert = NSAlert()
        alert.messageText = "Save changes to “\(url.lastPathComponent)”?"
        alert.informativeText = "Your changes will be lost if you don't save them."
        alert.addButton(withTitle: "Save")
        let dontSave = alert.addButton(withTitle: "Don't Save")
        dontSave.keyEquivalent = "d"
        dontSave.keyEquivalentModifierMask = .command
        alert.addButton(withTitle: "Cancel")
        switch await alert.beginSheetModal(for: window) {
        case .alertFirstButtonReturn:
            return await save(document)
        case .alertSecondButtonReturn:
            document.discardEdits()
            return true
        default:
            return false
        }
    }

    /// Saves, showing an alert if the save fails. True once the edits are on disk.
    private func save(_ document: DocumentViewController) async -> Bool {
        switch await document.save(prompts: self) {
        case .saved: return true
        case .cancelled: return false
        case .failed(let message):
            let alert = NSAlert()
            alert.messageText = message
            if let window { _ = await alert.beginSheetModal(for: window) }
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
        current?.close()
        current = nil
    }

    // MARK: Toolbar

    private static let openWith = NSToolbarItem.Identifier("openWith")
    private static let edit = NSToolbarItem.Identifier("edit")

    private func rebuildToolbar() {
        // A fresh identifier per rebuild: toolbars sharing an identifier sync their items across windows.
        let toolbar = NSToolbar(identifier: "doc-\(UUID().uuidString)")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        window?.toolbar = toolbar
        window?.toolbarStyle = .unified
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        guard let document = current else { return [Self.openWith] }
        let tools = document.commands.indices.filter { index in document.toolbarCommands.contains { $0.spec == document.commands[index].spec } }
        return [Self.openWith] + (document.editMode == .none ? [] : [Self.edit]) + [.flexibleSpace] + tools.map { NSToolbarItem.Identifier("command.\($0)") }
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
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
            return item
        }
        if identifier == Self.edit, let document = current {
            let button = NSButton(image: NSImage(systemSymbolName: "pencil.tip.crop.circle", accessibilityDescription: "Edit")!, target: self, action: #selector(toggleEditMode(_:)))
            button.setButtonType(.pushOnPushOff)
            button.bezelStyle = .toolbar
            button.state = document.isEditing ? .on : .off
            item.view = button
            item.label = "Edit"
            if case .unavailable(let reason) = document.editMode {
                button.isEnabled = false
                button.toolTip = reason
                item.toolTip = reason
            } else {
                item.toolTip = document.isEditing ? "Stop Editing (⌘E)" : "Edit (⌘E)"
            }
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
