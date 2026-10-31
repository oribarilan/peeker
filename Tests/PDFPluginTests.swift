import AppKit
import PDFKit
import PeekerKit
@testable import PeekerPDF
import Testing

nonisolated private let yellow = RGBA(red: 1, green: 0.8, blue: 0, alpha: 1)
nonisolated private let rect = CGRect(x: 72, y: 600, width: 200, height: 14)

private func highlights(in file: URL) -> Int {
    PDFDocument(url: file)?.page(at: 0)?.annotations.filter { $0.type == "Highlight" }.count ?? -1
}

private func highlight(_ id: String = PDFEdit.newID(), page: Int = 0, rect: CGRect = rect, color: RGBA = yellow) -> PDFEdit {
    .add(PDFMark(id: id, page: page, rect: rect, kind: .highlight(color)))
}

private func encoded(_ edits: [PDFEdit]) throws -> Data {
    try JSONEncoder().encode(PDFEdits.operations(edits))
}

private func open(_ file: URL, editable: Bool = true) async throws -> PDFPluginDocument {
    try #require(try await PDFPlugin.open(file, context: OpenContext(maxPixels: 0, allowsEditing: editable)) as? PDFPluginDocument)
}

@Suite struct PDFPluginOpening {
    @Test func offersZoomAndTheEditTools() async throws {
        let document = try await open(try TempFile.makePDF(pages: 1))
        #expect(document.commands.map(\.id) == PDFPlugin.commands.map(\.id))
        #expect(document.commands.filter(\.isEditTool).map(\.id) == ["text-box", "sign", "highlight", "rotate-left", "rotate-right", "delete-page"])
    }

    @Test func notAPDFSaysSo() async throws {
        let file = try TempFile.make(Data("plain text".utf8), name: "f.pdf")
        await #expect(throws: PluginError("This file isn't a readable PDF.")) { _ = try await open(file) }
    }

}

@Suite struct PDFRefusingToEdit {
    private func restricted(_ permissions: UInt) throws -> URL {
        let plain = try #require(PDFDocument(url: try TempFile.makePDF(pages: 1)))
        let file = try TempFile.make(Data(), name: "f.pdf")
        #expect(plain.write(to: file, withOptions: [.ownerPasswordOption: "owner", .accessPermissionsOption: NSNumber(value: permissions)]))
        return file
    }

    @Test func anXFAFormCantBeEdited() async throws {
        let file = try FormPDF.make(acroForm: "/XFA 16 0 R", extra: ["<< /Length 5 >>\nstream\n<xdp>\nendstream"])
        #expect(try await open(file).editMode == .unavailable(reason: "This form uses XFA, which Peeker can't fill."))
    }

    @Test func aSignedPDFCantBeEdited() async throws {
        let document = try await open(try FormPDF.make(acroForm: "/SigFlags 3"))
        #expect(document.editMode == .unavailable(reason: "This PDF is digitally signed; changing it would break the signature."))
        #expect(document.pdfView.document?.pageCount == 1, "it still opens")
    }

    @Test func formsWithoutSignaturesCanBeEdited() async throws {
        #expect(try await open(try FormPDF.make()).editMode == .available)
        #expect(try await open(try FormPDF.make(acroForm: "/SigFlags 2")).editMode == .available, "append-only alone isn't a signature")
    }

    @Test func aPDFWhosePermissionsForbidChangesCantBeEdited() async throws {
        let document = try await open(try restricted(1))  // printing only
        #expect(document.editMode == .unavailable(reason: "This PDF's permissions don't allow changes."))
    }

    /// Forms often forbid changing the pages but allow comments and filling in, which is all Edit mode does.
    @Test func aPDFThatAllowsCommentsAndFormsCanBeEdited() async throws {
        #expect(try await open(try restricted(1 | 64 | 128)).editMode == .available)
    }

    @Test func theSpacePanelNeverOffersEditMode() async throws {
        #expect(try await open(try FormPDF.make(acroForm: "/SigFlags 3"), editable: false).editMode == .none)
    }
}

@Suite struct PDFPluginEditing {
    @Test func opensInTheReadViewWithAnEditMode() async throws {
        let document = try await open(try TempFile.makePDF(pages: 1))
        #expect(document.editMode == .available && !document.isEditing)
    }

    @Test func highlightingASelectionIsAnEdit() async throws {
        let document = try await open(try TempFile.makePDF(pages: 1))
        document.setEditing(true)
        var count = 0
        document.onEdit = { count += 1 }
        #expect(document.unsavedEdits() == nil)
        let page = try #require(document.pdfView.document?.page(at: 0))
        document.pdfView.setCurrentSelection(page.selection(for: page.bounds(for: .mediaBox)), animate: false)
        #expect(document.perform("highlight"))
        #expect(count == 1)
        guard document.pendingEdits.count == 1, case .add(let mark) = document.pendingEdits[0] else { Issue.record("\(document.pendingEdits)"); return }
        #expect(mark.page == 0 && mark.kind == .highlight(yellow) && mark.id.hasPrefix("peeker-"))
        #expect(page.annotations.count == 1)
        #expect(PDFMarks.id(of: page.annotations[0]) == mark.id)
    }

    @Test func highlightDoesNothingInTheReadView() async throws {
        let document = try await open(try TempFile.makePDF(pages: 1))
        let page = try #require(document.pdfView.document?.page(at: 0))
        document.pdfView.setCurrentSelection(page.selection(for: page.bounds(for: .mediaBox)), animate: false)
        #expect(!document.perform("highlight"))
        #expect(document.unsavedEdits() == nil)
    }

    @Test func highlightWithoutASelectionChangesNothing() async throws {
        let document = try await open(try TempFile.makePDF(pages: 1))
        document.setEditing(true)
        var count = 0
        document.onEdit = { count += 1 }
        #expect(document.perform("highlight"))
        #expect(count == 0 && document.unsavedEdits() == nil)
    }

    @Test func restoreAppliesTheEdits() async throws {
        let document = try await open(try TempFile.makePDF(pages: 2))
        var count = 0
        document.onEdit = { count += 1 }
        let edit = highlight(page: 1)
        #expect(document.restore(encoded: try encoded([edit])))
        #expect(count == 1)
        #expect(document.pendingEdits == [edit])
        #expect(document.pdfView.document?.page(at: 1)?.annotations.count == 1)
    }

    /// Saving refuses the whole file over one bad edit, so one must never become pending.
    @Test func restoreSkipsEditsThatCouldNotBeSaved() async throws {
        let document = try await open(try TempFile.makePDF(pages: 1))
        var count = 0
        document.onEdit = { count += 1 }
        let accepted = document.restore(encoded: try encoded([
            highlight(page: 3),
            highlight(rect: CGRect(x: 272, y: 614, width: -200, height: -14)),
            highlight(rect: CGRect(x: 1000, y: 600, width: 200, height: 14)),
            highlight(color: RGBA(red: 2, green: 0, blue: 0, alpha: 1)),
            .setBounds(id: "peeker-gone", type: .signature, page: 0, rect: rect),
        ]))
        #expect(!accepted)
        #expect(count == 0 && document.unsavedEdits() == nil)
        #expect(document.pdfView.document?.page(at: 0)?.annotations.isEmpty == true)
    }

    /// Recovery records are read from disk at launch; a page number like Int.max must be refused, never trap.
    @Test func restoreRefusesAnAbsurdPage() async throws {
        let document = try await open(try TempFile.makePDF(pages: 1))
        #expect(!document.restore(encoded: try encoded([highlight(page: Int.max)])))
        let old = #"{"pdfHighlights":{"_0":[{"page":9223372036854775807,"rect":[[72,600],[200,14]],"color":{"red":1,"green":0.8,"blue":0,"alpha":1}}]}}"#
        #expect(!document.restore(encoded: Data(old.utf8)))
    }

    /// Old highlight records come from builds that edited any PDF; a signed one must not take them.
    @Test func aPDFThatCantBeEditedRefusesRecoveredEdits() async throws {
        let document = try await open(try FormPDF.make(acroForm: "/SigFlags 3"))
        #expect(!document.restore(encoded: try encoded([highlight()])))
        #expect(document.unsavedEdits() == nil)
    }

    @Test func viewOnlyDocumentRefusesEditsAndHasNoEditMode() async throws {
        let document = try await open(try TempFile.makePDF(pages: 1), editable: false)
        #expect(!document.restore(encoded: try encoded([highlight()])))
        #expect(document.commands.map(\.id) == ["zoom-in", "zoom-out"])
        #expect(document.editMode == .none)
    }

    /// An edit made while the save was in flight isn't on disk, so it stays pending.
    @Test func saveKeepsEditsMadeSince() async throws {
        let file = try TempFile.makePDF(pages: 1)
        let document = try await open(file)
        let first = highlight(), second = highlight(rect: rect.offsetBy(dx: 0, dy: -20))
        #expect(document.restore(encoded: try encoded([first])))
        let saved = try #require(document.unsavedEdits())
        #expect(document.restore(encoded: try encoded([second])))
        try await document.save(saved, accepting: nil)
        #expect(document.pendingEdits == [second])
        #expect(highlights(in: file) == 1)
    }

    /// A move of a mark added before the save started must not add it a second time on the next save.
    @Test func aMoveDuringASaveIsSavedAsAMove() async throws {
        let file = try TempFile.makePDF(pages: 1)
        let document = try await open(file)
        let id = PDFEdit.newID()
        #expect(document.change(highlight(id)))
        let saved = try #require(document.unsavedEdits())
        let moved = rect.offsetBy(dx: 0, dy: -40)
        #expect(document.change(.setBounds(id: id, type: .highlight, page: 0, rect: moved)))
        try await document.save(saved, accepting: nil)
        try await document.save(try #require(document.unsavedEdits()), accepting: nil)
        let annotations = try #require(PDFDocument(url: file)?.page(at: 0)?.annotations)
        #expect(annotations.count == 1)
        #expect(abs((annotations.first?.bounds.minY ?? 0) - moved.minY) < 0.5)
    }

    @Test func revertRemovesUnsavedMarksAndRestoresChangedOnes() async throws {
        let document = try await open(try TempFile.makePDF(pages: 1))
        let id = PDFEdit.newID()
        #expect(document.change(highlight(id)))
        try await document.save(try #require(document.unsavedEdits()), accepting: nil)
        #expect(document.change(.setBounds(id: id, type: .highlight, page: 0, rect: rect.offsetBy(dx: 0, dy: -50))))
        #expect(document.change(highlight(rect: rect.offsetBy(dx: 0, dy: -20))))
        document.revertEdits()
        #expect(document.unsavedEdits() == nil)
        let annotations = try #require(document.pdfView.document?.page(at: 0)?.annotations)
        #expect(annotations.count == 1)
        #expect(annotations.first?.bounds.minY == rect.minY)
    }

    /// Records written before edit mode stored highlights in this shape.
    @Test func restoresEditsInThePreviousRecordFormat() async throws {
        let document = try await open(try TempFile.makePDF(pages: 1))
        let old = #"{"pdfHighlights":{"_0":[{"page":0,"rect":[[72,600],[200,14]],"color":{"red":1,"green":0.8,"blue":0,"alpha":1}}]}}"#
        #expect(document.restore(encoded: Data(old.utf8)))
        guard case .add(let mark) = document.pendingEdits.first else { Issue.record("nothing restored"); return }
        #expect(mark.rect == rect && mark.kind == .highlight(yellow))
    }
}

@Suite(.serialized) struct PDFSaveIntegrationTests {
    /// The spec's read-view scenario: select text, press the shortcut, and Edit mode turns on and highlights it.
    @Test func highlightFromTheReadViewTurnsOnEditModeAndHighlights() async throws {
        let file = try TempFile.makePDF(pages: 1)
        let document = DocumentViewController(url: file, entry: PluginEntry(PDFPlugin.self), config: Config(),
                                              allowsEditing: true, recovery: nil)
        defer { document.close() }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 900), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentViewController = document
        await document.load()
        let pdf = try #require(document.pluginDocument as? PDFPluginDocument)
        let page = try #require(pdf.pdfView.document?.page(at: 0))
        pdf.pdfView.setCurrentSelection(page.selection(for: page.bounds(for: .mediaBox)), animate: false)
        let highlight = try #require(document.commands.first { $0.spec.id == "highlight" })
        document.run(highlight.spec)
        #expect(document.isEditing)
        #expect(page.annotations.contains { $0.type == "Highlight" })
        #expect(document.isEdited)
    }

    @Test func cmdSWritesTheHighlightsAndDoesNotReload() async throws {
        let file = try TempFile.makePDF(pages: 1)
        let document = DocumentViewController(url: file, entry: PluginEntry(PDFPlugin.self), config: Config(),
                                              allowsEditing: true, recovery: nil)
        defer { document.close() }
        document.loadViewIfNeeded()
        await document.load()
        let pdf = try #require(document.pluginDocument as? PDFPluginDocument)
        #expect(pdf.restore(encoded: try encoded([highlight()])))
        #expect(document.isEdited)
        #expect(await document.save(prompts: StubPrompts()) == .saved)
        #expect(!document.isEdited)
        #expect(pdf.unsavedEdits() == nil)
        #expect(highlights(in: file) == 1)
        try await Task.sleep(for: .milliseconds(700))   // past the watcher's 200 ms coalescing
        #expect(document.pluginDocument === pdf, "our own save must not trigger a reload")
    }
}
