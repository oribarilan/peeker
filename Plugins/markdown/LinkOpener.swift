import AppKit

/// Opens links from Markdown files, in the Peek panel on a click and in the Editor on a Cmd-click.
enum LinkOpener {
    /// Web pages and email. Any other link, such as `file:` or another app's scheme, could start an app from one click
    /// in a downloaded file, so it asks first.
    static func opensWithoutAsking(_ url: URL) -> Bool {
        ["http", "https", "mailto"].contains(url.scheme?.lowercased() ?? "")
    }

    /// The local file a link without a scheme points to, resolved against the folder of `file` (a `/` path starts at
    /// the disk's root), its fragment kept as the place to go and any query dropped. `#name` alone points to `file`
    /// itself. Nil for a link with a scheme, which `open` handles.
    static func resolve(_ destination: String, against file: URL) -> URL? {
        guard URL(string: destination)?.scheme == nil, let link = URL(string: destination, relativeTo: file),
              var parts = URLComponents(url: link.absoluteURL, resolvingAgainstBaseURL: false) else { return nil }
        parts.query = nil
        return parts.url
    }

    static func open(_ destination: String, from window: NSWindow?) {
        if let url = URL(string: destination) { open(url, from: window) }
    }

    /// Opens `url` with its default handler, asking first unless it's a web page or email. A link without a scheme,
    /// such as a relative path, does nothing.
    static func open(_ url: URL, from window: NSWindow?) {
        guard url.scheme != nil else { return }
        guard !opensWithoutAsking(url) else {
            NSWorkspace.shared.open(url)
            return
        }
        let alert = NSAlert()
        alert.messageText = "Open this link in another app?"
        alert.informativeText = url.absoluteString
        alert.addButton(withTitle: "Open")
        alert.addButton(withTitle: "Cancel")
        guard let window else {
            if alert.runModal() == .alertFirstButtonReturn { NSWorkspace.shared.open(url) }
            return
        }
        Task {
            if await alert.beginSheetModal(for: window) == .alertFirstButtonReturn { NSWorkspace.shared.open(url) }
        }
    }
}
