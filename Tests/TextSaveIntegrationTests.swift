import AppKit
import Foundation
import Testing

@Suite(.serialized) struct TextSaveIntegrationTests {
    @Test func openThroughTheRealPluginDeliversTheText() async throws {
        let file = try TempFile.make(Data("one\ntwo\n".utf8))
        let process = PluginProcess(entry: Self.entry, idleSeconds: 5)
        let reply = try await process.request(.open(path: file.path, maxPixels: 0), doc: "d", timeout: PluginTimeout.open)
        guard case .text(let shared) = reply.view else { Issue.record("not text"); return }
        #expect(try SharedFile.withMapped(shared.file) { String(decoding: $0, as: UTF8.self) } == "one\ntwo\n")
        #expect(shared.editable)
    }

    @Test func saveWritesThroughThePluginAndClearsEditedState() async throws {
        let file = try TempFile.make(Data("a\r\nb\r\n".utf8))
        let (document, _) = await open(file)
        defer { document.close() }
        let component = try #require(document.component)
        component.restore(.text("x\ny\n"))
        #expect(document.isEdited)
        #expect(await document.save(prompts: StubPrompts()) == .saved)
        #expect(try Data(contentsOf: file) == Data("x\r\ny\r\n".utf8))
        #expect(!document.isEdited)
    }

    @Test func newerFileOnDiskAsksBeforeOverwriting() async throws {
        let file = try TempFile.make(Data("mine\n".utf8))
        let (document, _) = await open(file)
        defer { document.close() }
        try #require(document.component).restore(.text("edited\n"))
        try Data("theirs\n".utf8).write(to: file)
        try FileManager.default.setAttributes([.modificationDate: Date.now.addingTimeInterval(10)], ofItemAtPath: file.path)
        let prompts = StubPrompts()
        prompts.overwrite = false
        #expect(await document.save(prompts: prompts) == .cancelled)
        #expect(prompts.asked == ["overwrite"])
        #expect(try Data(contentsOf: file) == Data("theirs\n".utf8))
        #expect(document.isEdited)
    }

    @Test func savingAFileDeletedSinceOpeningAsksThenCreatesItAgain() async throws {
        let file = try TempFile.make(Data("mine\n".utf8))
        let (document, _) = await open(file)
        defer { document.close() }
        try #require(document.component).restore(.text("edited\n"))
        try FileManager.default.removeItem(at: file)
        let prompts = StubPrompts()
        prompts.recreate = false
        #expect(await document.save(prompts: prompts) == .cancelled)
        #expect(!FileManager.default.fileExists(atPath: file.path))
        prompts.recreate = true
        #expect(await document.save(prompts: prompts) == .saved)
        #expect(prompts.asked == ["recreate", "recreate"])
        #expect(try Data(contentsOf: file) == Data("edited\n".utf8))
        #expect(!document.isEdited)
    }

    @Test func unencodableTextOffersUTF8() async throws {
        let file = try TempFile.make(Data([0x63, 0x61, 0x66, 0xE9]))   // "café" in Windows-1252
        let (document, _) = await open(file)
        defer { document.close() }
        try #require(document.component).restore(.text("🙂"))
        let prompts = StubPrompts()
        prompts.utf8 = true
        #expect(await document.save(prompts: prompts) == .saved)
        #expect(prompts.asked == ["utf8"])
        #expect(try Data(contentsOf: file) == Data("🙂".utf8))
    }

    @Test func pluginCrashDuringSaveKeepsTheEdits() async throws {
        // The test plugin aborts when it receives the save, so the crash lands while the save is in flight.
        let file = try TempFile.make(Data("mine\n".utf8), name: "crash-on-save.txt")
        let (document, _) = await open(file, entry: TestProducts.entry(id: "test", executable: "test-plugin", types: []))
        defer { document.close() }
        let component = try #require(document.component)
        component.restore(.text("edited\n"))
        let outcome = await document.save(prompts: StubPrompts())
        guard case .failed = outcome else { Issue.record("expected a failure, got \(outcome)"); return }
        #expect(component.pendingEdits() == .text("edited\n"))
        #expect(document.component === component)
        #expect(document.isEdited)
        #expect(try Data(contentsOf: file) == Data("mine\n".utf8))
    }

    @Test func pluginCrashWithUnsavedEditsKeepsThemAndTheNextSaveWorks() async throws {
        let file = try TempFile.make(Data("mine\n".utf8))
        let (document, process) = await open(file)
        defer { document.close() }
        let component = try #require(document.component)
        component.restore(.text("edited\n"))
        kill(try #require(process.pid), SIGKILL)
        try await waitUntil(seconds: 2) { !process.isRunning }   // the host has handled the crash
        #expect(document.component === component)
        #expect(document.isEdited)
        #expect(await document.save(prompts: StubPrompts()) == .saved)
        #expect(try Data(contentsOf: file) == Data("edited\n".utf8))
        #expect(!document.isEdited)
    }

    @Test func reloadsWhenTheFileChangesWithoutEdits() async throws {
        let file = try TempFile.make(Data("one\n".utf8))
        let (document, _) = await open(file)
        defer { document.close() }
        try Data("one\ntwo\n".utf8).write(to: file, options: .atomic)
        try await waitUntil(seconds: 2) { Self.text(of: document) == "one\ntwo\n" }
        #expect(!document.isEdited)
    }

    @Test func changeOnDiskNeverReplacesUnsavedEdits() async throws {
        let file = try TempFile.make(Data("one\n".utf8))
        let (document, _) = await open(file)
        defer { document.close() }
        try #require(document.component).restore(.text("mine\n"))
        try Data("theirs\n".utf8).write(to: file, options: .atomic)
        try await Task.sleep(for: .milliseconds(700))   // past the watcher's 200 ms coalescing and a reload
        #expect(Self.text(of: document) == "mine\n")
        let prompts = StubPrompts()
        #expect(await document.save(prompts: prompts) == .saved)
        #expect(prompts.asked == ["overwrite"])
        #expect(try Data(contentsOf: file) == Data("mine\n".utf8))
    }

    /// The user types after a reload request went out but before its reply: the reply is dropped, so the document
    /// still predates the file on disk and saving must ask.
    @Test func reloadDroppedForEditsStillAsksBeforeOverwriting() async throws {
        let file = try TempFile.make(Data("one\n".utf8))
        let (document, _) = await open(file)
        defer { document.close() }
        try Data("theirs\n".utf8).write(to: file)
        try FileManager.default.setAttributes([.modificationDate: Date.now.addingTimeInterval(10)], ofItemAtPath: file.path)
        document.reloadIfChangedOnDisk()
        try #require(document.component).restore(.text("mine\n"))   // same main-actor turn: before the reply
        try await Task.sleep(for: .milliseconds(300))
        #expect(Self.text(of: document) == "mine\n")
        let prompts = StubPrompts()
        prompts.overwrite = false
        #expect(await document.save(prompts: prompts) == .cancelled)
        #expect(prompts.asked == ["overwrite"])
        #expect(try Data(contentsOf: file) == Data("theirs\n".utf8))
    }

    @Test func discardEditsRevertsToTheSavedText() async throws {
        let file = try TempFile.make(Data("one\n".utf8))
        let (document, _) = await open(file)
        defer { document.close() }
        let component = try #require(document.component)
        component.restore(.text("mine\n"))
        document.discardEdits()
        #expect(!document.isEdited)
        #expect(component.pendingEdits() == nil)
        #expect(Self.text(of: document) == "one\n")
    }

    @Test func viewOnlyDocumentHasNoEdits() async throws {
        let file = try TempFile.make(Data("one\n".utf8))
        let process = PluginProcess(entry: Self.entry, idleSeconds: 5)
        let document = DocumentViewController(url: file, entry: Self.entry, process: process, config: Config(), allowsEditing: false, recovery: nil)
        defer { document.close() }
        document.loadViewIfNeeded()
        await document.load()
        let text = try #require(document.component as? TextComponent)
        #expect(!text.isEditable)
        #expect(text.pendingEdits() == nil)
    }

    // MARK: Crash recovery

    @Test func editsAreJournaledAfterTwoSecondsAndClearedOnSave() async throws {
        let file = try TempFile.make(Data("one\n".utf8))
        let store = Self.temporaryStore()
        let (document, _) = await open(file, recovery: store)
        defer { document.close() }
        try #require(document.component).restore(.text("mine\n"))
        try await Task.sleep(for: .milliseconds(1500))
        #expect(store.all().isEmpty, "the journal waits 2 s after the last edit")
        try await Task.sleep(for: .milliseconds(1000))
        let record = try #require(store.all().first)
        #expect(store.all().count == 1)
        #expect(record.url == file && record.pluginID == "text" && record.edits == .text("mine\n"))
        let modified = try #require(try FileManager.default.attributesOfItem(atPath: file.path)[.modificationDate] as? Date)
        #expect(abs(try #require(record.fileModified).timeIntervalSince(modified)) < 0.001)
        #expect(await document.save(prompts: StubPrompts()) == .saved)
        #expect(store.all().isEmpty)
    }

    @Test func eachEditRestartsTheJournalDelay() async throws {
        let file = try TempFile.make(Data("one\n".utf8))
        let store = Self.temporaryStore()
        let (document, _) = await open(file, recovery: store)
        defer { document.close() }
        let component = try #require(document.component)
        component.restore(.text("a\n"))
        try await Task.sleep(for: .milliseconds(1500))
        component.restore(.text("ab\n"))
        try await Task.sleep(for: .milliseconds(1000))
        #expect(store.all().isEmpty)
        try await waitUntil(seconds: 2) { !store.all().isEmpty }
        #expect(store.all().map(\.edits) == [.text("ab\n")])
    }

    @Test func restoredRecordShowsItsEditsMarksEditedAndDontSaveRemovesIt() async throws {
        let file = try TempFile.make(Data("one\n".utf8))
        let store = Self.temporaryStore()
        let id = UUID().uuidString
        let (document, _) = await open(file, recovery: store, recoveryID: id)
        defer { document.close() }
        let record = RecoveryRecord(id: id, url: file, pluginID: "text", fileModified: document.knownModification, edits: .text("recovered\n"))
        try store.write(record)
        document.restore(record)
        #expect(Self.text(of: document) == "recovered\n")
        #expect(document.isEdited)
        document.discardEdits()
        #expect(store.all().isEmpty)
        #expect(Self.text(of: document) == "one\n")
    }

    @Test func restoredRecordSavesAndRemovesItsRecord() async throws {
        let file = try TempFile.make(Data("one\n".utf8))
        let store = Self.temporaryStore()
        let id = UUID().uuidString
        let (document, _) = await open(file, recovery: store, recoveryID: id)
        defer { document.close() }
        let record = RecoveryRecord(id: id, url: file, pluginID: "text", fileModified: document.knownModification, edits: .text("recovered\n"))
        try store.write(record)
        document.restore(record)
        let prompts = StubPrompts()
        #expect(await document.save(prompts: prompts) == .saved)
        #expect(prompts.asked.isEmpty)
        #expect(try Data(contentsOf: file) == Data("recovered\n".utf8))
        #expect(store.all().isEmpty)
    }

    /// The edits were made against an older version of the file, so saving them still asks before replacing it.
    @Test func recoveredEditsForAChangedFileAskBeforeOverwriting() async throws {
        let file = try TempFile.make(Data("theirs\n".utf8))
        let store = Self.temporaryStore()
        let record = RecoveryRecord(id: UUID().uuidString, url: file, pluginID: "text", fileModified: Date(timeIntervalSince1970: 1), edits: .text("mine\n"))
        let (document, _) = await open(file, recovery: store, recoveryID: record.id)
        defer { document.close() }
        var results: [RecoveryResult] = []
        document.onRecovery = { results.append($1) }
        document.restore(record)
        #expect(results == [.restored(fileChangedSince: true)])
        let prompts = StubPrompts()
        prompts.overwrite = false
        #expect(await document.save(prompts: prompts) == .cancelled)
        #expect(prompts.asked == ["overwrite"])
    }

    @Test func closingWithoutEditsLeavesNoRecord() async throws {
        let file = try TempFile.make(Data("one\n".utf8))
        let store = Self.temporaryStore()
        let (document, _) = await open(file, recovery: store)
        let component = try #require(document.component)
        component.restore(.text("mine\n"))
        document.discardEdits()
        document.close()
        try await Task.sleep(for: .milliseconds(2300))
        #expect(store.all().isEmpty)
    }

    /// Over 10 MB the text opens read-only, so recovered text can't go back in; it must not vanish with the record.
    @Test func readOnlyDocumentRejectsRecoveredTextAndKeepsTheRecord() async throws {
        let file = try TempFile.make(Data(repeating: UInt8(ascii: "a"), count: 10 * 1_048_576 + 1))
        let store = Self.temporaryStore()
        let record = RecoveryRecord(id: UUID().uuidString, url: file, pluginID: "text", fileModified: nil, edits: .text("mine\n"))
        try store.write(record)
        let (document, _) = await open(file, recovery: store, recoveryID: record.id)
        var results: [RecoveryResult] = []
        document.onRecovery = { results.append($1) }
        document.restore(record)
        #expect(results == [.rejected(record)])
        let edited = document.isEdited   // a failing #expect on the document itself would describe its 10 MB text view
        #expect(!edited)
        document.close()
        #expect(store.all() == [record])
    }

    @Test func recoveredTextMatchingTheFileRemovesTheRecord() async throws {
        let file = try TempFile.make(Data("one\n".utf8))
        let store = Self.temporaryStore()
        let record = RecoveryRecord(id: UUID().uuidString, url: file, pluginID: "text", fileModified: nil, edits: .text("one\n"))
        try store.write(record)
        let (document, _) = await open(file, recovery: store, recoveryID: record.id)
        defer { document.close() }
        var results: [RecoveryResult] = []
        document.onRecovery = { results.append($1) }
        document.restore(record)
        #expect(results.isEmpty)
        #expect(!document.isEdited)
        #expect(store.all().isEmpty)
    }

    @Test func restoreBeforeLoadAppliesOnceTheFileShows() async throws {
        let file = try TempFile.make(Data("one\n".utf8))
        let modified = try FileManager.default.attributesOfItem(atPath: file.path)[.modificationDate] as? Date
        let store = Self.temporaryStore()
        let process = PluginProcess(entry: Self.entry, idleSeconds: 5)
        let document = DocumentViewController(url: file, entry: Self.entry, process: process, config: Config(), allowsEditing: true, recovery: store)
        defer { document.close() }
        var results: [RecoveryResult] = []
        document.onRecovery = { results.append($1) }
        document.loadViewIfNeeded()
        let record = RecoveryRecord(id: UUID().uuidString, url: file, pluginID: "text", fileModified: modified, edits: .text("recovered\n"))
        document.restore(record)
        await document.load()
        #expect(Self.text(of: document) == "recovered\n")
        #expect(document.isEdited)
        #expect(results.count == 1)
    }

    @Test func closingBeforeTheRestoredFileShowsKeepsTheRecord() async throws {
        let file = try TempFile.make(Data("one\n".utf8))
        let store = Self.temporaryStore()
        let record = RecoveryRecord(id: UUID().uuidString, url: file, pluginID: "text", fileModified: nil, edits: .text("recovered\n"))
        try store.write(record)
        let process = PluginProcess(entry: Self.entry, idleSeconds: 5)
        let document = DocumentViewController(url: file, entry: Self.entry, process: process, config: Config(), allowsEditing: true, recovery: store, recoveryID: record.id)
        document.loadViewIfNeeded()
        document.restore(record)
        document.close()
        #expect(store.all() == [record])
    }

    @Test func editsDuringASaveAreRewrittenToTheRecord() async throws {
        let file = try TempFile.make(Data("one\n".utf8))
        let store = Self.temporaryStore()
        let id = UUID().uuidString
        let (document, _) = await open(file, recovery: store, recoveryID: id)
        defer { document.close() }
        let component = try #require(document.component)
        component.restore(.text("first\n"))
        try store.write(RecoveryRecord(id: id, url: file, pluginID: "text", fileModified: nil, edits: .text("first\n")))
        // Runs until the save waits for the plugin, so the next edit lands while it's in flight.
        let save = Task.immediate { await document.save(prompts: StubPrompts()) }
        component.restore(.text("second\n"))
        #expect(await save.value == .saved)
        #expect(try Data(contentsOf: file) == Data("first\n".utf8))
        #expect(document.isEdited)
        #expect(store.all().map(\.edits) == [.text("second\n")])
    }

    private static func temporaryStore() -> RecoveryStore {
        RecoveryStore(directory: FileManager.default.temporaryDirectory.appending(path: "peeker-recovery-\(UUID().uuidString)"))
    }

    private static let entry = TestProducts.entry(id: "text", executable: "text-plugin", types: ["public.plain-text"])

    /// An editable document window's controller on `file`, loaded through the real text plugin.
    private func open(_ file: URL, entry: PluginEntry = Self.entry, recovery: RecoveryStore? = nil, recoveryID: String = UUID().uuidString) async -> (DocumentViewController, PluginProcess) {
        // A save to a plugin that just died writes to a closed pipe; the app ignores SIGPIPE the same way.
        signal(SIGPIPE, SIG_IGN)
        let process = PluginProcess(entry: entry, idleSeconds: 5)
        let document = DocumentViewController(url: file, entry: entry, process: process, config: Config(), allowsEditing: true, recovery: recovery, recoveryID: recoveryID)
        document.loadViewIfNeeded()
        await document.load()
        return (document, process)
    }

    private static func text(of document: DocumentViewController) -> String? {
        ((document.component as? TextComponent)?.focusView as? NSTextView)?.string
    }
}

final class StubPrompts: SavePrompts {
    var overwrite = true
    var utf8 = true
    var recreate = true
    /// Which prompts ran, in order: "overwrite", "recreate", "utf8".
    var asked: [String] = []

    func confirmOverwriteNewerFile(named: String) async -> Bool {
        asked.append("overwrite")
        return overwrite
    }

    func confirmSaveAsUTF8(reason: String) async -> Bool {
        asked.append("utf8")
        return utf8
    }

    func confirmRecreateMissingFile(named: String) async -> Bool {
        asked.append("recreate")
        return recreate
    }
}
