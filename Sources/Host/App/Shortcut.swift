import AppKit

/// A key plus modifiers, written in config as `cmd+shift+e`, `space` or `opt+space`.
struct Shortcut: Equatable {
    enum Key: Equatable {
        case character(Character)
        case space, escape, tab, enter
    }

    let key: Key
    let modifiers: NSEvent.ModifierFlags

    init(key: Key, modifiers: NSEvent.ModifierFlags = []) {
        self.key = key
        self.modifiers = modifiers
    }

    init?(parsing text: String) {
        var modifiers: NSEvent.ModifierFlags = []
        var key: Key?
        for part in text.lowercased().split(separator: "+").map({ $0.trimmingCharacters(in: .whitespaces) }) {
            switch part {
            case "cmd", "command": modifiers.insert(.command)
            case "shift": modifiers.insert(.shift)
            case "opt", "option", "alt": modifiers.insert(.option)
            case "ctrl", "control": modifiers.insert(.control)
            case "space" where key == nil: key = .space
            case "esc", "escape": key = key ?? .escape
            case "tab": key = key ?? .tab
            case "enter", "return": key = key ?? .enter
            case _ where part.count == 1 && key == nil: key = .character(part.first!)
            default: return nil
            }
        }
        guard let key else { return nil }
        self.init(key: key, modifiers: modifiers)
    }

    /// For menu items.
    var keyEquivalent: String {
        switch key {
        case .character(let c): String(c)
        case .space: " "
        case .escape: "\u{1b}"
        case .tab: "\t"
        case .enter: "\r"
        }
    }

    /// ANSI virtual key code, for the global event tap. Nil for characters the table doesn't cover.
    var keyCode: Int64? {
        switch key {
        case .space: 49
        case .escape: 53
        case .tab: 48
        case .enter: 36
        case .character(let c): Self.ansiKeyCodes[c]
        }
    }

    private static let ansiKeyCodes: [Character: Int64] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14,
        "r": 15, "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25, "7": 26, "-": 27,
        "8": 28, "0": 29, "o": 31, "u": 32, "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46, ".": 47, "/": 44,
    ]
}
