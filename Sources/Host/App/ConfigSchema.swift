import Foundation
import PeekerKit

/// The JSON Schema for `config.json`, written next to it so editors can autocomplete and check the keys. Built from
/// the same plugin list the config is checked against, so the two can't drift.
enum ConfigSchema {
    static func data(plugins: [PluginEntry]) -> Data {
        let pluginProperties = Dictionary(uniqueKeysWithValues: plugins.map { plugin in
            (plugin.id, object("Settings for the \(plugin.name) plugin.", [
                "enabled": ["type": "boolean", "description": "False turns the plugin off: it opens no files. Default: true."],
                "extensions": [
                    "type": "array",
                    "items": ["type": "string"],
                    "default": plugin.defaultExtensions,
                    "description": "Every extension the plugin opens (no dot; noExtension for files without one), replacing its default list: \(plugin.defaultExtensions.joined(separator: ", ")).",
                ],
                "commands": object("Shortcuts for the plugin's commands.", Dictionary(uniqueKeysWithValues: plugin.commands.map { command in
                    (command.id, object("\(command.title)" + (command.shortcut.map { ". Default: \($0)." } ?? "."), [
                        "shortcut": ["type": "string", "description": "A key with modifiers, such as cmd+shift+h. An edit tool may also use a single key, such as c, which works only in Edit mode."],
                    ]))
                })),
            ]))
        })
        var schema = object("Peeker settings. Every key is optional; a missing one keeps its default.", [
            "$schema": ["type": "string", "description": "Where this schema is, for editors."],
            "quickLook": object("The quick look panel on Space in Finder.", [
                "key": ["type": "string", "description": "The key that opens the panel. A bare key works only in Finder and not while typing; one with modifiers works anywhere; \"off\" turns the panel off. Default: space."],
            ]),
            "plugins": object("Per-plugin settings, by plugin id.", pluginProperties),
        ])
        schema["$schema"] = "https://json-schema.org/draft/2020-12/schema"
        schema["title"] = "Peeker config"
        // Can't fail: the schema holds only strings, booleans, arrays and dictionaries.
        return (try? JSONSerialization.data(withJSONObject: schema, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])) ?? Data()
    }

    /// Writes `schema.json` next to `config` when its contents differ from what's there. Writes nothing when the
    /// config's folder doesn't exist, so nothing appears uninvited. Returns whether it wrote.
    @discardableResult
    static func write(nextTo config: URL, plugins: [PluginEntry]) throws -> Bool {
        let folder = config.deletingLastPathComponent()
        var isFolder: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isFolder), isFolder.boolValue else { return false }
        let file = folder.appending(path: "schema.json")
        let data = data(plugins: plugins)
        guard (try? Data(contentsOf: file)) != data else { return false }
        try FileReplacement.replaceContents(ofFileAt: file.path, with: data)
        return true
    }

    private static func object(_ description: String, _ properties: [String: Any]) -> [String: Any] {
        ["type": "object", "description": description, "additionalProperties": false, "properties": properties]
    }
}
