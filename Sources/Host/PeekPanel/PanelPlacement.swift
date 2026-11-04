import AppKit

/// Where the Peek panel opens on a display: at its saved frame when that lies on the display, else at the saved size
/// centered there, else at the default size centered there.
enum PanelPlacement {
    static let minimumSize = NSSize(width: 400, height: 300)
    /// The default is this share of the display's visible area, capped at `maximumDefault`.
    private static let defaultShare = (width: 0.55, height: 0.75)
    private static let maximumDefault = NSSize(width: 900, height: 700)

    /// The frame for a display whose visible area is `screen`, given the saved frame, if any. A saved frame smaller than
    /// the minimum (an unreadable preference reads as zero) is ignored.
    static func frame(saved: NSRect?, screen: NSRect) -> NSRect {
        let saved = saved.flatMap { $0.width >= minimumSize.width && $0.height >= minimumSize.height ? $0 : nil }
        if let saved, screen.contains(saved) { return saved }
        if let saved, saved.width <= screen.width, saved.height <= screen.height { return centered(saved.size, on: screen) }
        return centered(defaultSize(for: screen), on: screen)
    }

    static func defaultSize(for screen: NSRect) -> NSSize {
        NSSize(width: max(minimumSize.width, min((screen.width * defaultShare.width).rounded(), maximumDefault.width)),
               height: max(minimumSize.height, min((screen.height * defaultShare.height).rounded(), maximumDefault.height)))
    }

    private static func centered(_ size: NSSize, on screen: NSRect) -> NSRect {
        NSRect(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2, width: size.width, height: size.height)
    }
}
