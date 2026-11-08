import AppKit
import PeekerKit

/// A toolbar icon with its key beside it, "icon | key", drawn as one template image. The item stays a plain image item,
/// so it keeps the toolbar's glass, selected and greyed looks, overflow menu and Accessibility name.
enum ToolbarImage {
    /// The symbol alone when there's no key or captions are off; nil without a symbol.
    static func make(symbol: String?, name: String, key: Shortcut?, showsKey: Bool) -> NSImage? {
        guard let symbol, let icon = NSImage(systemSymbolName: symbol, accessibilityDescription: name) else { return nil }
        guard showsKey, let key else { return icon }
        return KeyedSymbolImage.make(symbol: symbol, name: name, key: key.displayText, pointSize: 15, fontSize: 12) ?? icon
    }
}
