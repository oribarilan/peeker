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
