import AppKit

/// One entry in the menu of the Peek panel's button.
enum OpenWithItem: Equatable {
    case app(AppChoice)
    case peeker
    case alwaysPeeker
    case other
    case showInFinder
    case separator
}

enum PeekOpenWithMenu {
    /// The menu, in order: the apps that open the file (the Mac's default first, then A to Z, without Peeker, the
    /// button's own app or a second copy of one), then Peeker and Always Open in Peeker while another app is the
    /// default, then Other…, then Show in Finder.
    static func items(apps: [AppChoice], systemDefault: String?, buttonApp: String?, hasDefault: Bool, peekerID: String) -> [OpenWithItem] {
        let excluded: Set<String> = buttonApp.map { [peekerID, $0] } ?? [peekerID]
        let sorted = AppChoices.sorted(apps, systemDefault: systemDefault, excluding: excluded)
        var groups: [[OpenWithItem]] = [sorted.map(OpenWithItem.app)]
        groups.append((buttonApp != nil ? [.peeker] : []) + (hasDefault ? [.alwaysPeeker] : []))
        groups.append([.other])
        groups.append([.showInFinder])
        return Array(groups.filter { !$0.isEmpty }.joined(separator: [.separator]))
    }

    /// The Always checkbox's title in Other…'s picker; nil for a file with no extension, which can't have a default.
    static func alwaysTitle(for url: URL) -> String? {
        let ext = url.pathExtension.lowercased()
        return ext.isEmpty ? nil : "Always open .\(ext) files with this app"
    }
}

extension PeekPanel: NSMenuDelegate {
    /// The app the panel's default for `url`'s extension names, when it's installed.
    func buttonApp(for url: URL) -> AppChoice? {
        openWith[url.pathExtension.lowercased()].flatMap(appFor)
    }

    /// The main button's title, with its key while captions are on.
    func updateOpenButton(for url: URL) {
        let title = "Open in \(buttonApp(for: url)?.name ?? "Peeker")"
        openButton.title = showsKeys ? openKey.map { "\(title)  \($0.displayText)" } ?? title : title
        openButton.toolTip = Shortcut.tooltip(title: title, shortcut: openKey)
        layOutTitlebarButtons()
    }

    /// The button's main action: the default app for the file's type, or the Editor.
    func openDefault(_ url: URL) {
        if let app = buttonApp(for: url) { open(url, in: app.url) } else { dismiss(); onOpenInWindow?(url, nil) }
    }

    func choose(_ item: OpenWithItem, for url: URL) {
        switch item {
        case .app(let app): open(url, in: app.url)
        case .peeker:
            dismiss()
            onOpenInWindow?(url, nil)
        case .alwaysPeeker:
            dismiss()
            onSetDefault?(url.pathExtension.lowercased(), nil)
            onOpenInWindow?(url, nil)
        case .other: chooseOtherApp(for: url)
        case .showInFinder:
            dismiss()
            revealInFinder(url)
        case .separator: break
        }
    }

    private func open(_ url: URL, in app: URL) {
        dismiss()
        openInApp(url, app)
    }

    /// Fills the button's menu as it opens, so asking macOS for the apps costs nothing on Space.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        guard let url else { return }
        let apps = listApps(url)
        let items = PeekOpenWithMenu.items(
            apps: apps, systemDefault: AppChoices.systemDefault(for: url),
            buttonApp: buttonApp(for: url)?.bundleID, hasDefault: openWith[url.pathExtension.lowercased()] != nil,
            peekerID: Bundle.main.bundleIdentifier ?? "")
        for item in items {
            let menuItem: NSMenuItem
            switch item {
            case .separator: menu.addItem(.separator()); continue
            case .app(let app): menuItem = Self.appMenuItem(app)
            case .peeker: menuItem = NSMenuItem(title: "Peeker", action: #selector(menuChoice(_:)), keyEquivalent: "")
            case .alwaysPeeker: menuItem = NSMenuItem(title: "Always Open in Peeker", action: #selector(menuChoice(_:)), keyEquivalent: "")
            case .other: menuItem = NSMenuItem(title: "Other…", action: #selector(menuChoice(_:)), keyEquivalent: "")
            case .showInFinder: menuItem = Self.showInFinderItem(key: showInFinderKey)
            }
            menuItem.target = self
            menuItem.representedObject = MenuChoice(item)
            menu.addItem(menuItem)
        }
    }

    /// Show in Finder in the button's menu, showing its key, since no button in the title bar does.
    static func showInFinderItem(key: Shortcut?) -> NSMenuItem {
        let item = NSMenuItem(title: "Show in Finder", action: #selector(menuChoice(_:)), keyEquivalent: key?.keyEquivalent ?? "")
        item.keyEquivalentModifierMask = key?.modifiers ?? []
        return item
    }

    /// An app in the button's menu, with its icon; the panel sets its target and choice.
    static func appMenuItem(_ app: AppChoice) -> NSMenuItem {
        let item = NSMenuItem(title: app.name, action: #selector(menuChoice(_:)), keyEquivalent: "")
        item.showIcon(ofFileAt: app.url)
        return item
    }

    func menuWillOpen(_ menu: NSMenu) { isMenuOpen = true }
    func menuDidClose(_ menu: NSMenu) { isMenuOpen = false }

    @objc private func menuChoice(_ sender: NSMenuItem) {
        guard let url, let choice = sender.representedObject as? MenuChoice else { return }
        choose(choice.item, for: url)
    }

    /// Other…: a picker of apps as a sheet on the panel. Peeker comes forward for it, and Finder goes back in front
    /// on Cancel so the arrow keys keep browsing.
    private func chooseOtherApp(for url: URL) {
        guard attachedSheet == nil else { return }
        NSApp.activate()
        makeKey()
        AppChoices.pickOther(for: url, on: self, always: PeekOpenWithMenu.alwaysTitle(for: url)) { [weak self] app, always in
            guard let self else { return }
            guard let app else {
                NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first?.activate()
                return
            }
            if always, let id = Bundle(url: app)?.bundleIdentifier { onSetDefault?(url.pathExtension.lowercased(), id) }
            open(url, in: app)
        }
    }
}

/// Carries a menu item's choice; `representedObject` needs an object.
private final class MenuChoice {
    let item: OpenWithItem
    init(_ item: OpenWithItem) { self.item = item }
}
