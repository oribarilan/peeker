import AppKit

/// A key plus modifiers, written in config as `cmd+shift+e`, `space` or `opt+space`.
struct Shortcut: Equatable {
    enum Key: Equatable {
        case character(Character)
        case space, escape, tab, enter
    }

    let key: Key
    let modifiers: NSEvent.ModifierFlags

    /// Which shortcuts a place takes: the quick-look key, a command, or an edit tool. The config and the Settings
    /// recorders both check them.
    enum Rules {
        /// The quick-look key: Space alone, or a key with Command, Option or Control.
        case quickLook
        /// A plugin command: always with Command, Option or Control.
        case command
        /// An edit tool: like a command, or a single letter or digit, which works only in Edit mode.
        case editTool

        /// Why `shortcut` isn't allowed here, or nil when it is. Shift alone doesn't count as a modifier, since it only
        /// types a capital letter.
        func refusal(for shortcut: Shortcut) -> String? {
            let hasModifier = !shortcut.modifiers.intersection([.command, .option, .control]).isEmpty
            switch self {
            case .quickLook:
                if shortcut == Shortcut(key: .space) || hasModifier { return nil }
                return "Use Space alone, or add Command, Option or Control."
            case .command:
                return hasModifier ? nil : "Add Command, Option or Control."
            case .editTool:
                if hasModifier { return nil }
                if case .character = shortcut.key { return nil }
                return "Use a letter or digit, or add Command, Option or Control."
            }
        }
    }

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
            default:
                guard key == nil, let named = Self.key(named: part) else { return nil }
                key = named
            }
        }
        guard let key else { return nil }
        self.init(key: key, modifiers: modifiers)
    }

    /// The key a config part names; nil for anything the keyboard can't press, so the shortcut could never fire.
    private static func key(named name: String) -> Key? {
        switch name {
        case "space": .space
        case "esc", "escape": .escape
        case "tab": .tab
        case "enter", "return": .enter
        default: name.count == 1 && ansiKeyCodes[name.first!] != nil ? .character(name.first!) : nil
        }
    }

    /// The key typed in `event`, or nil for a key the config can't write (arrows, function keys).
    init?(event: NSEvent) {
        let code = Int64(event.keyCode)
        let key: Key? = switch code {
        case 49: .space
        case 53: .escape
        case 48: .tab
        case 36: .enter
        default: Self.ansiKeyCodes.first { $0.value == code }.map { .character($0.key) }
        }
        guard let key else { return nil }
        self.init(key: key, modifiers: event.modifierFlags.intersection([.control, .option, .shift, .command]))
    }

    /// As written in the config, such as `ctrl+opt+shift+cmd+h`: modifiers in that order, then the key.
    var configText: String {
        let names: [(NSEvent.ModifierFlags, String)] = [(.control, "ctrl"), (.option, "opt"), (.shift, "shift"), (.command, "cmd")]
        let keyName = switch key {
        case .character(let c): String(c)
        case .space: "space"
        case .escape: "esc"
        case .tab: "tab"
        case .enter: "enter"
        }
        return (names.filter { modifiers.contains($0.0) }.map(\.1) + [keyName]).joined(separator: "+")
    }

    /// As menus show it, such as ⌃⌥⇧⌘H.
    var displayText: String {
        let symbols: [(NSEvent.ModifierFlags, String)] = [(.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")]
        let name = switch key {
        case .character(let c): String(c).uppercased()
        case .space: "Space"
        case .escape: "Esc"
        case .tab: "Tab"
        case .enter: "Return"
        }
        return symbols.filter { modifiers.contains($0.0) }.map(\.1).joined() + name
    }

    /// A key without Command, Option or Control, which only edit tools may use.
    var isSingleKey: Bool { modifiers.intersection([.command, .option, .control]).isEmpty }

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
