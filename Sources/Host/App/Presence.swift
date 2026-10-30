import AppKit

/// Whether Peeker shows a Dock icon, menus and a place in Cmd+Tab: only while there's a window to work in. The
/// quick-look panel doesn't count, so pressing Space never makes a Dock icon appear.
enum Presence {
    static func policy(documentWindows: Int, settingsOpen: Bool) -> NSApplication.ActivationPolicy {
        documentWindows > 0 || settingsOpen ? .regular : .accessory
    }

    /// Switches when the policy changes. Coming forward as a regular app needs an activation, or the menu bar can
    /// keep showing the previous app's menus.
    static func update(documentWindows: Int, settingsOpen: Bool) {
        let policy = policy(documentWindows: documentWindows, settingsOpen: settingsOpen)
        guard NSApp.activationPolicy() != policy else { return }
        NSApp.setActivationPolicy(policy)
        if policy == .regular { NSApp.activate() }
    }
}
