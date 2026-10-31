import AppKit
import PeekerKit
import Testing

/// Plugins the config is checked against, in sidebar order: their ids, extensions and commands are all that matter here.
private enum StubPDF: Plugin {
    static let id = "pdf"
    static let name = "PDF"
    static let defaultExtensions = ["pdf"]
    static let commands = [CommandSpec(id: "zoom-in", title: "Zoom In", shortcut: "cmd+="), CommandSpec(id: "highlight", title: "Highlight")]
    static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument { throw PluginError("not used") }
}

private enum StubMarkdown: Plugin {
    static let id = "markdown"
    static let name = "Markdown"
    static let defaultExtensions = ["md", "markdown"]
    static let commands: [CommandSpec] = []
    static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument { throw PluginError("not used") }
}

private enum StubText: Plugin {
    static let id = "text"
    static let name = "Plain Text"
    static let defaultExtensions = ["txt", noExtension]
    static let commands: [CommandSpec] = []
    static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument { throw PluginError("not used") }
}

private let plugins = [PluginEntry(StubPDF.self), PluginEntry(StubMarkdown.self), PluginEntry(StubText.self)]

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
                "text": { "enabled": false, "extensions": ["txt", "log", "noExtension"] },
                "pdf": { "commands": { "highlight": { "shortcut": "cmd+shift+h" } } }
              }
            }
            """)
        #expect(config.disabled == ["text"])
        #expect(config.extensions == ["text": ["txt", "log", noExtension]])
        #expect(config.keys["pdf.highlight"] == Shortcut(key: .character("h"), modifiers: [.command, .shift]))
        #expect(config.quickLookKey == Shortcut(key: .space, modifiers: [.option]))
    }

    @Test func missingKeysKeepTheirDefaults() throws {
        let config = try config("{}")
        #expect(config.disabled.isEmpty && config.extensions.isEmpty && config.keys.isEmpty)
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
        let reading = read(#"{"plugins": {"text": {}"#)
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
        let reading = read(#"{"plugins": {"text": {"enabeld": false, "extensions": ["log"]}}, "colour": "red"}"#)
        let config = try #require(reading.config)
        #expect(config.disabled.isEmpty)
        #expect(config.extensions == ["text": ["log"]])
        #expect(reading.problems.map(\.path) == ["colour", "plugins.text.enabeld"])
        #expect(reading.problems.last?.message.contains("not a known setting") == true)
    }

    @Test func wrongKindsKeepTheDefault() throws {
        let reading = read(#"{"plugins": {"text": {"enabled": "no", "extensions": "txt"}}, "quickLook": {"key": 5}}"#)
        let config = try #require(reading.config)
        #expect(config.disabled.isEmpty && config.extensions.isEmpty && config.quickLookKey == Shortcut(key: .space))
        #expect(Set(reading.problems.map(\.path)) == ["plugins.text.enabled", "plugins.text.extensions", "quickLook.key"])
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

    @Test func theOldOpenSectionIsUnknown() {
        let reading = read(#"{"open": {"md": "text"}}"#)
        #expect(reading.problems.map(\.path) == ["open"])
        #expect(reading.problems.first?.message.contains("not a known setting") == true)
    }
}

@Suite struct ConfigExtensions {
    @Test func aListReplacesTheDefaultAndADotIsDropped() throws {
        let reading = read(#"{"plugins": {"text": {"extensions": [".TXT", "nginx", "nginx"]}}}"#)
        #expect(reading.problems.isEmpty)
        #expect(try #require(reading.config).extensions == ["text": ["txt", "nginx"]])
    }

    @Test func anEmptyListMeansThePluginOpensNothing() throws {
        let config = try config(#"{"plugins": {"text": {"extensions": []}}}"#)
        #expect(config.extensions == ["text": []])
        #expect(!config.owners(of: plugins).owners.values.contains("text"))
    }

    @Test func aMissingKeyKeepsTheDefaultList() throws {
        let owners = try config("{}").owners(of: plugins).owners
        #expect(owners == ["pdf": "pdf", "md": "markdown", "markdown": "markdown", "txt": "text", noExtension: "text"])
    }

    @Test func badEntriesAreSkippedAndTheRestApplies() throws {
        let reading = read(#"{"plugins": {"text": {"extensions": ["tar.gz", "", "a/b", "a b", 5, "log"]}}}"#)
        #expect(try #require(reading.config).extensions == ["text": ["log"]])
        #expect(reading.problems.map(\.path) == Array(repeating: "plugins.text.extensions", count: 5))
        #expect(reading.problems.first?.message.contains("tar.gz") == true)
    }
}

@Suite struct ExtensionOwners {
    @Test func anExtensionAddedToASecondListStaysWithItsDefaultPlugin() throws {
        let reading = read(#"{"plugins": {"text": {"extensions": ["txt", "md"]}}}"#)
        #expect(try #require(reading.config).owners(of: plugins).owners["md"] == "markdown")
        #expect(reading.problems.map(\.path) == ["plugins.text.extensions"])
        #expect(reading.problems.first?.message.contains("Markdown") == true)
    }

    @Test func theDefaultPluginWinsEvenWhenItComesLater() throws {
        let reading = read(#"{"plugins": {"pdf": {"extensions": ["pdf", "txt"]}}}"#)
        #expect(try #require(reading.config).owners(of: plugins).owners["txt"] == "text")
        #expect(reading.problems.map(\.path) == ["plugins.pdf.extensions"])
    }

    @Test func anExtensionMovedOutOfItsDefaultListHasNoConflict() throws {
        let reading = read(#"{"plugins": {"markdown": {"extensions": ["markdown"]}, "text": {"extensions": ["txt", "md"]}}}"#)
        #expect(reading.problems.isEmpty)
        #expect(try #require(reading.config).owners(of: plugins).owners["md"] == "text")
    }

    @Test func aNewExtensionInTwoListsGoesToTheFirstInSidebarOrder() throws {
        let reading = read(#"{"plugins": {"text": {"extensions": ["txt", "nginx"]}, "pdf": {"extensions": ["pdf", "nginx"]}}}"#)
        #expect(try #require(reading.config).owners(of: plugins).owners["nginx"] == "pdf")
        #expect(reading.problems.map(\.path) == ["plugins.text.extensions"])
        #expect(reading.problems.first?.message.contains("PDF") == true)
    }

    @Test func aDisabledPluginKeepsItsExtensions() throws {
        let config = try config(#"{"plugins": {"markdown": {"enabled": false}}}"#)
        #expect(config.owners(of: plugins).owners["md"] == "markdown")
    }
}

@Suite struct ConfigRendering {
    private func rendered(_ config: Config) -> String { String(decoding: config.json(plugins: plugins), as: UTF8.self) }

    private func object(_ config: Config) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: config.json(plugins: plugins)) as? [String: Any])
    }

    @Test func defaultsWriteEverySetting() throws {
        let root = try object(Config())
        #expect(root["$schema"] as? String == "schema.json")
        #expect((root["quickLook"] as? [String: Any])?["key"] as? String == "space")
        let pluginSettings = try #require(root["plugins"] as? [String: [String: Any]])
        #expect(pluginSettings.keys.sorted() == ["markdown", "pdf", "text"])
        #expect(pluginSettings["markdown"]?["enabled"] as? Bool == true)
        #expect(pluginSettings["markdown"]?["extensions"] as? [String] == ["md", "markdown"])
        #expect(pluginSettings["text"]?["extensions"] as? [String] == ["txt", "noExtension"])
        // A command's default shortcut is written; one with no shortcut is left out.
        #expect((pluginSettings["pdf"]?["commands"] as? [String: [String: String]]) == ["zoom-in": ["shortcut": "cmd+="]])
    }

    @Test func readingTheRenderingGivesBackTheSameSettings() throws {
        let original = try config("""
            {"quickLook": {"key": "off"},
             "plugins": {"text": {"enabled": false, "extensions": ["txt", "log"]},
                         "pdf": {"commands": {"highlight": {"shortcut": "cmd+shift+h"}}}}}
            """)
        let reading = read(rendered(original))
        #expect(reading.problems.isEmpty)
        let back = try #require(reading.config)
        #expect(back.quickLookKey == nil)
        #expect(back.disabled == ["text"])
        #expect(back.extensions["text"] == ["txt", "log"])
        #expect(back.keys["pdf.highlight"] == Shortcut(key: .character("h"), modifiers: [.command, .shift]))
        #expect(rendered(back) == rendered(original), "rendering is stable")
    }

    @Test func keysComeOutSortedWithATrailingNewline() {
        let text = rendered(Config())
        #expect(text.hasSuffix("}\n"))
        let order = ["\"$schema\"", "\"plugins\"", "\"quickLook\""].compactMap { text.range(of: $0)?.lowerBound }
        #expect(order.count == 3 && order == order.sorted())
    }

    @Test func anExtensionAnotherPluginKeepsIsLeftOut() throws {
        let clash = try config(#"{"plugins": {"text": {"extensions": ["txt", "md"]}}}"#)
        let root = try object(clash)
        let pluginSettings = try #require(root["plugins"] as? [String: [String: Any]])
        #expect(pluginSettings["text"]?["extensions"] as? [String] == ["txt"])
        #expect(read(rendered(clash)).problems.isEmpty)
    }
}

@Suite struct ConfigEditing {
    private var markdown: PluginEntry { plugins[1] }
    private var text: PluginEntry { plugins[2] }

    @Test func extensionEntriesAreCheckedLikeTheConfigs() {
        #expect(Config.extensionEntry(".Rst") == "rst")
        #expect(Config.extensionEntry("noExtension") == noExtension)
        #expect(Config.extensionEntry("tar.gz") == nil)
        #expect(Config.extensionEntry("") == nil)
        #expect(Config.extensionEntry("a b") == nil)
    }

    @Test func addingAndRemovingChangeOnlyThatPlugin() {
        var config = Config()
        config.addExtension("rst", to: text, among: plugins)
        #expect(config.effectiveExtensions(of: text, among: plugins) == ["txt", noExtension, "rst"])
        config.addExtension("rst", to: text, among: plugins)
        #expect(config.effectiveExtensions(of: text, among: plugins) == ["txt", noExtension, "rst"], "adding twice changes nothing")
        config.removeExtension("txt", from: text, among: plugins)
        #expect(config.effectiveExtensions(of: text, among: plugins) == [noExtension, "rst"])
        #expect(config.effectiveExtensions(of: markdown, among: plugins) == ["md", "markdown"])
    }

    @Test func movingTakesTheExtensionFromItsOwner() {
        var config = Config()
        #expect(config.owner(of: "md", among: plugins)?.id == "markdown")
        config.moveExtension("md", to: text, among: plugins)
        #expect(config.owner(of: "md", among: plugins)?.id == "text")
        #expect(config.effectiveExtensions(of: markdown, among: plugins) == ["markdown"])
        #expect(config.owners(of: plugins).problems.isEmpty)
    }

    @Test func resettingAPluginGivesBackExtensionsItTookFromAnother() throws {
        var config = Config()
        config.moveExtension("md", to: text, among: plugins)
        // As saved, Markdown's list no longer has md.
        config = try #require(read(String(decoding: config.json(plugins: plugins), as: UTF8.self)).config)
        config.resetExtensions(of: text, among: plugins)
        #expect(config.owner(of: "md", among: plugins)?.id == "markdown")
        #expect(config.effectiveExtensions(of: text, among: plugins) == ["txt", noExtension])
    }

    @Test func resettingBringsBackTheDefaultsEvenFromAnotherPlugin() throws {
        var config = Config()
        config.moveExtension("md", to: text, among: plugins)
        config.resetExtensions(of: markdown, among: plugins)
        #expect(config.owner(of: "md", among: plugins)?.id == "markdown")
        #expect(config.effectiveExtensions(of: text, among: plugins) == ["txt", noExtension])
        let back = try #require(read(String(decoding: config.json(plugins: plugins), as: UTF8.self)).config)
        #expect(back.owners(of: plugins).problems.isEmpty)
    }
}
