import AppKit
import PeekerKit
import Testing

private enum AskingPlugin: Plugin {
    static let id = "asking"
    static let name = "Asking"
    static let defaultExtensions: [String] = []
    static let tools: [ToolSpec] = []

    static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument { AskingDocument() }
}

/// Offers another way to save, then is cancelled while taking it, as a PDF does when its open password is asked for.
private final class AskingDocument: PluginDocument {
    static let offer = SaveOffer(id: "ask", button: "Enter Password…", detail: "")
    let contentView = NSView()
    var onEdit: (() -> Void)?
    var editability: Editability { .editable }
    func unsavedEdits() -> UnsavedEdits? { UnsavedEdits("edit") }
    func save(_ edits: UnsavedEdits, accepting offer: SaveOffer?) async throws(PluginError) {
        throw offer == nil ? PluginError("Needs a password.", offer: Self.offer) : .cancelled
    }
    func saveAs(_ edits: UnsavedEdits?, to destination: URL, accepting offer: SaveOffer?) async throws(PluginError) {
        throw offer == nil ? PluginError("Needs a password.", offer: Self.offer) : .cancelled
    }
}

@Suite(.serialized) struct SaveCancelling {
    @Test func aSaveTheUserCancelsIsCancelledNotFailed() async throws {
        let document = await loadedDocument(try TempFile.make(Data("x".utf8), name: "f.bin"), with: AskingPlugin.self)
        defer { document.close() }
        (document.pluginDocument as? AskingDocument)?.onEdit?()
        #expect(document.isEdited)
        #expect(await document.save(prompts: StubPrompts()) == .cancelled)
        let copy = FileManager.default.temporaryDirectory.appending(path: "copy-\(UUID().uuidString).bin")
        #expect(await document.saveAs(to: copy, prompts: StubPrompts()) == .cancelled)
        #expect(document.isEdited)
    }
}
