import AppKit
import UniformTypeIdentifiers

/// What a plugin declares about itself. The host routes files by `fileTypes`, using UTType conformance.
public struct PluginManifest: Sendable {
    public let id: String
    public let name: String
    public let fileTypes: [UTType]

    public init(id: String, name: String, fileTypes: [UTType]) {
        self.id = id
        self.name = name
        self.fileTypes = fileTypes
    }
}

/// A format "mini-app". One instance per plugin; `open` is called once per tab.
///
/// Native plugins (compiled into the host or loaded from a bundle) conform directly.
/// Web and process plugins are adapted to this protocol by the host.
public protocol Plugin: AnyObject {
    static var manifest: PluginManifest { get }
    init()
    func open(_ url: URL, host: any PluginHost) throws -> Viewer
}

/// Services the host offers a viewer.
public protocol PluginHost: AnyObject {
    /// Call once when the first content is on screen. Only needed for `Readiness.reportedByPlugin`.
    func contentDidBecomeReady()
    /// Show a plugin-level failure in place of the content (e.g. a crashed helper process).
    func viewerDidFail(_ message: String)
}

/// Whether the host may treat the content as ready as soon as it is displayed.
public enum Readiness: Sendable {
    case immediate
    case reportedByPlugin
}

/// What a plugin hands back for one open file: the content view plus its contributions to host chrome.
public struct Viewer {
    public let content: NSViewController
    public let sidebar: NSViewController?
    public let commands: [Command]
    public let readiness: Readiness
    public let onClose: (() -> Void)?

    public init(
        content: NSViewController,
        sidebar: NSViewController? = nil,
        commands: [Command] = [],
        readiness: Readiness = .immediate,
        onClose: (() -> Void)? = nil
    ) {
        self.content = content
        self.sidebar = sidebar
        self.commands = commands
        self.readiness = readiness
        self.onClose = onClose
    }
}

/// A plugin action the host surfaces in the toolbar and the Commands menu.
/// `id` is stable so users can rebind it from the config file.
public struct Command {
    public let id: String
    public let title: String
    public let symbolName: String?
    public let shortcut: Shortcut?
    public let run: () -> Void

    public init(id: String, title: String, symbolName: String? = nil, shortcut: Shortcut? = nil, run: @escaping () -> Void) {
        self.id = id
        self.title = title
        self.symbolName = symbolName
        self.shortcut = shortcut
        self.run = run
    }
}

public struct Shortcut: Sendable, Equatable {
    public let key: String
    public let modifiers: NSEvent.ModifierFlags

    public init(_ key: String, _ modifiers: NSEvent.ModifierFlags = .command) {
        self.key = key
        self.modifiers = modifiers
    }

    /// Parses config syntax such as `cmd+shift+e`. Returns nil for anything it does not understand.
    public init?(parsing text: String) {
        var modifiers: NSEvent.ModifierFlags = []
        var key: String?
        for part in text.lowercased().split(separator: "+").map({ $0.trimmingCharacters(in: .whitespaces) }) {
            switch part {
            case "cmd", "command": modifiers.insert(.command)
            case "shift": modifiers.insert(.shift)
            case "opt", "option", "alt": modifiers.insert(.option)
            case "ctrl", "control": modifiers.insert(.control)
            case _ where part.count == 1 && key == nil: key = part
            default: return nil
            }
        }
        guard let key else { return nil }
        self.init(key, modifiers)
    }
}

public enum PluginError: LocalizedError {
    case unreadable(URL)

    public var errorDescription: String? {
        switch self {
        case .unreadable(let url): "Could not read \(url.lastPathComponent)"
        }
    }
}
