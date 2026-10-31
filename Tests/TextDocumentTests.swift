import AppKit
import PeekerKit
@testable import PeekerText
import Testing

private func open(_ text: String, editable: Bool = true) async throws -> (URL, TextDocument) {
    let file = try TempFile.make(Data(text.utf8))
    let document = try await openDocument(file, with: TextPlugin.self, as: TextDocument.self, editing: editable)
    return (file, document)
}

private func restore(_ text: String, in document: TextDocument) throws -> Bool {
    document.restore(encoded: try JSONEncoder().encode(TextEdits.text(text)))
}

private func pending(_ document: TextDocument) -> String? {
    (document.unsavedEdits()?.value as? TextEdits)?.text
}

@Suite struct TextDocumentViewTests {
    @Test func reloadKeepsZoomAndWrap() async throws {
        let (file, document) = try await open("a")
        #expect(document.perform("zoom-in") && document.perform("toggle-wrap"))
        try Data("b".utf8).write(to: file)
        #expect(try await document.reload())
        let view = try #require(document.focusView as? NSTextView)
        #expect(view.string == "b")
        #expect(view.font?.pointSize == 13)
        #expect(view.textContainer?.widthTracksTextView == false)
    }

    /// A log that grows past the edit limit turns read-only in the same view, with the note bar appearing.
    @Test func reloadAcrossTheEditLimitKeepsTheView() async throws {
        let (file, document) = try await open("a\n")
        let view = document.contentView
        #expect(document.isEditable && document.note == nil)
        let line = Data(repeating: UInt8(ascii: "a"), count: 99) + Data([0x0A])
        var bytes = Data(capacity: TextLimits.editableBytes + line.count)
        while bytes.count <= TextLimits.editableBytes { bytes.append(line) }
        try bytes.write(to: file)
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        #expect(try await document.reload())
        #expect(document.contentView === view)
        #expect(!document.isEditable)
        #expect(document.note == TextPlugin.readOnlyNote)
    }

    @Test func viewOnlyDocumentTakesNoEdits() async throws {
        let (_, document) = try await open("a", editable: false)
        #expect(!document.isEditable)
        #expect(!(try restore("b", in: document)))
        #expect(document.unsavedEdits() == nil)
    }
}

@Suite struct TextDocumentEditingTests {
    @Test func editsAreTheTextThatDiffersFromTheBaseline() async throws {
        let (_, document) = try await open("a")
        var edits = 0
        document.onEdit = { edits += 1 }
        #expect(pending(document) == nil)
        #expect(try restore("b", in: document))
        #expect(edits == 1)
        #expect(pending(document) == "b")
        try await document.save(try #require(document.unsavedEdits()), accepting: nil)
        #expect(pending(document) == nil)
    }

    /// Typing while a save is in flight isn't on disk, so it stays pending, whoever else asked for the edits meanwhile.
    @Test func saveMovesTheBaselineToTheSavedTextOnly() async throws {
        let (_, document) = try await open("a")
        #expect(try restore("b", in: document))
        let saved = try #require(document.unsavedEdits())
        #expect(try restore("c", in: document))
        _ = document.unsavedEdits()   // another reader, such as crash recovery
        try await document.save(saved, accepting: nil)
        #expect(pending(document) == "c")
        #expect(try restore("b", in: document))
        #expect(pending(document) == nil)
    }

    @Test func revertGoesBackToTheBaseline() async throws {
        let (_, document) = try await open("a")
        #expect(try restore("b", in: document))
        document.revertEdits()
        #expect(pending(document) == nil)
        #expect(document.text == "a")
    }

    @Test func reloadedTextIsTheNewBaseline() async throws {
        let (file, document) = try await open("a")
        try Data("b".utf8).write(to: file)
        #expect(try await document.reload())
        #expect(pending(document) == nil)
    }

    /// Canonically equivalent but different code points ("é" vs "e" + combining acute) still count as an edit.
    @Test func equivalentButDifferentTextIsAnEdit() async throws {
        let (_, document) = try await open("\u{E9}")
        #expect(try restore("e\u{301}", in: document))
        #expect(pending(document) == "e\u{301}")
    }

    /// Records written before plugins moved into the app stored text edits in this shape.
    @Test func restoresEditsInThePreviousRecordFormat() async throws {
        let (_, document) = try await open("a")
        #expect(document.restore(encoded: Data(#"{"text":{"_0":"recovered"}}"#.utf8)))
        #expect(pending(document) == "recovered")
    }
}
