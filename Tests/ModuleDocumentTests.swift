import AppKit
import PeekerKit
import Testing
import UniformTypeIdentifiers

/// A plugin whose open waits until the test calls `release()`.
private enum GatedPlugin: Plugin {
    static let id = "gated"
    static let name = "Gated"
    static let fileTypes: [UTType] = [.data]
    static var waiting: CheckedContinuation<Void, Never>?

    static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument {
        await withCheckedContinuation { waiting = $0 }
        return StubDocument()
    }

    static func release() {
        waiting?.resume()
        waiting = nil
    }
}

private final class StubDocument: PluginDocument {
    let contentView = NSView()
}

@Suite(.serialized) struct ModuleDocuments {
    private func document() throws -> DocumentViewController {
        let url = try TempFile.make(Data("x".utf8), name: "f.bin")
        let document = DocumentViewController(url: url, entry: PluginEntry(GatedPlugin.self), config: Config(),
                                              allowsEditing: false, recovery: nil)
        document.loadViewIfNeeded()
        return document
    }

    @Test func showsTheDocumentOnceOpened() async throws {
        let document = try document()
        let loading = Task { await document.load() }
        try await waitUntil(seconds: 2) { GatedPlugin.waiting != nil }
        GatedPlugin.release()
        await loading.value
        #expect(document.pluginDocument is StubDocument)
    }

    @Test func closingDuringTheOpenShowsNothing() async throws {
        let document = try document()
        var ready = false
        document.onReady = { _, _ in ready = true }
        let loading = Task { await document.load() }
        try await waitUntil(seconds: 2) { GatedPlugin.waiting != nil }
        document.close()
        GatedPlugin.release()
        await loading.value
        #expect(document.pluginDocument == nil)
        #expect(!ready)
    }
}

/// A plugin whose documents edit a string and whose saves wait until the test calls `release()`.
private enum SlowSavePlugin: Plugin {
    static let id = "slow-save"
    static let name = "Slow Save"
    static let fileTypes: [UTType] = [.data]

    static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument {
        SlowSaveDocument()
    }
}

private final class SlowSaveDocument: PluginDocument {
    static var waiting: CheckedContinuation<Void, Never>?
    let contentView = NSView()
    var onEdit: (() -> Void)?
    private var unsaved: String?
    private(set) var saved: [String] = []

    func unsavedEdits() -> UnsavedEdits? { unsaved.map(UnsavedEdits.init) }

    func restore(encoded edits: Data) -> Bool {
        unsaved = String(decoding: edits, as: UTF8.self)
        onEdit?()
        return true
    }

    func save(_ edits: UnsavedEdits, accepting offer: SaveOffer?) async throws(PluginError) {
        await withCheckedContinuation { Self.waiting = $0 }
        let text = edits.value as? String ?? ""
        saved.append(text)
        if unsaved == text { unsaved = nil }
    }

    static func release() {
        waiting?.resume()
        waiting = nil
    }
}

@Suite(.serialized) struct ModuleSaving {
    private func open() async throws -> (DocumentViewController, SlowSaveDocument) {
        let url = try TempFile.make(Data("x".utf8), name: "f.bin")
        let document = DocumentViewController(url: url, entry: PluginEntry(SlowSavePlugin.self), config: Config(),
                                              allowsEditing: true, recovery: nil)
        document.loadViewIfNeeded()
        await document.load()
        let plugin = try #require(document.pluginDocument as? SlowSaveDocument)
        return (document, plugin)
    }

    @Test func aSecondSaveWaitsForTheRunningOne() async throws {
        let (document, plugin) = try await open()
        defer { document.close() }
        _ = plugin.restore(encoded: Data("a".utf8))
        let first = Task { await document.save(prompts: StubPrompts()) }
        try await waitUntil(seconds: 2) { SlowSaveDocument.waiting != nil }
        let second = Task { await document.save(prompts: StubPrompts()) }
        try await Task.sleep(for: .milliseconds(50))
        SlowSaveDocument.release()
        #expect(await first.value == .saved)
        #expect(await second.value == .saved)
        #expect(plugin.saved == ["a"])
        #expect(!document.isEdited)
    }

    @Test func aSecondSaveWritesWhatChangedDuringTheFirst() async throws {
        let (document, plugin) = try await open()
        defer { document.close() }
        _ = plugin.restore(encoded: Data("a".utf8))
        let first = Task { await document.save(prompts: StubPrompts()) }
        try await waitUntil(seconds: 2) { SlowSaveDocument.waiting != nil }
        _ = plugin.restore(encoded: Data("ab".utf8))
        let second = Task { await document.save(prompts: StubPrompts()) }
        SlowSaveDocument.release()
        try await waitUntil(seconds: 2) { SlowSaveDocument.waiting != nil }
        SlowSaveDocument.release()
        #expect(await first.value == .saved)
        #expect(await second.value == .saved)
        #expect(plugin.saved == ["a", "ab"])
        #expect(!document.isEdited)
    }
}
