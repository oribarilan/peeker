import AppKit
import PeekerKit

extension Config {
    /// Applies the config's look: the app's appearance, and the text theme and the appearance text areas draw it in.
    /// Changes nothing that's already as the config says, so saving another setting doesn't redraw every window.
    @MainActor func applyLooks() {
        let app = Self.appearance(named: appearance)
        if NSApplication.shared.appearance?.name != app?.name { NSApplication.shared.appearance = app }
        TextTheme.appearance = Self.appearance(named: textAppearance)
        TextTheme.current = theme
    }

    /// Light or dark as an appearance; anything else (system, app) is nil, which follows the Mac or the app.
    static func appearance(named name: String) -> NSAppearance? {
        switch name {
        case "light": NSAppearance(named: .aqua)
        case "dark": NSAppearance(named: .darkAqua)
        default: nil
        }
    }
}
