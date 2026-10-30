import Foundation
import PeekerText
import Testing

@Suite struct ConfigFileTests {
    private let plugins = [PluginEntry(TextPlugin.self)]

    @Test func createsAStarterFileAndItsFolderWhenThereIsNone() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "peeker-config-\(UUID().uuidString)/peeker")
        let config = folder.appending(path: "config.json")
        #expect(try ConfigFile.createIfMissing(at: config, plugins: plugins))
        #expect(try Data(contentsOf: config) == Data("{\n  \"$schema\": \"schema.json\"\n}\n".utf8))
        #expect(FileManager.default.fileExists(atPath: folder.appending(path: "schema.json").path))
        #expect(Config.load(from: config, plugins: plugins).problems.isEmpty)
    }

    @Test func leavesAnExistingFileByteForByte() throws {
        let bytes = Data(#"{"open":{"md":"text"}}"#.utf8)
        let config = try TempFile.make(bytes, name: "config.json")
        #expect(try !ConfigFile.createIfMissing(at: config, plugins: plugins))
        #expect(try Data(contentsOf: config) == bytes)
    }
}
