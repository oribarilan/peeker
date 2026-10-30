import Foundation
import Observation

/// The settings in use and what's wrong with the config file, kept current: it reads the file now and again each
/// time it's saved. A file that can't be used at all (not JSON, unreadable) leaves the settings in use as they were.
@Observable
final class ConfigStore {
    let url: URL
    let plugins: [PluginEntry]
    private(set) var config = Config()
    private(set) var problems: [ConfigProblem] = []
    @ObservationIgnored private var watcher: FileWatcher?
    /// Called on the main thread after every read caused by a change to the file.
    @ObservationIgnored var onChange: ((ConfigStore) -> Void)?

    init(url: URL = Config.defaultURL, plugins: [PluginEntry]) {
        self.url = url
        self.plugins = plugins
        read()
        watcher = FileWatcher(url: url) { [weak self] in
            guard let self else { return }
            read()
            onChange?(self)
        }
    }

    func stop() {
        watcher?.stop()
        watcher = nil
    }

    private func read() {
        let reading = Config.load(from: url, plugins: plugins)
        if let config = reading.config { self.config = config }
        problems = reading.problems
    }
}
