import AppKit
import PeekerKit
import Testing

/// Shows a file's text. Tests set the hooks they need before opening.
private enum Stub: Plugin {
    static let id = "stub"
    static let name = "Stub"
    static let defaultExtensions: [String] = []
    static let commands = [CommandSpec(id: "go", title: "Go")]
    /// Runs once, after an open has read the file and before it returns.
    static var duringOpen: (() throws -> Void)?
    /// Whether documents reload in place, and how long each reload takes after its read, oldest first; then none.
    static var reloadsInPlace = false
    static var reloadTimes: [Duration] = []
    static var reloadFails = false

    static func reset() {
        duringOpen = nil
        reloadsInPlace = false
        reloadTimes = []
        reloadFails = false
    }

    static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument {
        let text = StubDocument.read(url)
        await Task.yield()  // a real open reads off the main thread, so it always suspends
        if let step = duringOpen {
            duringOpen = nil
            try? step()
        }
        return StubDocument(url: url, text: text)
    }
}

private final class StubDocument: PluginDocument {
    let contentView = NSView()
    let url: URL
    private(set) var text: String
    private var edited = false
    var onEdit: (() -> Void)?
    var commands: [CommandSpec] { Stub.commands }
    var editMode: EditMode { .available }

    init(url: URL, text: String) {
        self.url = url
        self.text = text
    }

    static func read(_ url: URL) -> String { (try? String(contentsOf: url, encoding: .utf8)) ?? "" }

    func edit() {
        edited = true
        onEdit?()
    }

    func unsavedEdits() -> UnsavedEdits? { edited ? UnsavedEdits(text) : nil }

    func reload() async throws(PluginError) -> Bool {
        guard Stub.reloadsInPlace else { return false }
        if Stub.reloadFails { throw PluginError("The file can't be read.") }
        let read = Self.read(url)
        let time = Stub.reloadTimes.isEmpty ? .zero : Stub.reloadTimes.removeFirst()
        try? await Task.sleep(for: time)
        text = read
        return true
    }
}

@Suite(.serialized) struct DocumentReloading {
    private func open(_ file: URL) async -> DocumentViewController {
        let document = DocumentViewController(url: file, entry: PluginEntry(Stub.self), config: Config(), allowsEditing: true, recovery: nil)
        document.loadViewIfNeeded()
        await document.load()
        return document
    }

    private func text(of document: DocumentViewController) -> String? {
        (document.pluginDocument as? StubDocument)?.text
    }

    /// Writes `text` with a modification date `seconds` from now, in whole seconds so it reads back exactly.
    @discardableResult
    private func write(_ text: String, to file: URL, secondsFromNow seconds: Double) throws -> Date {
        try Data(text.utf8).write(to: file)
        let date = Date(timeIntervalSince1970: (Date.now.timeIntervalSince1970 + seconds).rounded(.down))
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: file.path)
        return date
    }

    /// Another app writes between the plugin's read and the open's return: the window must not keep the older text.
    @Test func aWriteDuringTheOpenIsPickedUp() async throws {
        Stub.reset()
        let file = try TempFile.make(Data("old".utf8), name: "f.stub")
        Stub.duringOpen = { try write("new", to: file, secondsFromNow: 10) }
        let document = await open(file)
        defer { document.close() }
        try await waitUntil(seconds: 2) { text(of: document) == "new" }
    }

    /// A document with no in-place reload is opened again; edits made during that open must survive it.
    @Test func editsMadeWhileTheFileReopensAreKept() async throws {
        Stub.reset()
        let file = try TempFile.make(Data("old".utf8), name: "f.stub")
        let document = await open(file)
        defer { document.close() }
        let first = try #require(document.pluginDocument as? StubDocument)
        try write("new", to: file, secondsFromNow: 10)
        document.reloadIfChangedOnDisk()
        first.edit()  // same main-actor turn: before the open returns
        try await Task.sleep(for: .milliseconds(200))
        #expect(document.pluginDocument === first)
        #expect(document.isEdited)
    }

    /// A slow reload that started first must not finish last and put older text back.
    @Test func reloadsRunOneAtATimeAndEndOnTheNewestFile() async throws {
        Stub.reset()
        Stub.reloadsInPlace = true
        Stub.reloadTimes = [.milliseconds(300), .milliseconds(10)]
        let file = try TempFile.make(Data("one".utf8), name: "f.stub")
        let document = await open(file)
        defer { document.close() }
        try write("two", to: file, secondsFromNow: 10)
        document.reloadIfChangedOnDisk()
        let newest = try write("three", to: file, secondsFromNow: 20)
        document.reloadIfChangedOnDisk()
        try await Task.sleep(for: .milliseconds(700))  // past both reloads and the watcher's 200 ms
        #expect(text(of: document) == "three")
        #expect(document.knownModification == newest)
    }

    /// The failure view has nothing to run, so the toolbar and menu must not keep offering the document's commands.
    @Test func aFailedReloadDropsTheCommandsAndEditMode() async throws {
        Stub.reset()
        Stub.reloadsInPlace = true
        Stub.reloadFails = true
        let file = try TempFile.make(Data("old".utf8), name: "f.stub")
        let document = await open(file)
        defer { document.close() }
        await document.toggleEditing { true }
        #expect(document.isEditing && document.commands.count == 1)
        var told = 0
        document.onCommandsChanged = { _ in told += 1 }
        try write("new", to: file, secondsFromNow: 10)
        document.reloadIfChangedOnDisk()
        try await waitUntil(seconds: 2) { document.pluginDocument == nil }
        #expect(document.commands.isEmpty)
        #expect(!document.isEditing)
        #expect(told == 1)
    }
}
