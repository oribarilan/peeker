import AppKit

/// What to do about unsaved edits before opening the file in another app.
enum AppOpenChoice: Sendable {
    case save
    case openWithoutSaving
    case cancel
}

/// File > Open With: the plugins that read the file, then the other apps that open it, then Other….
extension DocumentWindowController: NSMenuDelegate {
    /// File > Open With: the submenu's plugins, by their tag in the choices. The submenu itself is filled as it's checked.
    @objc func reopenWithMenu(_ sender: NSMenuItem) {
        let candidates = openWithChoices
        guard sender.submenu == nil, candidates.indices.contains(sender.tag) else { return }
        Task { await reopen(with: candidates[sender.tag]) }
    }

    /// Fills File > Open With: the plugins (the check on the current one comes with each menu check), then the apps
    /// when `withApps`, then Other…. The apps are asked for only as the submenu opens, since that asks Launch Services.
    func fillOpenWith(_ menu: NSMenu, withApps: Bool = false) {
        menu.removeAllItems()
        for (index, entry) in openWithChoices.enumerated() {
            let item = NSMenuItem(title: entry.name, action: #selector(reopenWithMenu(_:)), keyEquivalent: "")
            item.tag = index
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let apps = withApps ? listApps(url) : []
        for app in apps {
            let item = NSMenuItem(title: app.name, action: #selector(chooseApp(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = app
            item.showIcon(ofFileAt: app.url)
            menu.addItem(item)
        }
        if !apps.isEmpty { menu.addItem(.separator()) }
        let other = NSMenuItem(title: "Other…", action: #selector(chooseOtherApp(_:)), keyEquivalent: "")
        other.target = self
        menu.addItem(other)
    }

    /// The app delegate makes the front window File > Open With's delegate, so the apps fill in as it opens.
    func menuNeedsUpdate(_ menu: NSMenu) {
        fillOpenWith(menu, withApps: true)
    }

    @objc func chooseApp(_ sender: NSMenuItem) {
        guard let app = sender.representedObject as? AppChoice else { return }
        Task { await open(in: app.url, named: app.name) }
    }

    /// Other…: any app, picked in a sheet. Defaults are Settings' job, so there's no Always checkbox.
    @objc func chooseOtherApp(_ sender: Any?) {
        guard let window, window.attachedSheet == nil else { return }
        AppChoices.pickOther(for: url, on: window, always: nil) { [weak self] app, _ in
            guard let self, let app else { return }
            Task { await self.open(in: app, named: AppChoice(url: app)?.name ?? app.deletingPathExtension().lastPathComponent) }
        }
    }

    /// Opens the file in the app at `app`, asking first about unsaved edits. The window stays open either way.
    func open(in app: URL, named name: String) async {
        finishTyping()
        if let document = current, document.isEdited {
            switch await askBeforeOpeningInApp(self, name) {
            case .save: guard await save(document) else { return }
            case .openWithoutSaving: break
            case .cancel: return
            }
        }
        openInApp(url, app)
    }

    func askBeforeOpeningInAppSheet(_ app: String) async -> AppOpenChoice {
        guard let window, window.attachedSheet == nil else { return .cancel }
        let alert = NSAlert()
        alert.messageText = "Save changes to “\(url.lastPathComponent)” before opening it in \(app)?"
        alert.informativeText = "Without saving, \(app) opens the file as it was last saved, and your changes stay here."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Open Without Saving")
        alert.addButton(withTitle: "Cancel")
        switch await alert.beginSheetModal(for: window) {
        case .alertFirstButtonReturn: return .save
        case .alertSecondButtonReturn: return .openWithoutSaving
        default: return .cancel
        }
    }
}
