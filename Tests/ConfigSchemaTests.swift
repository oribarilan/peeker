import Foundation
import PeekerKit
import PeekerPDF
import PeekerText
import Testing

@Suite struct ConfigSchemaTests {
    private let plugins = [PluginEntry(PDFPlugin.self), PluginEntry(TextPlugin.self)]

    private func schema() throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: ConfigSchema.data(plugins: plugins)) as? [String: Any])
    }

    private func properties(_ object: [String: Any]?, _ key: String) -> [String: Any]? {
        (object?["properties"] as? [String: Any])?[key] as? [String: Any]
    }

    @Test func listsEveryPluginAndItsCommands() throws {
        let schema = try schema()
        let plugins = try #require(properties(schema, "plugins"))
        let pdf = try #require((plugins["properties"] as? [String: Any])?["pdf"] as? [String: Any])
        let commands = try #require(properties(pdf, "commands")?["properties"] as? [String: Any])
        #expect(Set(commands.keys) == ["zoom-in", "zoom-out", "highlight"])
        #expect(Set((plugins["properties"] as? [String: Any])?.keys ?? [:].keys) == ["pdf", "text"])
    }

    @Test func eachPluginsExtensionsDefaultToItsList() throws {
        let plugins = try #require(properties(try schema(), "plugins")?["properties"] as? [String: Any])
        for plugin in self.plugins {
            let extensions = try #require(properties(plugins[plugin.id] as? [String: Any], "extensions"))
            #expect(extensions["type"] as? String == "array")
            #expect(extensions["default"] as? [String] == plugin.defaultExtensions)
        }
    }

    @Test func theOldOpenSectionIsGone() throws {
        #expect(properties(try schema(), "open") == nil)
    }

    @Test func refusesKeysItDoesNotDescribe() throws {
        let schema = try schema()
        #expect(schema["additionalProperties"] as? Bool == false)
        #expect(properties(schema, "quickLook")?["additionalProperties"] as? Bool == false)
        #expect(properties(schema, "plugins")?["additionalProperties"] as? Bool == false)
    }

    @Test func writesNextToTheConfigOnlyWhenItChanges() throws {
        let config = try TempFile.make(Data("{}".utf8), name: "config.json")
        let schemaFile = config.deletingLastPathComponent().appending(path: "schema.json")
        #expect(try ConfigSchema.write(nextTo: config, plugins: plugins))
        #expect(FileManager.default.fileExists(atPath: schemaFile.path))
        #expect(try !ConfigSchema.write(nextTo: config, plugins: plugins), "unchanged, so no second write")
        #expect(try Data(contentsOf: config) == Data("{}".utf8))
    }

    @Test func writesNothingWithoutAConfigFolder() throws {
        let missing = FileManager.default.temporaryDirectory.appending(path: "no-such-\(UUID().uuidString)/config.json")
        #expect(try !ConfigSchema.write(nextTo: missing, plugins: plugins))
        #expect(!FileManager.default.fileExists(atPath: missing.deletingLastPathComponent().path))
    }
}
