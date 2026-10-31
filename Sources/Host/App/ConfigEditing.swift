import Foundation

/// The edits Settings makes to extension lists. Each works on the lists as they apply now, so what's saved is what
/// the user saw.
extension Config {
    /// The extensions `plugin` opens: its configured or default list, minus any another plugin keeps.
    func effectiveExtensions(of plugin: PluginEntry, among plugins: [PluginEntry]) -> [String] {
        let owners = owners(of: plugins).owners
        return (extensions[plugin.id] ?? plugin.defaultExtensions).filter { owners[$0] == plugin.id }
    }

    /// The plugin that opens `ext`, enabled or not.
    func owner(of ext: String, among plugins: [PluginEntry]) -> PluginEntry? {
        owners(of: plugins).owners[ext].flatMap { id in plugins.first { $0.id == id } }
    }

    /// Adds `ext` to `plugin`'s list. Settings moves an extension another plugin has instead (`moveExtension`).
    mutating func addExtension(_ ext: String, to plugin: PluginEntry, among plugins: [PluginEntry]) {
        let list = effectiveExtensions(of: plugin, among: plugins)
        guard !list.contains(ext) else { return }
        extensions[plugin.id] = list + [ext]
    }

    mutating func removeExtension(_ ext: String, from plugin: PluginEntry, among plugins: [PluginEntry]) {
        extensions[plugin.id] = effectiveExtensions(of: plugin, among: plugins).filter { $0 != ext }
    }

    /// Takes `ext` off its current owner's list and adds it to `plugin`'s.
    mutating func moveExtension(_ ext: String, to plugin: PluginEntry, among plugins: [PluginEntry]) {
        if let owner = owner(of: ext, among: plugins), owner.id != plugin.id { removeExtension(ext, from: owner, among: plugins) }
        addExtension(ext, to: plugin, among: plugins)
    }

    /// Back to the plugin's default list. A default extension moved to another plugin comes back, and an extension
    /// this plugin took from another goes back to the plugin that lists it by default, so Reset undoes a move.
    mutating func resetExtensions(of plugin: PluginEntry, among plugins: [PluginEntry]) {
        let dropped = effectiveExtensions(of: plugin, among: plugins).filter { !plugin.defaultExtensions.contains($0) }
        extensions[plugin.id] = nil
        for ext in dropped {
            if let home = plugins.first(where: { $0.id != plugin.id && $0.defaultExtensions.contains(ext) }) { addExtension(ext, to: home, among: plugins) }
        }
    }
}
