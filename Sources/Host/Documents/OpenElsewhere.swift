import AppKit

/// The question before a link opens a local file no enabled plugin opens, such as an app's document or a folder, in
/// its default app: one click in a downloaded file mustn't start an app.
enum OpenElsewhere {
    /// Asks as a sheet on `window`, showing the path. True after Open.
    static func confirm(_ url: URL, on window: NSWindow) async -> Bool {
        guard window.attachedSheet == nil else { return false }
        let alert = NSAlert()
        alert.messageText = "Open this link in another app?"
        alert.informativeText = url.path
        alert.addButton(withTitle: "Open")
        alert.addButton(withTitle: "Cancel")
        return await alert.beginSheetModal(for: window) == .alertFirstButtonReturn
    }
}
