import AppKit
import PeekerKit
@testable import PeekerText
import Testing

@MainActor private func type(_ text: String, in document: DocumentViewController) throws {
    let view = try #require(document.pluginDocument?.focusView as? NSTextView)
    view.insertText(text, replacementRange: NSRange(location: 0, length: 0))
}

@Suite(.serialized) struct HostSaveAs {
    @Test func theDocumentFollowsTheNewFile() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "peeker-recovery-\(UUID().uuidString)")
        let store = RecoveryStore(directory: folder)
        let file = try TempFile.make(Data("original\n".utf8))
        let document = await loadedDocument(file, with: TextPlugin.self, recovery: store, journalDelay: 0)
        try type("new ", in: document)
        #expect(document.isEdited)
        let copy = copyPath(beside: file)
        #expect(await document.saveAs(to: copy, prompts: StubPrompts()) == .saved)
        #expect(document.url == copy && !document.isEdited)
        #expect(try String(contentsOf: copy, encoding: .utf8) == "new original\n")
        #expect(try String(contentsOf: file, encoding: .utf8) == "original\n")
        try type("more ", in: document)
        try await waitUntil(seconds: 3) { store.all().map(\.url) == [copy] }  // recovery follows the new file
        #expect(await document.save(prompts: StubPrompts()) == .saved)
        #expect(try String(contentsOf: copy, encoding: .utf8) == "more new original\n")
        #expect(try String(contentsOf: file, encoding: .utf8) == "original\n")
    }

    @Test func aFailureLeavesItOnTheOriginalWithItsEdits() async throws {
        let file = try TempFile.make(Data("original\n".utf8))
        let document = await loadedDocument(file, with: TextPlugin.self)
        try type("new ", in: document)
        let nowhere = URL(filePath: "/nonexistent-\(UUID().uuidString)/copy.txt")
        guard case .failed = await document.saveAs(to: nowhere, prompts: StubPrompts()) else { Issue.record("saved"); return }
        #expect(document.url == file && document.isEdited)
    }

    @Test func textTheEncodingCantHoldAsksToSaveAsUTF8() async throws {
        let file = try TempFile.make(Data([0x63, 0x61, 0x66, 0xE9]))   // "café" in Windows-1252
        let document = await loadedDocument(file, with: TextPlugin.self)
        defer { document.close() }
        try document.type("🙂")
        let prompts = StubPrompts()
        let copy = copyPath(beside: file)
        #expect(await document.saveAs(to: copy, prompts: prompts) == .saved)
        #expect(prompts.asked == ["utf8"])
        #expect(try Data(contentsOf: copy) == Data("🙂".utf8))
        #expect(try Data(contentsOf: file) == Data([0x63, 0x61, 0x66, 0xE9]))
        #expect(document.url == copy && !document.isEdited)
    }

    @Test func decliningUTF8LeavesItOnTheOriginalWithItsEdits() async throws {
        let file = try TempFile.make(Data([0x63, 0x61, 0x66, 0xE9]))
        let document = await loadedDocument(file, with: TextPlugin.self)
        defer { document.close() }
        try document.type("🙂")
        let prompts = StubPrompts()
        prompts.utf8 = false
        let copy = copyPath(beside: file)
        #expect(await document.saveAs(to: copy, prompts: prompts) == .cancelled)
        #expect(prompts.asked == ["utf8"])
        #expect(!FileManager.default.fileExists(atPath: copy.path))
        #expect(document.url == file && document.isEdited && document.pendingText == "🙂")
    }

    @Test func aDestinationOpenInAnotherWindowIsRefused() async throws {
        let first = try await documentWindow(for: TextPlugin.self, name: "a.txt")
        let second = try await documentWindow(for: TextPlugin.self, name: "b.txt")
        defer { first.window?.close(); second.window?.close() }
        var said: String?
        first.present = { _, title, _ in said = title }
        let before = try Data(contentsOf: second.url)
        #expect(await first.saveAs(to: second.url) == false)
        #expect(said?.contains("open in another window") == true)
        #expect(try Data(contentsOf: second.url) == before)
    }

    @Test func theWindowFollowsTheNewFile() async throws {
        let controller = try await documentWindow(for: TextPlugin.self, name: "a.txt")
        defer { controller.window?.close() }
        let copy = copyPath(beside: controller.url)
        #expect(await controller.saveAs(to: copy))
        #expect(controller.url == copy && controller.window?.title == copy.lastPathComponent && controller.window?.representedURL == copy)
        #expect(controller.history.current.url == copy)
    }
}

@Suite struct SameFile {
    @Test func pathsDifferingOnlyInCaseNameTheSameFileOnThisDisk() throws {
        let file = try TempFile.make(Data("x".utf8), name: "Photo.txt")
        let lower = file.deletingLastPathComponent().appending(path: "photo.txt")
        let caseSensitive = !FileManager.default.fileExists(atPath: lower.path)
        #expect(DocumentWindowController.sameFile(file, lower) == !caseSensitive)
        #expect(!DocumentWindowController.sameFile(file, copyPath(beside: file)))
    }
}
