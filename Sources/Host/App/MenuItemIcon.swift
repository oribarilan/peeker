import AppKit

extension NSMenuItem {
    /// Shows the Finder icon of the file or app at `url` beside the title. macOS 27 hides menu item images unless an
    /// item asks to show its own; the property is set by name because the macOS 26 SDK, which CI builds with, lacks it.
    func showIcon(ofFileAt url: URL) {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 16, height: 16)
        image = icon
        if responds(to: NSSelectorFromString("setPreferredImageVisibility:")) { setValue(1, forKey: "preferredImageVisibility") }
    }
}
