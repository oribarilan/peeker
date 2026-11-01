import Foundation
import PeekerImage
import PeekerKit
import PeekerMarkdown
import PeekerPDF
import PeekerText

/// One plugin as the host knows it before opening anything with it.
struct PluginEntry {
    let id: String
    let name: String
    let defaultExtensions: [String]
    /// Every command the plugin can offer, which config shortcuts are checked against.
    let commands: [CommandSpec]
    let plugin: any Plugin.Type

    init(_ plugin: any Plugin.Type) {
        self.init(id: plugin.id, name: plugin.name, defaultExtensions: plugin.defaultExtensions, plugin: plugin)
    }

    /// For tests that route by made-up ids and extensions.
    init(id: String, name: String, defaultExtensions: [String], plugin: any Plugin.Type) {
        self.id = id
        self.name = name
        self.defaultExtensions = defaultExtensions
        commands = plugin.commands
        self.plugin = plugin
    }
}

/// Every plugin built into the app, and the user's choices of which are on and which extensions each opens.
final class PluginCatalog {
    let entries: [PluginEntry]
    private var config: Config
    /// Extension (or `noExtension`) -> id of the plugin that opens it.
    private var owners: [String: String]

    init(entries: [PluginEntry], config: Config) {
        self.entries = entries
        self.config = config
        owners = config.owners(of: entries).owners
    }

    /// The plugins built into the app, in sidebar order.
    static let builtIn: [any Plugin.Type] = [ImagePlugin.self, PDFPlugin.self, MarkdownPlugin.self, TextPlugin.self]

    /// Applies a re-read config.
    func reload(config: Config) {
        self.config = config
        owners = config.owners(of: entries).owners
    }

    var enabled: [PluginEntry] { entries.filter { !config.disabled.contains($0.id) } }

    /// The plugin that opens `url`: the one whose list has its extension, if it's enabled. Nil for a folder.
    func owner(for url: URL) -> PluginEntry? {
        guard let key = Self.listEntry(for: url), let id = owners[key] else { return nil }
        return enabled.first { $0.id == id }
    }

    /// What Open With offers for `url`: its owner first, then every other enabled plugin.
    func openWithChoices(for url: URL) -> [PluginEntry] {
        let owner = owner(for: url)
        return (owner.map { [$0] } ?? []) + enabled.filter { $0.id != owner?.id }
    }

    /// A recovery record's edits as plain text, from the plugin that wrote them; nil when they have none.
    func recoveryText(_ record: RecoveryRecord) -> String? {
        entries.first { $0.id == record.pluginID }?.plugin.recoveryText(from: record.editsData)
    }

    /// The list entry `url` matches: the lowercased extension of the file it points to, or `noExtension`. Nil for a
    /// folder, which no plugin opens.
    private static func listEntry(for url: URL) -> String? {
        let target = url.resolvingSymlinksInPath()
        if (try? target.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true { return nil }
        let ext = target.pathExtension.lowercased()
        return ext.isEmpty ? noExtension : ext
    }
}
