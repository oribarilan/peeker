import AppKit
import PeekerKit
@testable import PeekerImage
@testable import PeekerMarkdown
@testable import PeekerText
import Testing
import UniformTypeIdentifiers

/// A path next to `file` that doesn't exist yet, with the same extension.
func copyPath(beside file: URL) -> URL {
    file.deletingLastPathComponent().appending(path: "copy-\(UUID().uuidString).\(file.pathExtension)")
}

@Suite(.serialized) struct TextSaveAs {
    @Test func theCopyGetsTheEditsAndLaterSavesGoThere() async throws {
        let file = try TempFile.make(Data("original\n".utf8))
        let document = try await openDocument(file, with: TextPlugin.self, as: TextDocument.self)
        #expect(document.restore(encoded: try JSONEncoder().encode(TextEdits(text: "edited\n"))))
        let copy = copyPath(beside: file)
        try await document.saveAs(document.unsavedEdits(), to: copy)
        #expect(try String(contentsOf: copy, encoding: .utf8) == "edited\n")
        #expect(try String(contentsOf: file, encoding: .utf8) == "original\n", "the original stays")
        #expect(document.restore(encoded: try JSONEncoder().encode(TextEdits(text: "again\n"))))
        try await document.save(try #require(document.unsavedEdits()), accepting: nil)
        #expect(try String(contentsOf: copy, encoding: .utf8) == "again\n")
        #expect(try String(contentsOf: file, encoding: .utf8) == "original\n")
    }

    @Test func withoutEditsTheBytesAreCopied() async throws {
        let bytes = Data("line one\r\nline two\n".utf8)  // mixed line endings stay as they are
        let file = try TempFile.make(bytes)
        let document = try await openDocument(file, with: TextPlugin.self, as: TextDocument.self)
        let copy = copyPath(beside: file)
        try await document.saveAs(nil, to: copy)
        #expect(try Data(contentsOf: copy) == bytes)
    }

    @Test func aFailureLeavesTheDocumentOnItsFile() async throws {
        let file = try TempFile.make(Data("original\n".utf8))
        let document = try await openDocument(file, with: TextPlugin.self, as: TextDocument.self)
        #expect(document.restore(encoded: try JSONEncoder().encode(TextEdits(text: "edited\n"))))
        let nowhere = URL(filePath: "/nonexistent-\(UUID().uuidString)/copy.txt")
        await #expect(throws: PluginError.self) { try await document.saveAs(document.unsavedEdits(), to: nowhere) }
        try await document.save(try #require(document.unsavedEdits()), accepting: nil)
        #expect(try String(contentsOf: file, encoding: .utf8) == "edited\n")
    }
}

@Suite(.serialized) struct MarkdownSaveAs {
    @Test func theCopyGetsTheEditsAndLaterSavesGoThere() async throws {
        let file = try TempFile.make(Data("# Original\n".utf8), name: "a.md")
        let editor = try await openDocument(file, with: MarkdownPlugin.self, as: MarkdownEditor.self)
        #expect(editor.restore(encoded: try JSONEncoder().encode(TextEdits(text: "# Edited\n"))))
        let copy = copyPath(beside: file)
        try await editor.saveAs(editor.unsavedEdits(), to: copy)
        #expect(try String(contentsOf: copy, encoding: .utf8) == "# Edited\n")
        #expect(try String(contentsOf: file, encoding: .utf8) == "# Original\n")
        #expect(editor.restore(encoded: try JSONEncoder().encode(TextEdits(text: "# Again\n"))))
        try await editor.save(try #require(editor.unsavedEdits()), accepting: nil)
        #expect(try String(contentsOf: copy, encoding: .utf8) == "# Again\n")
    }
}

@Suite(.serialized) struct ImageSaveAs {
    private func open(_ url: URL) async throws -> ImageDocument {
        try await openDocument(url, with: ImagePlugin.self, as: ImageDocument.self, maxPixels: 4096)
    }

    @Test func theCopyGetsTheCropAndLaterSavesGoThere() async throws {
        let file = try imageFile(try cornerImage(width: 400, height: 200), type: .png)
        let document = try await open(file)
        document.apply(.crop(CGRect(x: 0, y: 0, width: 0.5, height: 1)))
        let copy = copyPath(beside: file)
        try await document.saveAs(document.unsavedEdits(), to: copy)
        #expect(try stored(copy).image.width == 200)
        #expect(try stored(file).image.width == 400, "the original stays")
        document.apply(.crop(CGRect(x: 0, y: 0, width: 0.5, height: 1)))
        try await document.save(try #require(document.unsavedEdits()), accepting: nil)
        #expect(try stored(copy).image.width == 100)
        #expect(try stored(file).image.width == 400)
    }

    @Test func withoutEditsTheBytesAreCopied() async throws {
        let file = try imageFile(try cornerImage(), type: .png)
        let document = try await open(file)
        let copy = copyPath(beside: file)
        try await document.saveAs(nil, to: copy)
        #expect(try Data(contentsOf: copy) == Data(contentsOf: file))
    }
}
