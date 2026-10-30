import Foundation
import os
import UniformTypeIdentifiers

/// One plugin as the host knows it before (and without) starting it.
struct PluginEntry {
    let manifest: PluginManifest
    /// Where plugin executables live: the app's Contents/Helpers, which code signing covers.
    let helpers: URL
    var id: String { manifest.id }
    var fileTypes: [UTType] { manifest.types.map { UTType($0) ?? UTType(importedAs: $0) } }
    var executable: URL { helpers.appending(path: manifest.executable) }
}

/// Every shipped plugin, the user's enable/disable and routing choices, and the plugin processes (started on demand).
final class PluginCatalog {
    let entries: [PluginEntry]
    private var config: Config
    private var processes: [String: PluginProcess] = [:]
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "dev.previewpp", category: "plugins")

    init(entries: [PluginEntry], config: Config) {
        self.entries = entries
        self.config = config
    }

    /// Reads `Resources/Plugins/<id>/manifest.json` from the app bundle.
    static func load(from bundle: Bundle, config: Config) -> PluginCatalog {
        let manifests = bundle.resourceURL!.appending(path: "Plugins")
        let helpers = bundle.bundleURL.appending(path: "Contents/Helpers")
        let folders: [URL]
        do { folders = try FileManager.default.contentsOfDirectory(at: manifests, includingPropertiesForKeys: nil) } catch {
            log.error("can't list plugins in \(manifests.path, privacy: .public): \(error, privacy: .public)")
            folders = []
        }
        let entries = folders.sorted { $0.lastPathComponent < $1.lastPathComponent }.compactMap { folder -> PluginEntry? in
            do {
                let manifest = try JSONDecoder().decode(PluginManifest.self, from: Data(contentsOf: folder.appending(path: "manifest.json")))
                return PluginEntry(manifest: manifest, helpers: helpers)
            } catch {
                log.warning("skipping \(folder.lastPathComponent, privacy: .public): \(error, privacy: .public)")
                return nil
            }
        }
        return PluginCatalog(entries: entries, config: config)
    }

    /// Applies a re-read config. Running plugin processes keep their idle timeout; new ones use the new value.
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

    func process(for entry: PluginEntry) -> PluginProcess {
        if let existing = processes[entry.id] { return existing }
        let process = PluginProcess(entry: entry, idleSeconds: config.pluginIdleSeconds)
        processes[entry.id] = process
        return process
    }

    /// A symlink's type is `public.symlink`, so the type comes from the file it points to.
    static func contentType(of url: URL) -> UTType? {
        (try? url.resolvingSymlinksInPath().resourceValues(forKeys: [.contentTypeKey]).contentType) ?? UTType(filenameExtension: url.pathExtension)
    }
}
