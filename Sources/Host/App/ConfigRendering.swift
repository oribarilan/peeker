import Foundation

extension Config {
    /// The whole config as `config.json` bytes: every setting, defaults included, with sorted keys. Built from the
    /// settings themselves, so keys the app doesn't understand and values it couldn't use never come out, and each
    /// plugin lists only the extensions it owns. Reading it back gives the same settings.
    func json(plugins: [PluginEntry]) -> Data {
        let pluginSettings = Dictionary(uniqueKeysWithValues: plugins.map { plugin in
            let commands = Dictionary(uniqueKeysWithValues: plugin.commands.compactMap { command -> (String, [String: String])? in
                if noShortcut.contains(Config.keyID(plugin: plugin.id, command: command.id)) { return (command.id, ["shortcut": "off"]) }
                guard let shortcut = shortcut(for: command, of: plugin.id) else { return nil }
                return (command.id, ["shortcut": shortcut.configText])
            })
            var settings: [String: Any] = [
                "enabled": !disabled.contains(plugin.id),
                "extensions": effectiveExtensions(of: plugin, among: plugins),
            ]
            if !commands.isEmpty { settings["commands"] = commands }
            return (plugin.id, settings)
        })
        let root: [String: Any] = [
            "$schema": "schema.json",
            "quickLook": ["key": quickLookKey?.configText ?? "off"],
            "updates": ["check": checkForUpdates],
            "plugins": pluginSettings,
        ]
        // Can't fail: the tree holds only strings, booleans, arrays and dictionaries.
        var data = (try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])) ?? Data()
        data.append(0x0A)
        return data
    }
}
