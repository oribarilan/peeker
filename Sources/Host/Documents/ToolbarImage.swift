import AppKit

/// A toolbar icon with its key beside it, "icon | key", drawn as one template image. The item stays a plain image item,
/// so it keeps the toolbar's glass, selected and greyed looks, overflow menu and Accessibility name.
enum ToolbarImage {
    /// The symbol alone when there's no key or captions are off; nil without a symbol.
    static func make(symbol: String?, name: String, key: Shortcut?, showsKey: Bool) -> NSImage? {
        guard let icon = symbol.flatMap({ NSImage(systemSymbolName: $0, accessibilityDescription: name) }) else { return nil }
        guard showsKey, let key else { return icon }
        let sized = icon.withSymbolConfiguration(.init(pointSize: 15, weight: .regular)) ?? icon
        let text = NSAttributedString(string: key.displayText, attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.black.withAlphaComponent(0.75),  // a template's alpha: a shade lighter than the icon
        ])
        let textSize = text.size()
        let gap: CGFloat = 6
        let height = max(sized.size.height, ceil(textSize.height))
        let size = NSSize(width: sized.size.width + gap * 2 + 1 + ceil(textSize.width), height: height)
        let image = NSImage(size: size, flipped: true) { _ in
            sized.draw(in: NSRect(origin: NSPoint(x: 0, y: (height - sized.size.height) / 2), size: sized.size))
            NSColor.black.withAlphaComponent(0.35).setFill()
            NSRect(x: sized.size.width + gap, y: height * 0.15, width: 1, height: height * 0.7).fill()
            text.draw(at: NSPoint(x: sized.size.width + gap * 2 + 1, y: (height - textSize.height) / 2))
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = name
        return image
    }
}
