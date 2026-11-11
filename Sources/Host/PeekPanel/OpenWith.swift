import AppKit
import UniformTypeIdentifiers

/// An installed app the Peek panel can open a file with.
nonisolated struct AppChoice: Equatable, Sendable {
    let bundleID: String
    let name: String
    let url: URL

    init(bundleID: String, name: String, url: URL) {
        self.bundleID = bundleID
        self.name = name
        self.url = url
    }

    /// The app at `url`; nil when it has no bundle ID.
    init?(url: URL) {
        guard let id = Bundle(url: url)?.bundleIdentifier else { return nil }
        let name = FileManager.default.displayName(atPath: url.path)
        self.init(bundleID: id, name: name.hasSuffix(".app") ? String(name.dropLast(4)) : name, url: url)
    }

    static func installed(bundleID: String) -> AppChoice? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID).flatMap(AppChoice.init(url:))
    }
}

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
        var seen: Set<String> = [peekerID]
        if let buttonApp { seen.insert(buttonApp) }
        let unique = apps.filter { seen.insert($0.bundleID).inserted }
        let sorted = unique.sorted { a, b in
            if (a.bundleID == systemDefault) != (b.bundleID == systemDefault) { return a.bundleID == systemDefault }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
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

    /// The main button's title and the folder button's image, each with its key while captions are on.
    func updateOpenButton(for url: URL) {
        let title = "Open in \(buttonApp(for: url)?.name ?? "Peeker")"
        openButton.title = showsKeys ? openKey.map { "\(title)  \($0.displayText)" } ?? title : title
        openButton.toolTip = Shortcut.tooltip(title: title, shortcut: openKey)
        finderButton.image = ToolbarImage.make(symbol: "folder", name: "Show in Finder", key: showInFinderKey, showsKey: showsKeys)
        finderButton.toolTip = Shortcut.tooltip(title: "Show in Finder", shortcut: showInFinderKey)
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
            apps: apps, systemDefault: NSWorkspace.shared.urlForApplication(toOpen: url).flatMap { Bundle(url: $0)?.bundleIdentifier },
            buttonApp: buttonApp(for: url)?.bundleID, hasDefault: openWith[url.pathExtension.lowercased()] != nil,
            peekerID: Bundle.main.bundleIdentifier ?? "")
        for item in items {
            let menuItem: NSMenuItem
            switch item {
            case .separator: menu.addItem(.separator()); continue
            case .app(let app):
                menuItem = NSMenuItem(title: app.name, action: #selector(menuChoice(_:)), keyEquivalent: "")
                let icon = NSWorkspace.shared.icon(forFile: app.url.path)
                icon.size = NSSize(width: 16, height: 16)
                menuItem.image = icon
            case .peeker: menuItem = NSMenuItem(title: "Peeker", action: #selector(menuChoice(_:)), keyEquivalent: "")
            case .alwaysPeeker: menuItem = NSMenuItem(title: "Always Open in Peeker", action: #selector(menuChoice(_:)), keyEquivalent: "")
            case .other: menuItem = NSMenuItem(title: "Other…", action: #selector(menuChoice(_:)), keyEquivalent: "")
            case .showInFinder: menuItem = NSMenuItem(title: "Show in Finder", action: #selector(menuChoice(_:)), keyEquivalent: "")
            }
            menuItem.target = self
            menuItem.representedObject = MenuChoice(item)
            menu.addItem(menuItem)
        }
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
        let picker = NSOpenPanel()
        picker.directoryURL = URL(filePath: "/Applications", directoryHint: .isDirectory)
        picker.allowedContentTypes = [.application]
        picker.treatsFilePackagesAsDirectories = false
        picker.message = "Choose an app to open “\(url.lastPathComponent)”."
        picker.prompt = "Open"
        var always: NSButton?
        if let title = PeekOpenWithMenu.alwaysTitle(for: url) {
            let box = NSButton(checkboxWithTitle: title, target: nil, action: nil)
            box.sizeToFit()
            let holder = NSView(frame: NSRect(x: 0, y: 0, width: box.frame.width + 40, height: box.frame.height + 16))
            box.frame.origin = NSPoint(x: 20, y: 8)
            holder.addSubview(box)
            picker.accessoryView = holder
            picker.isAccessoryViewDisclosed = true
            always = box
        }
        NSApp.activate()
        makeKey()
        picker.beginSheetModal(for: self) { [weak self] response in
            guard let self else { return }
            guard response == .OK, let app = picker.url else {
                NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first?.activate()
                return
            }
            if always?.state == .on, let id = Bundle(url: app)?.bundleIdentifier { onSetDefault?(url.pathExtension.lowercased(), id) }
            open(url, in: app)
        }
    }
}

/// Carries a menu item's choice; `representedObject` needs an object.
private final class MenuChoice {
    let item: OpenWithItem
    init(_ item: OpenWithItem) { self.item = item }
}
