import AppKit
import Foundation
import PeekerKit
@testable import PeekerText
import Testing

/// Unsaved edits kept for crash recovery and put back, with the text plugin.
@Suite(.serialized) struct CrashRecovery {
    /// In place of the 2 s a window uses; the tests check what happens before and after it, not its length.
    private static let journalDelay = 0.5

    @Test func editsAreJournaledAfterADelayAndClearedOnSave() async throws {
        let file = try TempFile.make(Data("one\n".utf8))
        let store = RecoveryStore.temporary()
        let document = await loadedDocument(file, with: TextPlugin.self, recovery: store, journalDelay: Self.journalDelay)
        defer { document.close() }
        try document.type("mine\n")
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
        let store = RecoveryStore.temporary()
        let document = await loadedDocument(file, with: TextPlugin.self, recovery: store, journalDelay: Self.journalDelay)
        defer { document.close() }
        try document.type("a\n")
        try await Task.sleep(for: .milliseconds(300))
        try document.type("ab\n")
        try await Task.sleep(for: .milliseconds(300))  // past the first edit's delay, not the second's
        #expect(store.all().isEmpty)
        try await waitUntil(seconds: 2) { !store.all().isEmpty }
        #expect(store.all().map(\.text) == ["ab\n"])
    }

    @Test func restoredRecordShowsItsEditsMarksEditedAndDontSaveRemovesIt() async throws {
        let file = try TempFile.make(Data("one\n".utf8))
        let store = RecoveryStore.temporary()
        let id = UUID().uuidString
        let document = await loadedDocument(file, with: TextPlugin.self, recovery: store, recoveryID: id)
        defer { document.close() }
        let record = RecoveryRecord(id: id, url: file, pluginID: "text", fileModified: document.knownModification, text: "recovered\n")
        try store.write(record)
        document.restore(record)
        #expect(document.shownText == "recovered\n")
        #expect(document.isEdited)
        document.discardEdits()
        #expect(store.all().isEmpty)
        #expect(document.shownText == "one\n")
    }

    @Test func restoredRecordSavesAndRemovesItsRecord() async throws {
        let file = try TempFile.make(Data("one\n".utf8))
        let store = RecoveryStore.temporary()
        let id = UUID().uuidString
        let document = await loadedDocument(file, with: TextPlugin.self, recovery: store, recoveryID: id)
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
        let store = RecoveryStore.temporary()
        let record = RecoveryRecord(id: UUID().uuidString, url: file, pluginID: "text", fileModified: Date(timeIntervalSince1970: 1), text: "mine\n")
        let document = await loadedDocument(file, with: TextPlugin.self, recovery: store, recoveryID: record.id)
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
        let store = RecoveryStore.temporary()
        let document = await loadedDocument(file, with: TextPlugin.self, recovery: store, journalDelay: Self.journalDelay)
        try document.type("mine\n")
        document.discardEdits()
        document.close()
        try await Task.sleep(for: .milliseconds(800))  // past the delay
        #expect(store.all().isEmpty)
    }

    /// Over 10 MB the text opens read-only, so recovered text can't go back in; it must not vanish with the record.
    @Test func readOnlyDocumentRejectsRecoveredTextAndKeepsTheRecord() async throws {
        let file = try TempFile.make(Data(repeating: UInt8(ascii: "a"), count: 10 * 1_048_576 + 1))
        let store = RecoveryStore.temporary()
        let record = RecoveryRecord(id: UUID().uuidString, url: file, pluginID: "text", fileModified: nil, text: "mine\n")
        try store.write(record)
        let document = await loadedDocument(file, with: TextPlugin.self, recovery: store, recoveryID: record.id)
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
        let store = RecoveryStore.temporary()
        let record = RecoveryRecord(id: UUID().uuidString, url: file, pluginID: "text", fileModified: nil, text: "one\n")
        try store.write(record)
        let document = await loadedDocument(file, with: TextPlugin.self, recovery: store, recoveryID: record.id)
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
        let store = RecoveryStore.temporary()
        let document = DocumentViewController(url: file, entry: PluginEntry(TextPlugin.self), config: Config(), allowsEditing: true, recovery: store)
        defer { document.close() }
        var results: [RecoveryResult] = []
        document.onRecovery = { results.append($1) }
        document.loadViewIfNeeded()
        let record = RecoveryRecord(id: UUID().uuidString, url: file, pluginID: "text", fileModified: modified, text: "recovered\n")
        document.restore(record)
        await document.load()
        #expect(document.shownText == "recovered\n")
        #expect(document.isEdited)
        #expect(results.count == 1)
    }

    @Test func closingBeforeTheRestoredFileShowsKeepsTheRecord() async throws {
        let file = try TempFile.make(Data("one\n".utf8))
        let store = RecoveryStore.temporary()
        let record = RecoveryRecord(id: UUID().uuidString, url: file, pluginID: "text", fileModified: nil, text: "recovered\n")
        try store.write(record)
        let document = DocumentViewController(url: file, entry: PluginEntry(TextPlugin.self), config: Config(), allowsEditing: true, recovery: store, recoveryID: record.id)
        document.loadViewIfNeeded()
        document.restore(record)
        document.close()
        #expect(store.all() == [record])
    }

    @Test func editsDuringASaveAreRewrittenToTheRecord() async throws {
        let file = try TempFile.make(Data("one\n".utf8))
        let store = RecoveryStore.temporary()
        let id = UUID().uuidString
        let document = await loadedDocument(file, with: TextPlugin.self, recovery: store, recoveryID: id)
        defer { document.close() }
        try document.type("first\n")
        try store.write(RecoveryRecord(id: id, url: file, pluginID: "text", fileModified: nil, text: "first\n"))
        // Runs until the save waits for the plugin, so the next edit lands while it's in flight.
        let save = Task.immediate { await document.save(prompts: StubPrompts()) }
        try document.type("second\n")
        #expect(await save.value == .saved)
        #expect(try Data(contentsOf: file) == Data("first\n".utf8))
        #expect(document.isEdited)
        #expect(store.all().map(\.text) == ["second\n"])
    }
}
