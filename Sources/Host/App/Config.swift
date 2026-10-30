import Foundation
import UniformTypeIdentifiers

/// The user's settings, from `~/.config/peeker/config.json` (or `$PEEKER_CONFIG`). Every key is optional:
///
///     {
///       "$schema": "schema.json",
///       "quickLook": { "key": "space" },          // bare key: Finder only, not while typing; with modifiers: anywhere; "off"
///       "plugins": {
///         "image": { "enabled": false },
///         "pdf": { "commands": { "highlight": { "shortcut": "cmd+shift+h" } } }
///       },
///       "open": { "md": "markdown", "conf": "text", "noExtension": "text" }
///     }
struct Config {
    var disabled: Set<String> = []
    /// Lowercased file extension -> plugin id. `""` is files with no extension (`open.noExtension`).
    var routes: [String: String] = [:]
    /// "pluginID.commandID" -> shortcut override.
    var keys: [String: Shortcut] = [:]
    var quickLookKey: Shortcut? = Shortcut(key: .space)

    static var defaultURL: URL {
        if let path = ProcessInfo.processInfo.environment["PEEKER_CONFIG"] { return URL(filePath: path) }
        return FileManager.default.homeDirectoryForCurrentUser.appending(path: ".config/peeker/config.json")
    }

    /// Reads the file at `url`. A missing file means defaults; one that can't be read is a problem and no settings.
    static func load(from url: URL = defaultURL, plugins: [PluginEntry]) -> ConfigReading {
        do {
            return read(try Data(contentsOf: url), plugins: plugins)
        } catch CocoaError.fileReadNoSuchFile {
            return read(nil, plugins: plugins)
        } catch {
            return ConfigReading(config: nil, problems: [ConfigProblem(path: "", message: "The file can't be read: \(error.localizedDescription)")])
        }
    }

    /// Settings from a config file's bytes (nil: there is no file), checked against `plugins`. A key that's wrong is
    /// skipped and listed; only a file that isn't a JSON object leaves no settings at all.
    static func read(_ data: Data?, plugins: [PluginEntry]) -> ConfigReading {
        guard let data else { return ConfigReading(config: Config(), problems: []) }
        let root: JSONValue
        do {
            _ = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            root = try JSONDecoder().decode(JSONValue.self, from: data)
        } catch {
            let detail = (error as NSError).userInfo["NSDebugDescription"] as? String
            return ConfigReading(config: nil, problems: [ConfigProblem(path: "", message: "The file isn't valid JSON" + (detail.map { ": \($0)" } ?? "."))])
        }
        guard case .object(let sections) = root else {
            return ConfigReading(config: nil, problems: [ConfigProblem(path: "", message: "The file should be a JSON object, in braces.")])
        }
        var reader = ConfigReader(plugins: plugins)
        reader.read(sections)
        return ConfigReading(config: reader.config, problems: reader.problems)
    }
}

/// What reading a config file gave: settings to use (nil when the file couldn't be used at all, so the settings in
/// use should stay) and what was wrong with it.
struct ConfigReading {
    let config: Config?
    let problems: [ConfigProblem]
}

/// Something wrong in the config file: where (a key path such as `plugins.pdf.enabled`; empty for the whole file)
/// and what.
struct ConfigProblem: Hashable, Sendable {
    let path: String
    let message: String
}

/// Walks the file's sections, keeping what's valid and listing the rest.
private struct ConfigReader {
    let plugins: [PluginEntry]
    var config = Config()
    var problems: [ConfigProblem] = []

    init(plugins: [PluginEntry]) {
        self.plugins = plugins
    }

    mutating func read(_ sections: [String: JSONValue]) {
        for (key, value) in sorted(sections) {
            switch key {
            case "$schema": break
            case "quickLook": if let settings = object(value, at: key) { readQuickLook(settings) }
            case "plugins": if let entries = object(value, at: key) { readPlugins(entries) }
            case "open": if let routes = object(value, at: key) { readRoutes(routes) }
            default: unknown(key)
            }
        }
    }

    private mutating func readQuickLook(_ settings: [String: JSONValue]) {
        for (key, value) in sorted(settings) {
            let path = "quickLook.\(key)"
            guard key == "key" else { unknown(path); continue }
            guard let text = string(value, at: path) else { continue }
            if text == "off" { config.quickLookKey = nil }
            else if let shortcut = Shortcut(parsing: text) { config.quickLookKey = shortcut }
            else { problem(path, "“\(text)” isn't a key Peeker understands. Use one like space or opt+space, or off.") }
        }
    }

    private mutating func readPlugins(_ entries: [String: JSONValue]) {
        for (id, value) in sorted(entries) {
            let path = "plugins.\(id)"
            guard let plugin = plugins.first(where: { $0.id == id }) else {
                problem(path, "There's no plugin “\(id)”. Plugins: \(plugins.map(\.id).sorted().joined(separator: ", ")).")
                continue
            }
            guard let settings = object(value, at: path) else { continue }
            for (key, value) in sorted(settings) {
                switch key {
                case "enabled":
                    if let enabled = bool(value, at: "\(path).enabled"), !enabled { config.disabled.insert(id) }
                case "commands":
                    if let commands = object(value, at: "\(path).commands") { readCommands(commands, of: plugin, at: "\(path).commands") }
                default:
                    unknown("\(path).\(key)")
                }
            }
        }
    }

    private mutating func readCommands(_ commands: [String: JSONValue], of plugin: PluginEntry, at prefix: String) {
        for (command, value) in sorted(commands) {
            let path = "\(prefix).\(command)"
            guard plugin.commands.contains(where: { $0.id == command }) else {
                let known = plugin.commands.map(\.id)
                problem(path, "The \(plugin.name) plugin has no command “\(command)”" + (known.isEmpty ? "." : ". Its commands: \(known.joined(separator: ", "))."))
                continue
            }
            guard let settings = object(value, at: path) else { continue }
            for (key, value) in sorted(settings) {
                guard key == "shortcut" else { unknown("\(path).\(key)"); continue }
                guard let text = string(value, at: "\(path).shortcut") else { continue }
                if let shortcut = Shortcut(parsing: text) { config.keys["\(plugin.id).\(command)"] = shortcut }
                else { problem("\(path).shortcut", "“\(text)” isn't a shortcut Peeker understands. Use one like cmd+shift+h.") }
            }
        }
    }

    private mutating func readRoutes(_ routes: [String: JSONValue]) {
        for (key, value) in sorted(routes) {
            let path = "open.\(key)"
            guard let id = string(value, at: path) else { continue }
            guard let plugin = plugins.first(where: { $0.id == id }) else {
                problem(path, "There's no plugin “\(id)”. Plugins: \(plugins.map(\.id).sorted().joined(separator: ", ")).")
                continue
            }
            let ext = key == "noExtension" ? "" : key.lowercased()
            // Files macOS has no real type for may go to any plugin; a typed file only to one that can open its type.
            if let type = UTType(filenameExtension: ext), !ext.isEmpty, !type.isDynamic, type != .data,
               !plugin.fileTypes.contains(where: { type.conforms(to: $0) }) {
                problem(path, "The \(plugin.name) plugin can't open .\(ext) files, so this route never applies.")
                continue
            }
            config.routes[ext] = id
        }
    }

    // MARK: Values

    private mutating func object(_ value: JSONValue, at path: String) -> [String: JSONValue]? {
        if case .object(let object) = value { return object }
        problem(path, "Should be an object, in braces.")
        return nil
    }

    private mutating func string(_ value: JSONValue, at path: String) -> String? {
        if case .string(let string) = value { return string }
        problem(path, "Should be text, in quotes.")
        return nil
    }

    private mutating func bool(_ value: JSONValue, at path: String) -> Bool? {
        if case .bool(let bool) = value { return bool }
        problem(path, "Should be true or false.")
        return nil
    }

    private mutating func unknown(_ path: String) {
        problem(path, "\(path) is not a known setting.")
    }

    private mutating func problem(_ path: String, _ message: String) {
        problems.append(ConfigProblem(path: path, message: message))
    }

    /// File order is lost in decoding, so problems come in a stable, alphabetical order instead.
    private func sorted(_ object: [String: JSONValue]) -> [(String, JSONValue)] {
        object.sorted { $0.key < $1.key }
    }
}
