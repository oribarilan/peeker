import AppKit
import Foundation
import PeekerKit
@testable import PeekerText
import Testing

@Suite(.serialized) struct TextSaveIntegrationTests {
    @Test func saveWritesThroughThePluginAndClearsEditedState() async throws {
        let file = try TempFile.make(Data("a\r\nb\r\n".utf8))
        let (document, _) = await open(file)
        defer { document.close() }
        try Self.type("x\ny\n", in: document)
        #expect(document.isEdited)
        #expect(await document.save(prompts: StubPrompts()) == .saved)
        #expect(try Data(contentsOf: file) == Data("x\r\ny\r\n".utf8))
        #expect(!document.isEdited)
    }

    @Test func newerFileOnDiskAsksBeforeOverwriting() async throws {
        let file = try TempFile.make(Data("mine\n".utf8))
        let (document, _) = await open(file)
        defer { document.close() }
        try Self.type("edited\n", in: document)
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
        try Self.type("edited\n", in: document)
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
        try Self.type("🙂", in: document)
        let prompts = StubPrompts()
        prompts.utf8 = true
        #expect(await document.save(prompts: prompts) == .saved)
        #expect(prompts.asked == ["utf8"])
        #expect(try Data(contentsOf: file) == Data("🙂".utf8))
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
        try Self.type("mine\n", in: document)
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
        try Self.type("mine\n", in: document)   // same main-actor turn: before the reply
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
        try Self.type("mine\n", in: document)
        document.discardEdits()
        #expect(!document.isEdited)
        #expect(Self.pending(document) == nil)
        #expect(Self.text(of: document) == "one\n")
    }

    @Test func viewOnlyDocumentHasNoEdits() async throws {
        let file = try TempFile.make(Data("one\n".utf8))
        let document = await loadedDocument(file, with: TextPlugin.self, allowsEditing: false)
        defer { document.close() }
        let text = try #require(Self.textDocument(document))
        #expect(!text.isEditable)
        #expect(text.unsavedEdits() == nil)
    }

    // MARK: Crash recovery

    @Test func editsAreJournaledAfterADelayAndClearedOnSave() async throws {
        let file = try TempFile.make(Data("one\n".utf8))
        let store = Self.temporaryStore()
        let (document, _) = await open(file, recovery: store, journalDelay: Self.journalDelay)
        defer { document.close() }
        try Self.type("mine\n", in: document)
        #expect(store.all().isEmpty, "the journal waits after the last edit")
        try await waitUntil(seconds: 2) { !store.all().isEmpty }
        let record = try #require(store.all().first)
        #expect(store.all().count == 1)
        #expect(record.url == file && record.pluginID == "text" && record.text == "mine\n")
        let modified = try #require(try FileManager.default.attributesOfItem(atPath: file.path)[.modificationDate] as? Date)
        #expect(abs(try #require(record.fileModified).timeIntervalSince(modified)) < 0.001)
        #expect(await document.save(prompts: StubPrompts()) == .saved)
        #expect(store.all().isEmpty)
    }

    @Test func eachEditRestartsTheJournalDelay() async throws {
        let file = try TempFile.make(Data("one\n".utf8))
        let store = Self.temporaryStore()
        let (document, _) = await open(file, recovery: store, journalDelay: Self.journalDelay)
        defer { document.close() }
        try Self.type("a\n", in: document)
        try await Task.sleep(for: .milliseconds(300))
        try Self.type("ab\n", in: document)
        try await Task.sleep(for: .milliseconds(300))  // past the first edit's delay, not the second's
        #expect(store.all().isEmpty)
        try await waitUntil(seconds: 2) { !store.all().isEmpty }
        #expect(store.all().map(\.text) == ["ab\n"])
    }

    @Test func restoredRecordShowsItsEditsMarksEditedAndDontSaveRemovesIt() async throws {
        let file = try TempFile.make(Data("one\n".utf8))
        let store = Self.temporaryStore()
        let id = UUID().uuidString
        let (document, _) = await open(file, recovery: store, recoveryID: id)
        defer { document.close() }
        let record = RecoveryRecord(id: id, url: file, pluginID: "text", fileModified: document.knownModification, text: "recovered\n")
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
        let record = RecoveryRecord(id: id, url: file, pluginID: "text", fileModified: document.knownModification, text: "recovered\n")
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
        let record = RecoveryRecord(id: UUID().uuidString, url: file, pluginID: "text", fileModified: Date(timeIntervalSince1970: 1), text: "mine\n")
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
        let (document, _) = await open(file, recovery: store, journalDelay: Self.journalDelay)
        try Self.type("mine\n", in: document)
        document.discardEdits()
        document.close()
        try await Task.sleep(for: .milliseconds(800))  // past the delay
        #expect(store.all().isEmpty)
    }

    /// Over 10 MB the text opens read-only, so recovered text can't go back in; it must not vanish with the record.
    @Test func readOnlyDocumentRejectsRecoveredTextAndKeepsTheRecord() async throws {
        let file = try TempFile.make(Data(repeating: UInt8(ascii: "a"), count: 10 * 1_048_576 + 1))
        let store = Self.temporaryStore()
        let record = RecoveryRecord(id: UUID().uuidString, url: file, pluginID: "text", fileModified: nil, text: "mine\n")
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
        let record = RecoveryRecord(id: UUID().uuidString, url: file, pluginID: "text", fileModified: nil, text: "one\n")
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
        let document = DocumentViewController(url: file, entry: Self.entry, config: Config(), allowsEditing: true, recovery: store)
        defer { document.close() }
        var results: [RecoveryResult] = []
        document.onRecovery = { results.append($1) }
        document.loadViewIfNeeded()
        let record = RecoveryRecord(id: UUID().uuidString, url: file, pluginID: "text", fileModified: modified, text: "recovered\n")
        document.restore(record)
        await document.load()
        #expect(Self.text(of: document) == "recovered\n")
        #expect(document.isEdited)
        #expect(results.count == 1)
    }

    @Test func closingBeforeTheRestoredFileShowsKeepsTheRecord() async throws {
        let file = try TempFile.make(Data("one\n".utf8))
        let store = Self.temporaryStore()
        let record = RecoveryRecord(id: UUID().uuidString, url: file, pluginID: "text", fileModified: nil, text: "recovered\n")
        try store.write(record)
        let document = DocumentViewController(url: file, entry: Self.entry, config: Config(), allowsEditing: true, recovery: store, recoveryID: record.id)
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
        try Self.type("first\n", in: document)
        try store.write(RecoveryRecord(id: id, url: file, pluginID: "text", fileModified: nil, text: "first\n"))
        // Runs until the save waits for the plugin, so the next edit lands while it's in flight.
        let save = Task.immediate { await document.save(prompts: StubPrompts()) }
        try Self.type("second\n", in: document)
        #expect(await save.value == .saved)
        #expect(try Data(contentsOf: file) == Data("first\n".utf8))
        #expect(document.isEdited)
        #expect(store.all().map(\.text) == ["second\n"])
    }

    /// In place of the 2 s a window uses; the tests check what happens before and after it, not its length.
    private static let journalDelay = 0.5

    private static func temporaryStore() -> RecoveryStore {
        RecoveryStore(directory: FileManager.default.temporaryDirectory.appending(path: "peeker-recovery-\(UUID().uuidString)"))
    }

    private static let entry = PluginEntry(TextPlugin.self)

    /// An editable document window's controller on `file`, loaded through the text plugin.
    private func open(_ file: URL, recovery: RecoveryStore? = nil, recoveryID: String = UUID().uuidString,
                      journalDelay: TimeInterval = 2) async -> (DocumentViewController, TextDocument?) {
        let document = await loadedDocument(file, with: TextPlugin.self, recovery: recovery, recoveryID: recoveryID, journalDelay: journalDelay)
        return (document, Self.textDocument(document))
    }

    private static func textDocument(_ document: DocumentViewController) -> TextDocument? {
        document.pluginDocument as? TextDocument
    }

    private static func text(of document: DocumentViewController) -> String? {
        textDocument(document)?.text
    }

    /// Replaces the whole text, as typing would.
    private static func type(_ text: String, in document: DocumentViewController) throws {
        let edits = try JSONEncoder().encode(TextEdits.text(text))
        #expect(try #require(textDocument(document)).restore(encoded: edits))
    }

    private static func pending(_ document: DocumentViewController) -> String? {
        (textDocument(document)?.unsavedEdits()?.value as? TextEdits)?.text
    }
}
