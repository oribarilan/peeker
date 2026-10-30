import AppKit

/// Actions on the config file the Settings window offers.
enum ConfigFile {
    /// Creates a config containing only the schema line, with its folder and the schema, when there's no file yet.
    /// Never touches an existing file. Returns whether it created one.
    @discardableResult
    static func createIfMissing(at url: URL, plugins: [PluginEntry]) throws -> Bool {
        guard !FileManager.default.fileExists(atPath: url.path) else { return false }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Fails rather than replace a file that appeared meanwhile.
        try Data("{\n  \"$schema\": \"schema.json\"\n}\n".utf8).write(to: url, options: .withoutOverwriting)
        try ConfigSchema.write(nextTo: url, plugins: plugins)
        return true
    }

    /// Opens the config in the user's default app for JSON, creating it first when there's none.
    static func openInEditor(_ url: URL, plugins: [PluginEntry]) {
        do {
            try createIfMissing(at: url, plugins: plugins)
            NSWorkspace.shared.open(url)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't create the config file"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
}
