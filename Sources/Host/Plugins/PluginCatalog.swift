import Foundation
import PeekerData
import PeekerImage
import PeekerKit
import PeekerMarkdown
import PeekerPDF
import PeekerTable
import PeekerText
import UniformTypeIdentifiers

/// One plugin as the host knows it before opening anything with it.
struct PluginEntry {
    let id: String
    let name: String
    let defaultExtensions: [String]
    /// The file types Open With offers it for when it isn't the file's owner.
    let readableTypes: [UTType]
    /// The SF Symbol for its Settings pane.
    let symbol: String
    /// Every tool the plugin can offer, which config shortcuts are checked against.
    let tools: [ToolSpec]
    let plugin: any Plugin.Type

    init(_ plugin: any Plugin.Type) {
        self.init(id: plugin.id, name: plugin.name, defaultExtensions: plugin.defaultExtensions, plugin: plugin)
    }

    /// For tests that route by made-up ids and extensions.
    init(id: String, name: String, defaultExtensions: [String], plugin: any Plugin.Type) {
        self.id = id
        self.name = name
        self.defaultExtensions = defaultExtensions
        readableTypes = plugin.readableTypes
        symbol = plugin.symbol
        tools = plugin.tools
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
    static let builtIn: [any Plugin.Type] = [ImagePlugin.self, PDFPlugin.self, MarkdownPlugin.self, TablePlugin.self, DataPlugin.self, TextPlugin.self]

    /// Applies a re-read config.
    func reload(config: Config) {
        self.config = config
        owners = config.owners(of: entries).owners
    }

    var enabled: [PluginEntry] { entries.filter { !config.disabled.contains($0.id) } }

    /// The plugin whose list has `url`'s extension, whether it's on or off. Nil for a folder or an extension no list has.
    func listing(_ url: URL) -> PluginEntry? {
        guard let key = Self.listEntry(for: url), let id = owners[key] else { return nil }
        return entries.first { $0.id == id }
    }

    /// The plugin that opens `url`: the one whose list has its extension, if it's enabled. Nil for a folder.
    func owner(for url: URL) -> PluginEntry? {
        guard let key = Self.listEntry(for: url), let id = owners[key] else { return nil }
        return enabled.first { $0.id == id }
    }

    /// What Open With offers for `url`: its owner first, then each other enabled plugin that reads the file's type, and
    /// `current`, the plugin the tab shows, while it's on.
    func openWithChoices(for url: URL, showing current: String?) -> [PluginEntry] {
        let owner = owner(for: url)
        let type = Self.contentType(of: url)
        let others = enabled.filter { entry in
            entry.id != owner?.id && (entry.id == current || entry.readableTypes.contains { type?.conforms(to: $0) == true })
        }
        return (owner.map { [$0] } ?? []) + others
    }

    /// The file's type as macOS sees it, which types a file with no extension by its contents. From the extension
    /// alone when the file can't be asked, such as a path with nothing there.
    private static func contentType(of url: URL) -> UTType? {
        let target = url.resolvingSymlinksInPath()
        return (try? target.resourceValues(forKeys: [.contentTypeKey]))?.contentType ?? UTType(filenameExtension: target.pathExtension)
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
