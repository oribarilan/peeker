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
        #expect(await document.saveAs(to: copy) == .saved)
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
        guard case .failed = await document.saveAs(to: nowhere) else { Issue.record("saved"); return }
        #expect(document.url == file && document.isEdited)
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
