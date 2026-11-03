import AppKit

/// The colors Markdown and text views draw with. The host picks one from the config; views read `current` and
/// recolor on `didChange`. Every color is dynamic, so a light/dark switch needs nothing from the views.
@MainActor public struct TextTheme: Sendable {
    /// The config name, such as `tokyo-night`.
    public let id: String
    public let name: String
    /// Themes with the same group sit together in the pop-up, between separators.
    public let group: Int
    public let background, text, heading, marker, link, codeBackground, selection, cursor, findMatch: NSColor

    /// Set by the host. Setting another theme posts `didChange`.
    public static var current = TextTheme.system {
        didSet { if current.id != oldValue.id { NotificationCenter.default.post(name: didChange, object: nil) } }
    }

    public nonisolated static let didChange = Notification.Name("PeekerTextThemeDidChange")

    public static func named(_ id: String) -> TextTheme? { all.first { $0.id == id } }

    /// The ids of `all`, in order, for code off the main actor such as the config reader.
    public nonisolated static let ids = ["system", "paper", "slate", "graphite", "ink", "catppuccin", "tokyo-night", "high-contrast"]

    public static let system = TextTheme(
        id: "system", name: "System", group: 0, background: .textBackgroundColor, text: .labelColor, heading: .labelColor,
        marker: .tertiaryLabelColor, link: .linkColor, codeBackground: .quaternarySystemFill,
        selection: .selectedTextBackgroundColor, cursor: .textInsertionPointColor, findMatch: .findHighlightColor)

    /// In the order the pop-up lists them.
    public static let all: [TextTheme] = [
        system,
        palette("paper", "Paper", group: 1,
                light: [0xF7F3EA, 0x3B3A36, 0x2B2A27, 0xB3AB9B, 0x9A5B2E, 0xEDE5D3, 0xE6D9BF, 0x3B3A36, 0xF2D27A],
                dark: [0x23211D, 0xDCD5C8, 0xEFE8DA, 0x6E675C, 0xD49A6A, 0x2F2C26, 0x4A4234, 0xDCD5C8, 0x7A5F22]),
        palette("slate", "Slate", group: 1,
                light: [0xF2F4F7, 0x2F3640, 0x1F2630, 0xA3ADBA, 0x3B6EA8, 0xE4E9EF, 0xCCD8E8, 0x2F3640, 0xF1D88A],
                dark: [0x1B2028, 0xC9D1DC, 0xE3E9F1, 0x566172, 0x7FA7D9, 0x252C37, 0x33405A, 0xC9D1DC, 0x6B5A24]),
        palette("graphite", "Graphite", group: 1,
                light: [0xFAFAF9, 0x2E2E30, 0x2E2E30, 0xE6A39B, 0xD9473B, 0xF0EFED, 0xF6D5D0, 0xD9473B, 0xF5D47E],
                dark: [0x1F1F21, 0xDCDCDE, 0xF2F2F3, 0x9A554E, 0xF0766A, 0x2A2A2D, 0x4A3532, 0xF0766A, 0x6E5420]),
        palette("ink", "Ink", group: 1,
                light: [0xFCFCFA, 0x1F2A44, 0x14203A, 0xAAB1C3, 0x5B4FC4, 0xF0F1F5, 0xD9DCF2, 0x1F2A44, 0xF2DA8C],
                dark: [0x15161A, 0xE4E1DA, 0xF5F2EA, 0x5A5D68, 0xB5A8F0, 0x1F2026, 0x353A4A, 0xE4E1DA, 0x5E5226]),
        // Catppuccin Latte and Mocha, from github.com/catppuccin/palette (MIT).
        palette("catppuccin", "Catppuccin", group: 2,
                light: [0xEFF1F5, 0x4C4F69, 0x8839EF, 0x9CA0B0, 0x1E66F5, 0xE6E9EF, 0xCCD0DA, 0xDC8A78, 0xDF8E1D],
                dark: [0x1E1E2E, 0xCDD6F4, 0xCBA6F7, 0x6C7086, 0x89B4FA, 0x181825, 0x45475A, 0xF5E0DC, 0x7A6435]),
        // Tokyo Night Light and Night, from github.com/tokyo-night/tokyo-night-vscode-theme (MIT).
        palette("tokyo-night", "Tokyo Night", group: 2,
                light: [0xE6E7ED, 0x343B59, 0x2959AA, 0x888B94, 0x006C86, 0xDCDEE5, 0xD7D9E1, 0x363C4D, 0xE6C680],
                dark: [0x1A1B26, 0xA9B1D6, 0x7AA2F7, 0x51597D, 0x7DCFFF, 0x24283B, 0x2A2E40, 0xC0CAF5, 0x6B5A2F]),
        palette("high-contrast", "High Contrast", group: 3,
                light: [0xFFFFFF, 0x000000, 0x000000, 0x595959, 0x0039B3, 0xE8E8E8, 0xB4D5FF, 0x000000, 0xFFE14D],
                dark: [0x000000, 0xFFFFFF, 0xFFFFFF, 0xA6A6A6, 0x8AB8FF, 0x1F1F1F, 0x264F78, 0xFFFFFF, 0x8C6F00]),
    ]

    /// Roles in order: background, text, heading, marker, link, code background, selection, cursor, find match.
    private static func palette(_ id: String, _ name: String, group: Int, light: [UInt32], dark: [UInt32]) -> TextTheme {
        let colors = zip(light, dark).enumerated().map { index, pair in
            NSColor(name: "\(id).\(index)") { appearance in
                srgb(appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? pair.1 : pair.0)
            }
        }
        return TextTheme(id: id, name: name, group: group, background: colors[0], text: colors[1], heading: colors[2], marker: colors[3],
                         link: colors[4], codeBackground: colors[5], selection: colors[6], cursor: colors[7], findMatch: colors[8])
    }

    private nonisolated static func srgb(_ hex: UInt32) -> NSColor {
        NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}
