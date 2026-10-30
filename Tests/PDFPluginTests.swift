import AppKit
import PDFKit
import PeekerKit
@testable import PeekerPDF
import Testing

// `PeekerPDF.` picks the PDF plugin's `PeekerPDF.Highlight` and `PeekerPDF.RGBA` over the process protocol's, until the protocol goes away.

nonisolated private let yellow = PeekerPDF.RGBA(red: 1, green: 0.8, blue: 0, alpha: 1)
nonisolated private let rect = CGRect(x: 72, y: 600, width: 200, height: 14)

private func highlights(in file: URL) -> Int {
    PDFDocument(url: file)?.page(at: 0)?.annotations.filter { $0.type == "Highlight" }.count ?? -1
}

private func edits(_ highlights: [PeekerPDF.Highlight]) throws -> Data {
    try JSONEncoder().encode(PDFEdits.pdfHighlights(highlights))
}

private func open(_ file: URL, editable: Bool = true) async throws -> PDFPluginDocument {
    try #require(try await PDFPlugin.open(file, context: OpenContext(maxPixels: 0, allowsEditing: editable)) as? PDFPluginDocument)
}

@Suite struct PDFPluginOpening {
    @Test func offersZoomAndHighlightButNoSave() async throws {
        let document = try await open(try TempFile.makePDF(pages: 1))
        #expect(document.commands.map(\.id) == ["zoom-in", "zoom-out", "highlight"])
    }

    @Test func notAPDFSaysSo() async throws {
        let file = try TempFile.make(Data("plain text".utf8), name: "f.pdf")
        await #expect(throws: PluginError("This file isn't a readable PDF.")) { _ = try await open(file) }
    }

    @Test func lockedPDFSaysSo() async throws {
        let file = try TempFile.make(Data(), name: "f.pdf")
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        let info = [kCGPDFContextUserPassword: "secret", kCGPDFContextOwnerPassword: "secret"] as CFDictionary
        let context = try #require(CGContext(file as CFURL, mediaBox: &box, info))
        context.beginPDFPage(nil)
        context.endPDFPage()
        context.closePDF()
        await #expect(throws: PluginError("This PDF is password protected.")) { _ = try await open(file) }
    }
}

@Suite struct PDFPluginSaving {
    @Test func savedHighlightsAreInTheFile() async throws {
        let file = try TempFile.makePDF(pages: 1)
        try await PDFPlugin.write([PeekerPDF.Highlight(page: 0, rect: rect, color: yellow)], to: file.path)
        let annotations = try #require(PDFDocument(url: file)?.page(at: 0)).annotations.filter { $0.type == "Highlight" }
        #expect(annotations.count == 1)
        #expect(abs(annotations[0].bounds.minX - 72) < 0.5 && abs(annotations[0].bounds.width - 200) < 0.5)
    }

    @Test func refusesReadOnlyPDF() async throws {
        let file = try TempFile.makePDF(pages: 1)
        let bytes = try Data(contentsOf: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: file.path)
        await #expect(throws: PluginError("You don't have permission to save “f.pdf”.", code: .notWritable)) {
            try await PDFPlugin.write([PeekerPDF.Highlight(page: 0, rect: rect, color: yellow)], to: file.path)
        }
        #expect(try Data(contentsOf: file) == bytes)
    }

    @Test(arguments: [
        PeekerPDF.Highlight(page: 1, rect: rect, color: yellow),
        PeekerPDF.Highlight(page: -1, rect: rect, color: yellow),
        PeekerPDF.Highlight(page: 0, rect: CGRect(x: CGFloat.infinity, y: 600, width: 200, height: 14), color: yellow),
        PeekerPDF.Highlight(page: 0, rect: CGRect(x: 72, y: 600, width: CGFloat.nan, height: 14), color: yellow),
        PeekerPDF.Highlight(page: 0, rect: CGRect(x: 272, y: 614, width: -200, height: -14), color: yellow),
        PeekerPDF.Highlight(page: 0, rect: CGRect(x: 1000, y: 600, width: 200, height: 14), color: yellow),
    ])
    func refusesHighlightsOutsideTheDocument(_ highlight: PeekerPDF.Highlight) async throws {
        let file = try TempFile.makePDF(pages: 1)
        let bytes = try Data(contentsOf: file)
        do {
            try await PDFPlugin.write([highlight], to: file.path)
            Issue.record("saved an invalid highlight")
        } catch {
            #expect(error.message.hasPrefix("Can't save a highlight"))
        }
        #expect(try Data(contentsOf: file) == bytes)
    }

    @Test func keepsTheFilePermissions() async throws {
        let file = try TempFile.makePDF(pages: 1)
        try FileManager.default.setAttributes([.posixPermissions: 0o640], ofItemAtPath: file.path)
        try await PDFPlugin.write([PeekerPDF.Highlight(page: 0, rect: rect, color: yellow)], to: file.path)
        #expect(try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? Int == 0o640)
    }
}

@Suite struct PDFPluginEditing {
    @Test func highlightingASelectionIsAnEdit() async throws {
        let document = try await open(try TempFile.makePDF(pages: 1))
        var count = 0
        document.onEdit = { count += 1 }
        #expect(document.unsavedEdits() == nil)
        let page = try #require(document.pdfView.document?.page(at: 0))
        document.pdfView.setCurrentSelection(page.selection(for: page.bounds(for: .mediaBox)), animate: false)
        #expect(document.perform("highlight"))
        let pending = try #require(document.pendingHighlights)
        #expect(count == 1)
        #expect(pending.count == 1 && pending[0].page == 0 && pending[0].color == yellow)
        #expect(page.annotations.count == 1)
    }

    @Test func highlightWithoutASelectionChangesNothing() async throws {
        let document = try await open(try TempFile.makePDF(pages: 1))
        var count = 0
        document.onEdit = { count += 1 }
        #expect(document.perform("highlight"))
        #expect(count == 0 && document.unsavedEdits() == nil)
    }

    @Test func restoreAddsAnnotationsAndPendingHighlights() async throws {
        let document = try await open(try TempFile.makePDF(pages: 2))
        var count = 0
        document.onEdit = { count += 1 }
        let highlight = PeekerPDF.Highlight(page: 1, rect: rect, color: yellow)
        #expect(document.restore(encoded: try edits([highlight])))
        #expect(count == 1)
        #expect(document.pendingHighlights == [highlight])
        #expect(document.pdfView.document?.page(at: 1)?.annotations.count == 1)
    }

    /// Saving refuses the whole file over one bad highlight, so one must never become pending.
    @Test func restoreSkipsHighlightsThatCouldNotBeSaved() async throws {
        let document = try await open(try TempFile.makePDF(pages: 1))
        var count = 0
        document.onEdit = { count += 1 }
        let accepted = document.restore(encoded: try edits([
            PeekerPDF.Highlight(page: 3, rect: rect, color: yellow),
            PeekerPDF.Highlight(page: 0, rect: CGRect(x: 272, y: 614, width: -200, height: -14), color: yellow),
            PeekerPDF.Highlight(page: 0, rect: CGRect(x: 1000, y: 600, width: 200, height: 14), color: yellow),
            PeekerPDF.Highlight(page: 0, rect: rect, color: PeekerPDF.RGBA(red: 2, green: 0, blue: 0, alpha: 1)),
        ]))
        #expect(!accepted)
        #expect(count == 0 && document.unsavedEdits() == nil)
        #expect(document.pdfView.document?.page(at: 0)?.annotations.isEmpty == true)
    }

    @Test func viewOnlyDocumentRefusesEdits() async throws {
        let document = try await open(try TempFile.makePDF(pages: 1), editable: false)
        #expect(!document.restore(encoded: try edits([PeekerPDF.Highlight(page: 0, rect: rect, color: yellow)])))
        #expect(document.commands.map(\.id) == ["zoom-in", "zoom-out"])
    }

    /// A highlight added while the save was in flight isn't on disk, so it stays pending.
    @Test func saveKeepsHighlightsAddedSince() async throws {
        let file = try TempFile.makePDF(pages: 1)
        let document = try await open(file)
        let first = PeekerPDF.Highlight(page: 0, rect: rect, color: yellow)
        let second = PeekerPDF.Highlight(page: 0, rect: rect.offsetBy(dx: 0, dy: -20), color: yellow)
        #expect(document.restore(encoded: try edits([first])))
        let saved = try #require(document.unsavedEdits())
        #expect(document.restore(encoded: try edits([second])))
        try await document.save(saved, accepting: nil)
        #expect(document.pendingHighlights == [second])
        #expect(highlights(in: file) == 1)
    }

    @Test func revertRemovesPendingAnnotationsOnly() async throws {
        let document = try await open(try TempFile.makePDF(pages: 1))
        let saved = PeekerPDF.Highlight(page: 0, rect: rect, color: yellow)
        #expect(document.restore(encoded: try edits([saved])))
        try await document.save(try #require(document.unsavedEdits()), accepting: nil)
        #expect(document.restore(encoded: try edits([PeekerPDF.Highlight(page: 0, rect: rect.offsetBy(dx: 0, dy: -20), color: yellow)])))
        document.revertEdits()
        #expect(document.unsavedEdits() == nil)
        #expect(document.pdfView.document?.page(at: 0)?.annotations.count == 1)
    }

    /// Records written before plugins moved into the app stored edits in this shape.
    @Test func restoresEditsInThePreviousRecordFormat() async throws {
        let document = try await open(try TempFile.makePDF(pages: 1))
        let old = #"{"pdfHighlights":{"_0":[{"page":0,"rect":[[72,600],[200,14]],"color":{"red":1,"green":0.8,"blue":0,"alpha":1}}]}}"#
        #expect(document.restore(encoded: Data(old.utf8)))
        #expect(document.pendingHighlights == [PeekerPDF.Highlight(page: 0, rect: rect, color: yellow)])
    }
}

@Suite(.serialized) struct PDFSaveIntegrationTests {
    @Test func cmdSWritesTheHighlightsAndDoesNotReload() async throws {
        let file = try TempFile.makePDF(pages: 1)
        let document = DocumentViewController(url: file, entry: PluginEntry(PDFPlugin.self), config: Config(),
                                              allowsEditing: true, recovery: nil)
        defer { document.close() }
        document.loadViewIfNeeded()
        await document.load()
        let pdf = try #require(document.pluginDocument as? PDFPluginDocument)
        #expect(pdf.restore(encoded: try edits([PeekerPDF.Highlight(page: 0, rect: rect, color: yellow)])))
        #expect(document.isEdited)
        #expect(await document.save(prompts: StubPrompts()) == .saved)
        #expect(!document.isEdited)
        #expect(pdf.unsavedEdits() == nil)
        #expect(highlights(in: file) == 1)
        try await Task.sleep(for: .milliseconds(700))   // past the watcher's 200 ms coalescing
        #expect(document.pluginDocument === pdf, "our own save must not trigger a reload")
    }
}
