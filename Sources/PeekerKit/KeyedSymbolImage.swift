import AppKit

/// A symbol with its key beside it, "icon | key", drawn as one template image whose Accessibility name is `name`, so
/// VoiceOver reads the tool, not its letter. Used by the toolbar and the markup strip.
public enum KeyedSymbolImage {
    public static func make(symbol: String, name: String, key: String, pointSize: CGFloat, fontSize: CGFloat) -> NSImage? {
        guard let icon = NSImage(systemSymbolName: symbol, accessibilityDescription: name) else { return nil }
        let sized = icon.withSymbolConfiguration(.init(pointSize: pointSize, weight: .regular)) ?? icon
        let text = NSAttributedString(
            string: key,
            attributes: [
                .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
                .foregroundColor: NSColor.black.withAlphaComponent(0.75),  // a template's alpha: a shade lighter than the icon
            ])
        let textSize = text.size()
        let gap = (pointSize * 0.4).rounded()
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
