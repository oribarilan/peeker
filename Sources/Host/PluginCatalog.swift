import Foundation
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
    private let config: Config
    private var processes: [String: PluginProcess] = [:]

    init(entries: [PluginEntry], config: Config) {
        self.entries = entries
        self.config = config
    }

    /// Reads `Resources/Plugins/<id>/manifest.json` from the app bundle.
    static func load(from bundle: Bundle, config: Config) -> PluginCatalog {
        let manifests = bundle.resourceURL!.appending(path: "Plugins")
        let helpers = bundle.bundleURL.appending(path: "Contents/Helpers")
        let folders = (try? FileManager.default.contentsOfDirectory(at: manifests, includingPropertiesForKeys: nil)) ?? []
        let entries = folders.sorted { $0.lastPathComponent < $1.lastPathComponent }.compactMap { folder -> PluginEntry? in
            do {
                let manifest = try JSONDecoder().decode(PluginManifest.self, from: Data(contentsOf: folder.appending(path: "manifest.json")))
                return PluginEntry(manifest: manifest, helpers: helpers)
            } catch {
                FileHandle.standardError.write(Data("plugins: skipping \(folder.lastPathComponent): \(error)\n".utf8))
                return nil
            }
        }
        return PluginCatalog(entries: entries, config: config)
    }

    var enabled: [PluginEntry] { entries.filter { !config.disabled.contains($0.id) } }

    /// Enabled plugins that support `url`, best first: exact type matches before supertype matches.
    func candidates(for url: URL) -> [PluginEntry] {
        guard let type = Self.contentType(of: url) else { return [] }
        let exact = enabled.filter { $0.fileTypes.contains(type) }
        let conforming = enabled.filter { entry in !entry.fileTypes.contains(type) && entry.fileTypes.contains { type.conforms(to: $0) } }
        return exact + conforming
    }

    /// The config route for the extension wins, but only if that plugin is enabled and supports the file.
    func defaultPlugin(for url: URL) -> PluginEntry? {
        let candidates = candidates(for: url)
        if let routed = config.routes[url.pathExtension.lowercased()], let entry = candidates.first(where: { $0.id == routed }) {
            return entry
        }
        return candidates.first
    }

    func process(for entry: PluginEntry) -> PluginProcess {
        if let existing = processes[entry.id] { return existing }
        let process = PluginProcess(entry: entry, idleSeconds: config.pluginIdleSeconds)
        processes[entry.id] = process
        return process
    }

    static func contentType(of url: URL) -> UTType? {
        (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType) ?? UTType(filenameExtension: url.pathExtension)
    }
}
