import Foundation
import Observation
import PeekerKit

/// The settings in use and what's wrong with the config file, kept current: it reads the file now and again each
/// time it's saved. A file that can't be used at all (not JSON, unreadable) leaves the settings in use as they were.
@Observable
final class ConfigStore {
    let url: URL
    let plugins: [PluginEntry]
    private(set) var config = Config()
    private(set) var problems: [ConfigProblem] = []
    /// False while the file can't be used at all (not JSON, unreadable), which locks Settings. A missing file is fine.
    private(set) var isUsable = true
    @ObservationIgnored private var watcher: FileWatcher?
    /// Called on the main thread when the settings in use, the problems or whether the file is usable change.
    @ObservationIgnored var onChange: ((ConfigStore) -> Void)?

    init(url: URL = Config.defaultURL, plugins: [PluginEntry]) {
        self.url = url
        self.plugins = plugins
        read()
        watcher = FileWatcher(url: url) { [weak self] in
            guard let self, read() else { return }
            onChange?(self)
        }
    }

    func stop() {
        watcher?.stop()
        watcher = nil
    }

    /// Saves a change made in Settings: renders the whole config with `change` applied and writes it through the
    /// safe-write path, creating the file and its folder (with the schema) when missing. Writes nothing when the file
    /// already says the same, and refuses while the file can't be used. Applies the result at once.
    func save(_ change: (inout Config) -> Void) throws {
        guard isUsable else { throw SaveError("The config file can't be read, so Settings can't change it. Fix it in your editor first.") }
        var next = config
        change(&next)
        let data = next.json(plugins: plugins)
        guard (try? Data(contentsOf: url)) != data else { return }
        let folder = url.deletingLastPathComponent()
        let isNewFolder = !FileManager.default.fileExists(atPath: folder.path)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try FileReplacement.replaceContents(ofFileAt: url.path, with: data)
        if isNewFolder { try ConfigSchema.write(nextTo: url, plugins: plugins) }
        if read() { onChange?(self) }
    }

    struct SaveError: LocalizedError {
        let errorDescription: String?
        init(_ message: String) { errorDescription = message }
    }

    /// Reads the file; true when that changed anything. A Settings save sees its own write again through the watcher.
    @discardableResult
    private func read() -> Bool {
        let before = (config, problems, isUsable)
        let reading = Config.load(from: url, plugins: plugins)
        if let config = reading.config { self.config = config }
        isUsable = reading.config != nil
        problems = reading.problems
        return before != (config, problems, isUsable)
    }
}
