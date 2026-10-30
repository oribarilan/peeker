import AppKit
import PeekerKit
import Testing
import UniformTypeIdentifiers

/// Plugins the config is checked against: their ids, file types and commands are all that matter here.
private enum StubPDF: Plugin {
    static let id = "pdf"
    static let name = "PDF"
    static let fileTypes: [UTType] = [.pdf]
    static let commands = [CommandSpec(id: "zoom-in", title: "Zoom In"), CommandSpec(id: "highlight", title: "Highlight")]
    static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument { throw PluginError("not used") }
}

private enum StubText: Plugin {
    static let id = "text"
    static let name = "Plain Text"
    static let fileTypes: [UTType] = [.plainText]
    static let commands: [CommandSpec] = []
    static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument { throw PluginError("not used") }
}

private let plugins = [PluginEntry(StubPDF.self), PluginEntry(StubText.self)]

private func read(_ json: String) -> ConfigReading {
    Config.read(Data(json.utf8), plugins: plugins)
}

/// The settings from `json`, which must be usable.
private func config(_ json: String) throws -> Config {
    try #require(read(json).config)
}

@Suite struct ConfigParsing {
    @Test func everySectionApplies() throws {
        let config = try config("""
            {
              "$schema": "schema.json",
              "quickLook": { "key": "opt+space" },
              "plugins": {
                "text": { "enabled": false },
                "pdf": { "commands": { "highlight": { "shortcut": "cmd+shift+h" } } }
              },
              "open": { "MD": "text", "noExtension": "text" }
            }
            """)
        #expect(config.disabled == ["text"])
        #expect(config.routes == ["md": "text", "": "text"])
        #expect(config.keys["pdf.highlight"] == Shortcut(key: .character("h"), modifiers: [.command, .shift]))
        #expect(config.quickLookKey == Shortcut(key: .space, modifiers: [.option]))
        #expect(read("{\"open\": {\"md\": \"text\"}}").problems.isEmpty)
    }

    @Test func missingKeysKeepTheirDefaults() throws {
        let config = try config("{}")
        #expect(config.disabled.isEmpty && config.routes.isEmpty && config.keys.isEmpty)
        #expect(config.quickLookKey == Shortcut(key: .space))
    }

    @Test func noFileMeansDefaultsWithoutProblems() throws {
        let reading = Config.read(nil, plugins: plugins)
        #expect(reading.problems.isEmpty)
        #expect(try #require(reading.config).quickLookKey == Shortcut(key: .space))
    }

    @Test func quickLookCanBeTurnedOff() throws {
        #expect(try config(#"{"quickLook": {"key": "off"}}"#).quickLookKey == nil)
    }

    @Test func theDefaultFileIsJSONAndTheOldDotfileIsNotRead() {
        #expect(Config.defaultURL.lastPathComponent == "config.json")
    }
}

@Suite struct ConfigProblems {
    @Test func invalidJSONIsOneProblemAndNoSettings() {
        let reading = read(#"{"open": {"md": "text""#)
        #expect(reading.config == nil)
        #expect(reading.problems.count == 1)
        #expect(reading.problems.first?.message.hasPrefix("The file isn't valid JSON") == true)
    }

    @Test func aFileThatIsNotAnObjectIsUnusable() {
        let reading = read("[1, 2]")
        #expect(reading.config == nil)
        #expect(reading.problems.map(\.path) == [""])
    }

    @Test func unknownKeysAreSkippedAndTheRestApplies() throws {
        let reading = read(#"{"plugins": {"text": {"enabeld": false}}, "open": {"md": "text"}, "colour": "red"}"#)
        let config = try #require(reading.config)
        #expect(config.disabled.isEmpty)
        #expect(config.routes == ["md": "text"])
        #expect(reading.problems.map(\.path) == ["colour", "plugins.text.enabeld"])
        #expect(reading.problems.last?.message.contains("not a known setting") == true)
    }

    @Test func wrongKindsKeepTheDefault() throws {
        let reading = read(#"{"plugins": {"text": {"enabled": "no"}}, "quickLook": {"key": 5}, "open": {"md": true}}"#)
        let config = try #require(reading.config)
        #expect(config.disabled.isEmpty && config.routes.isEmpty && config.quickLookKey == Shortcut(key: .space))
        #expect(Set(reading.problems.map(\.path)) == ["plugins.text.enabled", "quickLook.key", "open.md"])
    }

    @Test func unparseableShortcutKeepsTheDefault() throws {
        let reading = read(#"{"plugins": {"pdf": {"commands": {"highlight": {"shortcut": "cmd+banana"}}}}}"#)
        #expect(try #require(reading.config).keys.isEmpty)
        #expect(reading.problems.map(\.path) == ["plugins.pdf.commands.highlight.shortcut"])
    }

    @Test func unknownPluginsAndCommandsAreProblems() {
        let reading = read(#"{"plugins": {"pfd": {"enabled": false}, "pdf": {"commands": {"hilight": {"shortcut": "cmd+h"}}}}}"#)
        #expect(reading.problems.map(\.path) == ["plugins.pdf.commands.hilight", "plugins.pfd"])
    }

    @Test func routesThatCanNeverApplyAreProblems() throws {
        let reading = read(#"{"open": {"pdf": "text", "md": "nothing", "conf": "text"}}"#)
        let config = try #require(reading.config)
        #expect(config.routes == ["conf": "text"])   // macOS has no type for .conf, so any plugin may take it
        #expect(Set(reading.problems.map(\.path)) == ["open.pdf", "open.md"])
    }
}
