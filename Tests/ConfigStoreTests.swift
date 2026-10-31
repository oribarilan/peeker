import Foundation
import PeekerText
import Testing

@Suite(.serialized) struct ConfigStoreTests {
    private let plugins = [PluginEntry(TextPlugin.self)]

    private func store(_ json: String) throws -> (ConfigStore, URL) {
        let file = try TempFile.make(Data(json.utf8), name: "config.json")
        return (ConfigStore(url: file, plugins: plugins), file)
    }

    @Test func readsTheFileAtOnce() throws {
        let (store, _) = try store(#"{"plugins": {"text": {"extensions": ["md"]}}}"#)
        defer { store.stop() }
        #expect(store.config.extensions == ["text": ["md"]])
        #expect(store.problems.isEmpty)
    }

    @Test func aSaveApplies() async throws {
        let (store, file) = try store("{}")
        defer { store.stop() }
        var changes = 0
        store.onChange = { _ in changes += 1 }
        try Data(#"{"plugins": {"text": {"extensions": ["md"]}}}"#.utf8).write(to: file)
        try await waitUntil(seconds: 2) { store.config.extensions == ["text": ["md"]] }
        #expect(changes >= 1)
    }

    @Test func anEditorThatSavesByRenamingStillApplies() async throws {
        let (store, file) = try store("{}")
        defer { store.stop() }
        try Data(#"{"plugins": {"text": {"extensions": ["conf"]}}}"#.utf8).write(to: file, options: .atomic)
        try await waitUntil(seconds: 2) { store.config.extensions == ["text": ["conf"]] }
        try Data(#"{"plugins": {"text": {"extensions": ["md"]}}}"#.utf8).write(to: file, options: .atomic)
        try await waitUntil(seconds: 2) { store.config.extensions == ["text": ["md"]] }
    }

    @Test func aSymlinkedConfigAppliesAndStaysALink() async throws {
        let target = try TempFile.make(Data("{}".utf8), name: "config.json")
        let link = try TempFile.make(Data(), name: "placeholder").deletingLastPathComponent().appending(path: "config.json")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        let store = ConfigStore(url: link, plugins: plugins)
        defer { store.stop() }
        try Data(#"{"plugins": {"text": {"extensions": ["md"]}}}"#.utf8).write(to: target, options: .atomic)
        try await waitUntil(seconds: 3) { store.config.extensions == ["text": ["md"]] }
        #expect(try FileManager.default.attributesOfItem(atPath: link.path)[.type] as? FileAttributeType == .typeSymbolicLink)
    }

    @Test func brokenJSONKeepsTheSettingsInUse() async throws {
        let (store, file) = try store(#"{"plugins": {"text": {"extensions": ["md"]}}}"#)
        defer { store.stop() }
        try Data(#"{"plugins": {"text": "#.utf8).write(to: file)
        try await waitUntil(seconds: 2) { !store.problems.isEmpty }
        #expect(store.config.extensions == ["text": ["md"]])
        #expect(store.problems.count == 1)
    }
}

@Suite(.serialized) struct ConfigStoreSaving {
    private let plugins = [PluginEntry(TextPlugin.self)]

    private func store(_ json: String) throws -> (ConfigStore, URL) {
        let file = try TempFile.make(Data(json.utf8), name: "config.json")
        return (ConfigStore(url: file, plugins: plugins), file)
    }

    private func contents(_ url: URL) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    }

    /// The watcher sees the save's own write; reporting it again would rebuild every toolbar a second time.
    @Test func aSettingsChangeIsReportedOnce() async throws {
        let (store, _) = try store("{}")
        defer { store.stop() }
        var changes = 0
        store.onChange = { _ in changes += 1 }
        try store.save { $0.disabled.insert("text") }
        try await Task.sleep(for: .milliseconds(600))  // past the watcher's 200 ms
        #expect(changes == 1)
    }

    @Test func theFirstSaveCreatesTheFileItsFolderAndTheSchema() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "PeekerTests-" + UUID().uuidString).appending(path: "peeker")
        let file = folder.appending(path: "config.json")
        let store = ConfigStore(url: file, plugins: plugins)
        defer { store.stop() }
        #expect(store.isUsable)
        try store.save { $0.disabled.insert("text") }
        let plugin = try #require((try contents(file)["plugins"] as? [String: [String: Any]])?["text"])
        #expect(plugin["enabled"] as? Bool == false)
        #expect(FileManager.default.fileExists(atPath: folder.appending(path: "schema.json").path))
        #expect(store.config.disabled == ["text"])
    }

    @Test func aSaveDropsKeysTheAppDoesntKnow() throws {
        let (store, file) = try store(#"{"plugins": {"text": {"enabeld": false}}}"#)
        defer { store.stop() }
        #expect(store.problems.count == 1)
        try store.save { $0.quickLookKey = nil }
        let plugin = try #require((try contents(file)["plugins"] as? [String: [String: Any]])?["text"])
        #expect(plugin["enabeld"] == nil)
        #expect(store.problems.isEmpty)
    }

    @Test func aSymlinkedConfigStaysALink() throws {
        let target = try TempFile.make(Data("{}".utf8), name: "config.json")
        let link = try TempFile.make(Data(), name: "placeholder").deletingLastPathComponent().appending(path: "config.json")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        let store = ConfigStore(url: link, plugins: plugins)
        defer { store.stop() }
        try store.save { $0.disabled.insert("text") }
        #expect(try FileManager.default.attributesOfItem(atPath: link.path)[.type] as? FileAttributeType == .typeSymbolicLink)
        #expect(String(decoding: try Data(contentsOf: target), as: UTF8.self).contains("\"enabled\" : false"))
    }

    @Test func nothingIsWrittenWhenNothingChanged() throws {
        let (store, file) = try store("{}")
        defer { store.stop() }
        try store.save { _ in }
        let first = try FileManager.default.attributesOfItem(atPath: file.path)[.systemFileNumber] as? Int
        try store.save { _ in }
        #expect(try FileManager.default.attributesOfItem(atPath: file.path)[.systemFileNumber] as? Int == first)
    }

    @Test func brokenJSONLocksSavingUntilItsFixed() async throws {
        let (store, file) = try store(#"{"plugins": "#)
        defer { store.stop() }
        #expect(!store.isUsable)
        #expect(throws: (any Error).self) { try store.save { $0.disabled.insert("text") } }
        #expect(String(decoding: try Data(contentsOf: file), as: UTF8.self) == #"{"plugins": "#)
        try Data("{}".utf8).write(to: file)
        try await waitUntil(seconds: 2) { store.isUsable }
    }
}

@Suite(.serialized) struct LiveConfigTests {
    @Test func applyingAConfigUpdatesAnOpenDocumentsShortcuts() async throws {
        let file = try TempFile.make(Data("a\n".utf8))
        let document = DocumentViewController(url: file, entry: PluginEntry(TextPlugin.self), config: Config(), allowsEditing: true, recovery: nil)
        defer { document.close() }
        document.loadViewIfNeeded()
        await document.load()
        #expect(document.commands.first { $0.spec.id == "zoom-in" }?.shortcut == Shortcut(parsing: "cmd+="))
        var changed = false
        document.onCommandsChanged = { _ in changed = true }
        var config = Config()
        config.keys["text.zoom-in"] = Shortcut(parsing: "cmd+shift+z")
        document.apply(config)
        #expect(document.commands.first { $0.spec.id == "zoom-in" }?.shortcut == Shortcut(parsing: "cmd+shift+z"))
        #expect(changed)
    }
}
