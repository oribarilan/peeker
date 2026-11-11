import Foundation
import PeekerKit

/// The JSON Schema for `config.json`, written next to it so editors can autocomplete and check the keys. Built from
/// the same plugin list the config is checked against, so the two can't drift.
enum ConfigSchema {
    static func data(plugins: [PluginEntry]) -> Data {
        let pluginProperties = Dictionary(
            uniqueKeysWithValues: plugins.map { plugin in
                (
                    plugin.id,
                    object(
                        "Settings for the \(plugin.name) plugin.",
                        [
                            "enabled": ["type": "boolean", "description": "False turns the plugin off: it opens no files. Default: true."],
                            "extensions": [
                                "type": "array",
                                "items": ["type": "string"],
                                "default": plugin.defaultExtensions,
                                "description":
                                    "Every extension the plugin opens (no dot; noExtension for files without one), replacing its default list: \(plugin.defaultExtensions.joined(separator: ", ")).",
                            ],
                            "tools": object(
                                "Shortcuts for the plugin's tools.",
                                Dictionary(
                                    uniqueKeysWithValues: plugin.tools.map { command in
                                        (
                                            command.id,
                                            object(
                                                "\(command.title)" + (command.shortcut.map { ". Default: \($0)." } ?? "."),
                                                [
                                                    "shortcut": [
                                                        "type": "string",
                                                        "description":
                                                            "A key with modifiers, such as cmd+shift+h, or \"off\" for no shortcut. Named keys are space, esc, tab, enter, pageup and pagedown. An edit tool may also use a single key, such as c, which works while no text field has the keyboard; any tool may use pageup or pagedown alone.",
                                                    ]
                                                ])
                                        )
                                    })),
                        ])
                )
            })
        var schema = object(
            "Peeker settings. Every key is optional; a missing one keeps its default.",
            [
                "$schema": ["type": "string", "description": "Where this schema is, for editors."],
                "peekPanel": object(
                    "The Peek panel: a key in Finder shows the selected file in Peeker.",
                    [
                        "key": [
                            "type": "string",
                            "description":
                                "The key that opens the Peek panel. A bare key works only in Finder and not while typing; one with modifiers works anywhere; \"off\" turns the panel off. Default: space.",
                        ],
                        "openWith": [
                            "type": "object", "additionalProperties": ["type": "string"], "default": [String: String](),
                            "description":
                                "Apps the Peek panel's button opens files with instead of Peeker, by extension (no dot) to the app's bundle ID, such as {\"swift\": \"com.apple.dt.Xcode\"}. Only the panel follows it; the Mac's default app stays as it is. Set and cleared from the button's menu.",
                        ],
                        "openKey": [
                            "type": "string", "default": "cmd+o",
                            "description":
                                "The key that does what the Peek panel's main button does, while the panel is up and Finder is in front. Needs Command, Option or Control; \"off\" for none.",
                        ],
                        "showInFinderKey": [
                            "type": "string", "default": "cmd+r",
                            "description":
                                "The key that shows the Peek panel's file in Finder and closes the panel, while it's up and Finder is in front. Needs Command, Option or Control; \"off\" for none.",
                        ],
                    ]),
                "plugins": object("Per-plugin settings, by plugin id.", pluginProperties),
                "textTheme": [
                    "type": "string", "enum": TextTheme.ids, "default": "system",
                    "description":
                        "The colors of Markdown and text, in windows and the Peek panel. Each theme has a light and a dark variant. Default: system.",
                ],
                "appearance": [
                    "type": "string", "enum": Config.appearances, "default": "system",
                    "description": "The look of Peeker's windows: system follows the Mac, light or dark holds that look. Default: system.",
                ],
                "textAppearance": [
                    "type": "string", "enum": Config.textAppearances, "default": "app",
                    "description":
                        "Which variant of the text theme Markdown and text files use: app matches Peeker's appearance, light or dark holds that variant. Default: app.",
                ],
                "showShortcuts": [
                    "type": "boolean", "default": true,
                    "description":
                        "True shows each toolbar tool's key beside its icon; false leaves the keys to tooltips, the menus and Settings. Default: true.",
                ],
                "updates": object(
                    "Checking for new versions of Peeker.",
                    [
                        "automatic": [
                            "type": "string", "enum": Config.automaticUpdateModes, "default": "check",
                            "description":
                                "off checks only when you ask; check looks for a new version once a day and offers it with its release notes; download also downloads it and installs it once no window is open. Default: check.",
                        ],
                        "showWhatsNew": [
                            "type": "boolean", "default": true,
                            "description": "True shows a window with the release notes after Peeker updates. Default: true.",
                        ],
                    ]),
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
