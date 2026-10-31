import Foundation
import PeekerKit

/// The user's settings, from `~/.config/peeker/config.json` (or `$PEEKER_CONFIG`). Every key is optional:
///
///     {
///       "$schema": "schema.json",
///       "quickLook": { "key": "space" },          // bare key: Finder only, not while typing; with modifiers: anywhere; "off"
///       "plugins": {
///         "image": { "enabled": false },
///         "text": { "extensions": ["txt", "md", "noExtension"] },   // replaces the plugin's default list
///         "pdf": { "commands": { "highlight": { "shortcut": "cmd+shift+h" } } }
///       }
///     }
struct Config: Equatable {
    var disabled: Set<String> = []
    /// Plugin id -> the extensions the config gives it in place of its default list: lowercase, no dot.
    var extensions: [String: [String]] = [:]
    /// "pluginID.commandID" -> shortcut override.
    var keys: [String: Shortcut] = [:]
    var quickLookKey: Shortcut? = Shortcut(key: .space)

    /// Which plugin opens each extension (or `noExtension`), from every plugin's configured or default list, taken in
    /// `plugins` order. An extension in more than one list stays with the plugin whose default list has it, or else
    /// the first; each other list loses it, with a problem. A disabled plugin keeps its extensions, so turning it off
    /// hands nothing to another plugin.
    func owners(of plugins: [PluginEntry]) -> (owners: [String: String], problems: [ConfigProblem]) {
        var owners: [String: PluginEntry] = [:]
        var problems: [ConfigProblem] = []
        for plugin in plugins {
            for ext in extensions[plugin.id] ?? plugin.defaultExtensions {
                guard let holder = owners[ext], holder.id != plugin.id else {
                    owners[ext] = plugin
                    continue
                }
                let pluginIsDefault = plugin.defaultExtensions.contains(ext) && !holder.defaultExtensions.contains(ext)
                let (winner, loser) = pluginIsDefault ? (plugin, holder) : (holder, plugin)
                owners[ext] = winner
                problems.append(ConfigProblem(path: "plugins.\(loser.id).extensions",
                                              message: "“\(ext)” belongs to the \(winner.name) plugin, so \(loser.name) doesn't open it."))
            }
        }
        return (owners.mapValues(\.id), problems)
    }

    /// `text` as an extension-list entry: lowercased, with one leading dot dropped, or `noExtension` as is. Nil when
    /// it's empty or has a dot, slash or space.
    static func extensionEntry(_ text: String) -> String? {
        if text == noExtension { return text }
        let bare = text.hasPrefix(".") ? text.dropFirst() : Substring(text)
        guard !bare.isEmpty, !bare.contains(where: { $0 == "." || $0 == "/" || $0.isWhitespace }) else { return nil }
        return bare.lowercased()
    }

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
        return ConfigReading(config: reader.config, problems: reader.problems + reader.config.owners(of: plugins).problems)
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
                case "extensions":
                    readExtensions(value, of: plugin, at: "\(path).extensions")
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
                guard let shortcut = Shortcut(parsing: text) else {
                    problem("\(path).shortcut", "“\(text)” isn't a shortcut Peeker understands. Use one like cmd+shift+h.")
                    continue
                }
                let isEditTool = plugin.commands.first { $0.id == command }?.isEditTool == true
                if let refusal = (isEditTool ? KeyRecorderRules.editTool : .command).refusal(for: shortcut) {
                    problem("\(path).shortcut", "“\(text)” can't be used here. \(refusal)")
                } else {
                    config.keys["\(plugin.id).\(command)"] = shortcut
                }
            }
        }
    }

    private mutating func readExtensions(_ value: JSONValue, of plugin: PluginEntry, at path: String) {
        guard case .array(let items) = value else {
            problem(path, "Should be a list of extensions, in brackets.")
            return
        }
        var list: [String] = []
        for item in items {
            guard case .string(let text) = item else {
                problem(path, "Each extension should be text, in quotes.")
                continue
            }
            guard let ext = Config.extensionEntry(text) else {
                problem(path, "“\(text)” isn't an extension. Write one like md, without the dot, or noExtension.")
                continue
            }
            if !list.contains(ext) { list.append(ext) }
        }
        config.extensions[plugin.id] = list
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
