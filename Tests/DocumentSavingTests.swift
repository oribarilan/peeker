import AppKit
import Foundation
import PeekerKit
@testable import PeekerText
import Testing

/// Saving through the host: prompts, outside changes and reloads, with the text plugin.
@Suite(.serialized) struct DocumentSaving {
    @Test func saveWritesThroughThePluginAndClearsEditedState() async throws {
        let file = try TempFile.make(Data("a\r\nb\r\n".utf8))
        let document = await loadedDocument(file, with: TextPlugin.self)
        defer { document.close() }
        try document.type("x\ny\n")
        #expect(document.isEdited)
        #expect(await document.save(prompts: StubPrompts()) == .saved)
        #expect(try Data(contentsOf: file) == Data("x\r\ny\r\n".utf8))
        #expect(!document.isEdited)
    }

    @Test func newerFileOnDiskAsksBeforeOverwriting() async throws {
        let file = try TempFile.make(Data("mine\n".utf8))
        let document = await loadedDocument(file, with: TextPlugin.self)
        defer { document.close() }
        try document.type("edited\n")
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
        let document = await loadedDocument(file, with: TextPlugin.self)
        defer { document.close() }
        try document.type("edited\n")
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
        let document = await loadedDocument(file, with: TextPlugin.self)
        defer { document.close() }
        try document.type("🙂")
        let prompts = StubPrompts()
        prompts.utf8 = true
        #expect(await document.save(prompts: prompts) == .saved)
        #expect(prompts.asked == ["utf8"])
        #expect(try Data(contentsOf: file) == Data("🙂".utf8))
    }

    @Test func reloadsWhenTheFileChangesWithoutEdits() async throws {
        let file = try TempFile.make(Data("one\n".utf8))
        let document = await loadedDocument(file, with: TextPlugin.self)
        defer { document.close() }
        try Data("one\ntwo\n".utf8).write(to: file, options: .atomic)
        try await waitUntil(seconds: 2) { document.shownText == "one\ntwo\n" }
        #expect(!document.isEdited)
    }

    @Test func changeOnDiskNeverReplacesUnsavedEdits() async throws {
        let file = try TempFile.make(Data("one\n".utf8))
        let document = await loadedDocument(file, with: TextPlugin.self)
        defer { document.close() }
        try document.type("mine\n")
        try Data("theirs\n".utf8).write(to: file, options: .atomic)
        try await Task.sleep(for: .milliseconds(700))   // past the watcher's 200 ms coalescing and a reload
        #expect(document.shownText == "mine\n")
        let prompts = StubPrompts()
        #expect(await document.save(prompts: prompts) == .saved)
        #expect(prompts.asked == ["overwrite"])
        #expect(try Data(contentsOf: file) == Data("mine\n".utf8))
    }

    /// The user types after a reload request went out but before its reply: the reply is dropped, so the document
    /// still predates the file on disk and saving must ask.
    @Test func reloadDroppedForEditsStillAsksBeforeOverwriting() async throws {
        let file = try TempFile.make(Data("one\n".utf8))
        let document = await loadedDocument(file, with: TextPlugin.self)
        defer { document.close() }
        try Data("theirs\n".utf8).write(to: file)
        try FileManager.default.setAttributes([.modificationDate: Date.now.addingTimeInterval(10)], ofItemAtPath: file.path)
        document.reloadIfChangedOnDisk()
        try document.type("mine\n")   // same main-actor turn: before the reply
        try await Task.sleep(for: .milliseconds(300))
        #expect(document.shownText == "mine\n")
        let prompts = StubPrompts()
        prompts.overwrite = false
        #expect(await document.save(prompts: prompts) == .cancelled)
        #expect(prompts.asked == ["overwrite"])
        #expect(try Data(contentsOf: file) == Data("theirs\n".utf8))
    }

    @Test func discardEditsRevertsToTheSavedText() async throws {
        let file = try TempFile.make(Data("one\n".utf8))
        let document = await loadedDocument(file, with: TextPlugin.self)
        defer { document.close() }
        try document.type("mine\n")
        document.discardEdits()
        #expect(!document.isEdited)
        #expect(document.pendingText == nil)
        #expect(document.shownText == "one\n")
    }

    @Test func viewOnlyDocumentHasNoEdits() async throws {
        let file = try TempFile.make(Data("one\n".utf8))
        let document = await loadedDocument(file, with: TextPlugin.self, allowsEditing: false)
        defer { document.close() }
        let text = try #require(document.textDocument)
        #expect(!text.isEditable)
        #expect(text.unsavedEdits() == nil)
    }
}
