import AppKit
import os

/// The user's dotfile: `~/.config/previewpp/config`, or `$PPP_CONFIG`.
///
///     # comments start with #
///     disable = image                 # plugin ids to turn off
///     open.md = markdown              # default plugin per file extension; for a type macOS knows, it must support it
///     open.conf = text                # extensions macOS has no type for go only to the plugin you name; no other is offered
///     open.none = text                # same, for files with no extension (.zshrc, .env)
///     key.pdf.highlight = cmd+shift+h # rebind a plugin command
///     quicklook.key = space           # bare key: Finder only, not while typing; with modifiers: anywhere; "off" to disable
///     plugin.idle = 60                # seconds an unused plugin process stays alive
///
/// Preview++ > Reload Config re-reads the file. It applies to documents opened afterwards; open ones keep their settings.
struct Config {
    var disabled: Set<String> = []
    /// Lowercased file extension -> plugin id. `""` is files with no extension (`open.none`).
    var routes: [String: String] = [:]
    /// "pluginID.commandID" -> shortcut override.
    var keys: [String: Shortcut] = [:]
    var quickLookKey: Shortcut? = Shortcut(key: .space)
    var pluginIdleSeconds: TimeInterval = 60

    static var defaultURL: URL {
        if let path = ProcessInfo.processInfo.environment["PPP_CONFIG"] { return URL(filePath: path) }
        return FileManager.default.homeDirectoryForCurrentUser.appending(path: ".config/previewpp/config")
    }

    /// A missing file means defaults; a file that exists but can't be read throws.
    static func load(from url: URL = defaultURL) throws -> Config {
        guard FileManager.default.fileExists(atPath: url.path) else { return Config() }
        return Config(parsing: try String(contentsOf: url, encoding: .utf8))
    }

    init() {}

    init(parsing text: String) {
        for (number, rawLine) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let line = rawLine.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)[0].trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            let parts = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2, !parts[1].isEmpty else {
                Self.warn("line \(number + 1): expected key = value")
                continue
            }
            let (key, value) = (parts[0], parts[1])
            switch key {
            case "disable":
                disabled.formUnion(value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
            case "quicklook.key":
                if value == "off" { quickLookKey = nil }
                else if let shortcut = Shortcut(parsing: value) { quickLookKey = shortcut }
                else { Self.warn("line \(number + 1): can't parse key '\(value)'") }
            case "plugin.idle":
                if let seconds = TimeInterval(value), seconds >= 0 { pluginIdleSeconds = seconds }
                else { Self.warn("line \(number + 1): plugin.idle needs seconds") }
            case _ where key.hasPrefix("open."):
                let ext = String(key.dropFirst(5)).lowercased()
                routes[ext == "none" ? "" : ext] = value
            case _ where key.hasPrefix("key."):
                if let shortcut = Shortcut(parsing: value) { keys[String(key.dropFirst(4))] = shortcut }
                else { Self.warn("line \(number + 1): can't parse shortcut '\(value)'") }
            default:
                Self.warn("line \(number + 1): unknown key '\(key)'")
            }
        }
    }

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "dev.previewpp", category: "config")

    private static func warn(_ message: String) {
        log.warning("\(message, privacy: .public)")
    }
}

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
