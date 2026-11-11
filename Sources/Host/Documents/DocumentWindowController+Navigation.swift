import AppKit
import PeekerKit

/// Following links in an Editor tab: where each goes, the tab's history with Back and Forward, and the trail.
extension DocumentWindowController {
    enum Arrival {
        case place(String)
        case position(any Sendable)
    }

    static let back = NSToolbarItem.Identifier("back")
    static let forward = NSToolbarItem.Identifier("forward")
    static let showInFinder = NSToolbarItem.Identifier("showInFinder")
    /// Peeker's own sidebar button, in place of the system's, so it can show its key.
    static let sidebar = NSToolbarItem.Identifier("sidebar")

    private var following: (any LinkFollowing)? { current?.pluginDocument as? any LinkFollowing }

    /// Takes a link to a local file from the tab's document.
    func follow(_ link: URL) async {
        guard let plugin = current?.entry.id else { return }
        let route = LinkRoute(
            link: link, from: url, plugin: plugin, owner: { [catalog] in catalog.owner(for: $0)?.id },
            isOpenElsewhere: { [weak self] in self?.otherWindow($0) != nil })
        switch route {
        case .missing: beep()
        case .stay: break
        case .place(let name): await jump(to: name)
        case .bringForward(let file): if let other = otherWindow(file) { bringForward(other) }
        case .sameTab(let file, let place): await show(NavigationHistory.Entry(url: file, pluginID: plugin, place: place), movingTo: nil)
        case .ownTab(let file, let place): openInOwnTab?(file, place)
        case .ask(let file): if await confirmOpenElsewhere(self, file) { NSWorkspace.shared.open(file) }
        }
    }

    /// Goes to a place in the document shown now, adding it to the history; beeps when there's no such place.
    func jump(to name: String) async {
        guard let document = following, let plugin = current?.entry.id else { return beep() }
        let position = document.position
        guard let title = await document.go(to: name) else { return beep() }
        guard document === following else { return }
        history.record(position)
        history.push(NavigationHistory.Entry(url: url, pluginID: plugin, place: name, title: title))
        navigationChanged()
    }

    @objc func goBack(_ sender: Any?) {
        Task { await move(to: history.index - 1) }
    }

    @objc func goForward(_ sender: Any?) {
        Task { await move(to: history.index + 1) }
    }

    /// Back, Forward and the trail: makes the entry at `target` current. Within the file shown, only the view moves.
    func move(to target: Int) async {
        guard target != history.index, history.entries.indices.contains(target) else { return }
        let entry = history.entries[target]
        guard LinkRoute.sameFile(entry.url, url), entry.pluginID == current?.entry.id else { return await show(entry, movingTo: target) }
        guard let document = following else { return }
        history.record(document.position)
        history.move(to: target)
        if let position = entry.position { document.restore(position) } else if let place = entry.place { _ = await document.go(to: place) }
        navigationChanged()
    }

    /// Shows another file in the tab once unsaved edits are resolved: a new place when `target` is nil, else the
    /// history's entry at `target`. A file that's gone or whose plugin is off beeps; one another window shows comes
    /// forward instead.
    private func show(_ entry: NavigationHistory.Entry, movingTo target: Int?) async {
        guard FileManager.default.fileExists(atPath: entry.url.path),
            let plugin = catalog.enabled.first(where: { $0.id == entry.pluginID })
        else { return beep() }
        if let other = otherWindow(entry.url) { return bringForward(other) }
        if let position = following?.position { history.record(position) }
        guard await resolveUnsavedEdits() else { return }
        if let target { history.move(to: target) } else { history.push(entry) }
        pendingArrival = entry.position.map { .position($0) } ?? entry.place.map { .place($0) }
        show(with: plugin, file: entry.url)
        navigationChanged()
    }

    /// Once a document's content is on screen, takes it where the link or the history said.
    func arrive(_ document: DocumentViewController) {
        guard document === current, let arrival = pendingArrival else { return }
        pendingArrival = nil
        guard let following else { return }
        switch arrival {
        case .position(let position):
            following.restore(position)
        case .place(let name):
            let index = history.index
            Task {
                guard let title = await following.go(to: name) else { return beep() }
                history.setTitle(title, at: index)
                navigationChanged()
            }
        }
    }

    // MARK: Controls

    /// Back and Forward show while the document follows links or the tab has somewhere to go.
    var showsBackAndForward: Bool { following != nil || history.entries.count > 1 }

    /// The sidebar button, Back and Forward, and Show in Finder: the host's own toolbar buttons, with their menu keys
    /// in the tooltips.
    func navigationItem(_ identifier: NSToolbarItem.Identifier) -> NSToolbarItem? {
        let (title, symbol, key, action): (String, String, Shortcut?, Selector)
        switch identifier {
        case Self.sidebar: (title, symbol, key, action) = ("Sidebar", "sidebar.left", MainMenu.sidebarKey, #selector(toggleSidebar(_:)))
        case Self.back: (title, symbol, key, action) = ("Back", "chevron.left", MainMenu.backKey, #selector(goBack(_:)))
        case Self.forward: (title, symbol, key, action) = ("Forward", "chevron.right", MainMenu.forwardKey, #selector(goForward(_:)))
        case Self.showInFinder: (title, symbol, key, action) = ("Show in Finder", "folder", nil, #selector(showInFinder(_:)))
        default: return nil
        }
        let item = NSToolbarItem(itemIdentifier: identifier)
        // No caption: beside the icon it would make the sidebar button too wide for the space above the sidebar.
        item.image = ToolbarImage.make(symbol: symbol, name: title, key: key, showsKey: false)
        item.label = title
        item.toolTip = Shortcut.tooltip(title: title, shortcut: key)
        item.target = self
        item.action = action
        return item
    }

    /// Greys out Back and Forward as the history allows, and shows the trail while there's more than one place.
    func navigationChanged() {
        window?.toolbar?.validateVisibleItems()
        let shows = history.entries.count > 1
        if shows, trailAccessory == nil, let window {
            let trail = HistoryTrail()
            trail.onSelect = { [weak self] index in Task { await self?.move(to: index) } }
            let accessory = NSTitlebarAccessoryViewController()
            accessory.view = trail
            accessory.layoutAttribute = .bottom
            window.addTitlebarAccessoryViewController(accessory)
            trailAccessory = accessory
        }
        trailAccessory?.isHidden = !shows
        (trailAccessory?.view as? HistoryTrail)?.show(history)
    }
}
