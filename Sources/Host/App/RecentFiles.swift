import AppKit

/// Fills File > Open Recent each time it opens. AppKit's own recent-documents menu opens files through NSDocument,
/// which Peeker doesn't use, so the items open through the app's usual path instead.
final class RecentFiles: NSObject, NSMenuDelegate {
    private let urls: () -> [URL]
    private let open: (URL) -> Void

    init(urls: @escaping () -> [URL] = { NSDocumentController.shared.recentDocumentURLs }, open: @escaping (URL) -> Void) {
        self.urls = urls
        self.open = open
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        for url in urls() {
            let item = NSMenuItem(title: url.lastPathComponent, action: #selector(openRecent(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = url
            item.image = NSWorkspace.shared.icon(forFile: url.path)
            item.image?.size = NSSize(width: 16, height: 16)
            menu.addItem(item)
        }
        if !menu.items.isEmpty { menu.addItem(.separator()) }
        let clear = NSMenuItem(title: "Clear Menu", action: #selector(NSDocumentController.clearRecentDocuments(_:)), keyEquivalent: "")
        clear.target = NSDocumentController.shared
        menu.addItem(clear)
    }

    @objc private func openRecent(_ sender: NSMenuItem) {
        if let url = sender.representedObject as? URL { open(url) }
    }
}
