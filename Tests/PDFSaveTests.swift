import AppKit
import PDFKit
import Testing

@Suite struct PDFSaveTests {
    nonisolated static let yellow = RGBA(red: 1, green: 0.8, blue: 0, alpha: 1)

    @Test func savedHighlightsAreInTheFile() throws {
        let file = try TempFile.makePDF(pages: 1)
        let plugin = PDFPlugin()
        _ = try plugin.open("d", path: file.path, maxPixels: 0)
        let highlight = Highlight(page: 0, rect: CGRect(x: 72, y: 600, width: 200, height: 14), color: Self.yellow)
        _ = try plugin.save("d", .pdfHighlights([highlight]))
        let annotations = try #require(PDFDocument(url: file)?.page(at: 0)).annotations.filter { $0.type == "Highlight" }
        #expect(annotations.count == 1)
        #expect(abs(annotations[0].bounds.minX - 72) < 0.5 && abs(annotations[0].bounds.width - 200) < 0.5)
    }

    @Test func refusesReadOnlyPDF() throws {
        let file = try TempFile.makePDF(pages: 1)
        let bytes = try Data(contentsOf: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: file.path)
        let plugin = PDFPlugin()
        _ = try plugin.open("d", path: file.path, maxPixels: 0)
        let error = #expect(throws: PluginFailure.self) {
            try plugin.save("d", .pdfHighlights([Highlight(page: 0, rect: CGRect(x: 72, y: 600, width: 200, height: 14), color: Self.yellow)]))
        }
        #expect(error == PluginFailure("You don't have permission to save “f.pdf”.", code: .notWritable))
        #expect(try Data(contentsOf: file) == bytes)
    }

    @Test(arguments: [
        Highlight(page: 1, rect: CGRect(x: 72, y: 600, width: 200, height: 14), color: PDFSaveTests.yellow),
        Highlight(page: -1, rect: CGRect(x: 72, y: 600, width: 200, height: 14), color: PDFSaveTests.yellow),
        Highlight(page: 0, rect: CGRect(x: CGFloat.infinity, y: 600, width: 200, height: 14), color: PDFSaveTests.yellow),
        Highlight(page: 0, rect: CGRect(x: 72, y: 600, width: CGFloat.nan, height: 14), color: PDFSaveTests.yellow),
        Highlight(page: 0, rect: CGRect(x: 272, y: 614, width: -200, height: -14), color: PDFSaveTests.yellow),
        Highlight(page: 0, rect: CGRect(x: 1000, y: 600, width: 200, height: 14), color: PDFSaveTests.yellow),
    ])
    func refusesHighlightsOutsideTheDocument(_ highlight: Highlight) throws {
        let file = try TempFile.makePDF(pages: 1)
        let bytes = try Data(contentsOf: file)
        let plugin = PDFPlugin()
        _ = try plugin.open("d", path: file.path, maxPixels: 0)
        let error = #expect(throws: PluginFailure.self) { try plugin.save("d", .pdfHighlights([highlight])) }
        #expect(error?.message.hasPrefix("Can't save a highlight") == true)
        #expect(try Data(contentsOf: file) == bytes)
    }

    @Test func keepsTheFilePermissions() throws {
        let file = try TempFile.makePDF(pages: 1)
        try FileManager.default.setAttributes([.posixPermissions: 0o640], ofItemAtPath: file.path)
        let plugin = PDFPlugin()
        _ = try plugin.open("d", path: file.path, maxPixels: 0)
        _ = try plugin.save("d", .pdfHighlights([Highlight(page: 0, rect: CGRect(x: 72, y: 600, width: 200, height: 14), color: Self.yellow)]))
        #expect(try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? Int == 0o640)
    }

    @Test func savingAnUnopenedDocumentFails() throws {
        #expect(throws: PluginFailure.self) { try PDFPlugin().save("d", .pdfHighlights([])) }
    }

    @Test func replyHasNoSaveCommand() throws {
        let reply = try PDFPlugin().open("d", path: try TempFile.makePDF(pages: 1).path, maxPixels: 0)
        #expect(reply.commands?.map(\.id) == ["zoom-in", "zoom-out", "highlight"])
    }
}

@Suite struct PDFComponentEditingTests {
    private static let rect = CGRect(x: 72, y: 600, width: 200, height: 14)
    private static let yellow = RGBA(red: 1, green: 0.8, blue: 0, alpha: 1)

    @Test func highlightingASelectionIsAnEdit() throws {
        let pdf = try PDFComponent(url: try TempFile.makePDF(pages: 1))
        var edits = 0
        pdf.onEdit = { edits += 1 }
        #expect(pdf.pendingEdits() == nil)
        let page = try #require(pdf.pdfView.document?.page(at: 0))
        pdf.pdfView.setCurrentSelection(page.selection(for: page.bounds(for: .mediaBox)), animate: false)
        #expect(pdf.perform("highlight"))
        guard case .pdfHighlights(let highlights) = pdf.pendingEdits() else { Issue.record("no highlights"); return }
        #expect(edits == 1)
        #expect(highlights.count == 1 && highlights[0].page == 0 && highlights[0].color == Self.yellow)
        #expect(page.annotations.count == 1)
    }

    @Test func highlightWithoutASelectionChangesNothing() throws {
        let pdf = try PDFComponent(url: try TempFile.makePDF(pages: 1))
        var edits = 0
        pdf.onEdit = { edits += 1 }
        #expect(pdf.perform("highlight"))
        #expect(edits == 0 && pdf.pendingEdits() == nil)
    }

    @Test func restoreAddsAnnotationsAndPendingHighlights() throws {
        let pdf = try PDFComponent(url: try TempFile.makePDF(pages: 2))
        var edits = 0
        pdf.onEdit = { edits += 1 }
        let highlight = Highlight(page: 1, rect: Self.rect, color: Self.yellow)
        pdf.restore(.pdfHighlights([highlight]))
        #expect(edits == 1)
        #expect(pdf.pendingEdits() == .pdfHighlights([highlight]))
        #expect(pdf.pdfView.document?.page(at: 1)?.annotations.count == 1)
    }

    @Test func restoreSkipsHighlightsOnMissingPages() throws {
        let pdf = try PDFComponent(url: try TempFile.makePDF(pages: 1))
        var edits = 0
        pdf.onEdit = { edits += 1 }
        pdf.restore(.pdfHighlights([Highlight(page: 3, rect: Self.rect, color: Self.yellow)]))
        #expect(edits == 0 && pdf.pendingEdits() == nil)
    }

    /// The plugin refuses the whole save over one bad highlight, so one must never become pending.
    @Test func restoreSkipsHighlightsThePluginWouldRefuse() throws {
        let pdf = try PDFComponent(url: try TempFile.makePDF(pages: 1))
        var edits = 0
        pdf.onEdit = { edits += 1 }
        pdf.restore(.pdfHighlights([
            Highlight(page: 0, rect: CGRect(x: 72, y: 600, width: CGFloat.nan, height: 14), color: Self.yellow),
            Highlight(page: 0, rect: CGRect(x: CGFloat.infinity, y: 600, width: 200, height: 14), color: Self.yellow),
            Highlight(page: 0, rect: CGRect(x: 272, y: 614, width: -200, height: -14), color: Self.yellow),
            Highlight(page: 0, rect: CGRect(x: 1000, y: 600, width: 200, height: 14), color: Self.yellow),
            Highlight(page: 0, rect: Self.rect, color: RGBA(red: 2, green: 0, blue: 0, alpha: 1)),
        ]))
        #expect(edits == 0 && pdf.pendingEdits() == nil)
        #expect(pdf.pdfView.document?.page(at: 0)?.annotations.isEmpty == true)
    }

    /// A highlight added while the save was in flight isn't on disk, so it stays pending.
    @Test func didSaveKeepsHighlightsAddedDuringTheSave() throws {
        let pdf = try PDFComponent(url: try TempFile.makePDF(pages: 1))
        let first = Highlight(page: 0, rect: Self.rect, color: Self.yellow)
        let second = Highlight(page: 0, rect: Self.rect.offsetBy(dx: 0, dy: -20), color: Self.yellow)
        pdf.restore(.pdfHighlights([first]))
        let saved = try #require(pdf.pendingEdits())
        pdf.restore(.pdfHighlights([second]))
        pdf.didSave(saved)
        #expect(pdf.pendingEdits() == .pdfHighlights([second]))
        #expect(pdf.pdfView.document?.page(at: 0)?.annotations.count == 2)
    }

    @Test func revertRemovesPendingAnnotationsOnly() throws {
        let pdf = try PDFComponent(url: try TempFile.makePDF(pages: 1))
        let saved = Highlight(page: 0, rect: Self.rect, color: Self.yellow)
        pdf.restore(.pdfHighlights([saved]))
        pdf.didSave(.pdfHighlights([saved]))
        pdf.restore(.pdfHighlights([Highlight(page: 0, rect: Self.rect.offsetBy(dx: 0, dy: -20), color: Self.yellow)]))
        pdf.revertEdits()
        #expect(pdf.pendingEdits() == nil)
        #expect(pdf.pdfView.document?.page(at: 0)?.annotations.count == 1)
    }

    @Test func saveIsNoLongerAComponentVerb() throws {
        let pdf = try PDFComponent(url: try TempFile.makePDF(pages: 1))
        #expect(!pdf.perform("save"))
    }
}

@Suite(.serialized) struct PDFSaveIntegrationTests {
    private static let entry = TestProducts.entry(id: "pdf", executable: "pdf-plugin", types: ["com.adobe.pdf"])

    @Test func cmdSSendsHighlightsToThePluginWhichWritesTheFile() async throws {
        let file = try TempFile.makePDF(pages: 1)
        let process = PluginProcess(entry: Self.entry, idleSeconds: 5)
        let document = DocumentViewController(url: file, entry: Self.entry, process: process, config: Config(), allowsEditing: true, recovery: nil)
        defer { document.close() }
        document.loadViewIfNeeded()
        await document.load()
        let highlight = Highlight(page: 0, rect: CGRect(x: 72, y: 600, width: 200, height: 14), color: RGBA(red: 1, green: 0.8, blue: 0, alpha: 1))
        let component = try #require(document.component)
        component.restore(.pdfHighlights([highlight]))
        #expect(document.isEdited)
        #expect(await document.save(prompts: StubPrompts()) == .saved)
        #expect(!document.isEdited)
        #expect(component.pendingEdits() == nil)
        #expect(PDFDocument(url: file)?.page(at: 0)?.annotations.filter { $0.type == "Highlight" }.count == 1)
        try await Task.sleep(for: .milliseconds(700))   // past the watcher's 200 ms coalescing
        #expect(document.component === component, "our own save must not trigger a reload")
    }
}
