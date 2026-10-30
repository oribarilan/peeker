import Foundation
import PeekerImage
import PeekerKit
import PeekerMarkdown
import PeekerPDF
import PeekerText
import UniformTypeIdentifiers

/// One plugin as the host knows it before opening anything with it.
struct PluginEntry {
    let id: String
    let name: String
    let fileTypes: [UTType]
    let plugin: any Plugin.Type

    init(_ plugin: any Plugin.Type) {
        self.init(id: plugin.id, name: plugin.name, fileTypes: plugin.fileTypes, plugin: plugin)
    }

    /// For tests that route by made-up ids and types.
    init(id: String, name: String, fileTypes: [UTType], plugin: any Plugin.Type) {
        self.id = id
        self.name = name
        self.fileTypes = fileTypes
        self.plugin = plugin
    }
}

/// Every plugin built into the app, and the user's enable/disable and routing choices.
final class PluginCatalog {
    let entries: [PluginEntry]
    private var config: Config

    init(entries: [PluginEntry], config: Config) {
        self.entries = entries
        self.config = config
    }

    /// The plugins built into the app.
    static let builtIn: [any Plugin.Type] = [ImagePlugin.self, MarkdownPlugin.self, PDFPlugin.self, TextPlugin.self]

    static func builtIn(config: Config) -> PluginCatalog {
        PluginCatalog(entries: builtIn.map(PluginEntry.init), config: config)
    }

    /// Applies a re-read config.
    func reload(config: Config) {
        self.config = config
    }

    var enabled: [PluginEntry] { entries.filter { !config.disabled.contains($0.id) } }

    /// Enabled plugins that support `url`, best first: exact type matches before supertype matches.
    /// Files macOS has no real type for (dynamic types, or plain `public.data`) go only to the plugin the config routes them to.
    func candidates(for url: URL) -> [PluginEntry] {
        guard let type = Self.contentType(of: url) else { return [] }
        if type.isDynamic || type == .data {
            return routedPlugin(for: url).map { [$0] } ?? []
        }
        let exact = enabled.filter { $0.fileTypes.contains(type) }
        let conforming = enabled.filter { entry in !entry.fileTypes.contains(type) && entry.fileTypes.contains { type.conforms(to: $0) } }
        return exact + conforming
    }

    /// The config route for the extension wins, but only if that plugin is enabled and supports the file.
    func defaultPlugin(for url: URL) -> PluginEntry? {
        let candidates = candidates(for: url)
        if let routed = routedPlugin(for: url), let entry = candidates.first(where: { $0.id == routed.id }) {
            return entry
        }
        return candidates.first
    }

    /// The enabled plugin the config names for this file's extension (`""` for none), whether or not it supports the file.
    private func routedPlugin(for url: URL) -> PluginEntry? {
        guard let id = config.routes[url.pathExtension.lowercased()] else { return nil }
        return enabled.first { $0.id == id }
    }

    /// A recovery record's edits as plain text, from the plugin that wrote them; nil when they have none.
    func recoveryText(_ record: RecoveryRecord) -> String? {
        entries.first { $0.id == record.pluginID }?.plugin.recoveryText(from: record.editsData)
    }

    /// A symlink's type is `public.symlink`, so the type comes from the file it points to.
    static func contentType(of url: URL) -> UTType? {
        (try? url.resolvingSymlinksInPath().resourceValues(forKeys: [.contentTypeKey]).contentType) ?? UTType(filenameExtension: url.pathExtension)
    }
}
