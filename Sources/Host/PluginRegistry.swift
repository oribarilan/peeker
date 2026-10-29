import Foundation
import PreviewPPKit
import UniformTypeIdentifiers

/// How a plugin's code runs. Only used for display and benchmarking; the host treats all entries alike.
enum Runtime: String {
    case builtin, bundle, web, process
}

/// One registered plugin, whatever its runtime.
struct PluginEntry {
    let id: String
    let manifest: PluginManifest
    let runtime: Runtime
    let open: (URL, any PluginHost) throws -> Viewer
}

final class PluginRegistry {
    private(set) var entries: [PluginEntry] = []
    private let config: Config

    init(config: Config) {
        self.config = config
    }

    /// Native plugins are instantiated on first use, then reused for every tab.
    func register(_ type: any Plugin.Type, runtime: Runtime) {
        var instance: (any Plugin)?
        add(type.manifest, runtime: runtime) { url, host in
            let plugin = instance ?? type.init()
            instance = plugin
            return try plugin.open(url, host: host)
        }
    }

    func add(_ manifest: PluginManifest, runtime: Runtime, open: @escaping (URL, any PluginHost) throws -> Viewer) {
        // The same plugin may exist in two runtimes during experiments; keep both, addressable as id@runtime.
        let id = entries.contains { $0.id == manifest.id } ? "\(manifest.id)@\(runtime.rawValue)" : manifest.id
        entries.append(PluginEntry(id: id, manifest: manifest, runtime: runtime, open: open))
    }

    /// Scans plugin folders. Bundles are loaded eagerly so the POC can measure what that costs.
    func discover(in directories: [URL]) {
        let fileManager = FileManager.default
        for directory in directories {
            let items = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
            for item in items.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                switch item.pathExtension {
                case "pppplugin": loadBundle(at: item)
                case "pppweb": loadExternal(at: item) { WebPluginAdapter(folder: item, manifest: $0) }
                case "pppproc": loadExternal(at: item) { ProcessPluginAdapter(folder: item, manifest: $0) }
                default: continue
                }
            }
        }
    }

    private func loadBundle(at url: URL) {
        do {
            guard let bundle = Bundle(url: url) else { throw CocoaError(.fileReadCorruptFile) }
            try bundle.loadAndReturnError()
            guard let type = bundle.principalClass as? any Plugin.Type else {
                throw CocoaError(.executableNotLoadable, userInfo: [NSLocalizedDescriptionKey: "principal class is not a PreviewPPKit.Plugin"])
            }
            register(type, runtime: .bundle)
        } catch {
            // The debug description carries dyld's actual reason (e.g. a Team ID mismatch under library validation).
            let reason = (error as NSError).userInfo[NSDebugDescriptionErrorKey] as? String ?? error.localizedDescription
            log("skipping \(url.lastPathComponent): \(reason)")
        }
    }

    private func loadExternal(at url: URL, adapter: (ExternalManifest) -> some ExternalPlugin) {
        do {
            let manifest = try ExternalManifest.load(from: url)
            let plugin = adapter(manifest)
            add(manifest.pluginManifest, runtime: plugin.runtime, open: plugin.open)
        } catch {
            log("skipping \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    // MARK: Routing

    /// Enabled plugins that can open `url`, best first: exact type matches before supertype matches.
    func candidates(for url: URL) -> [PluginEntry] {
        guard let type = Self.contentType(of: url) else { return [] }
        let enabled = entries.filter { !config.disabled.contains($0.id) }
        let exact = enabled.filter { $0.manifest.fileTypes.contains(type) }
        let conforming = enabled.filter { entry in
            !entry.manifest.fileTypes.contains(type) && entry.manifest.fileTypes.contains { type.conforms(to: $0) }
        }
        return exact + conforming
    }

    func defaultPlugin(for url: URL) -> PluginEntry? {
        let candidates = candidates(for: url)
        if let routed = config.routes[url.pathExtension.lowercased()], let entry = candidates.first(where: { $0.id == routed }) {
            return entry
        }
        return candidates.first
    }

    static func contentType(of url: URL) -> UTType? {
        (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType) ?? UTType(filenameExtension: url.pathExtension)
    }

    private func log(_ message: String) {
        FileHandle.standardError.write(Data("plugins: \(message)\n".utf8))
    }
}
