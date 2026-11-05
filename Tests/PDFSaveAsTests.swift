import AppKit
import PDFKit
import PeekerKit
@testable import PeekerPDF
import Testing

@Suite(.serialized) struct PDFSaveAs {
    private func open(_ file: URL) async throws -> PDFPluginDocument {
        let document = try await openDocument(file, with: PDFPlugin.self, as: PDFPluginDocument.self)
        document.undoManager.groupsByEvent = false
        return document
    }

    @Test func theCopyGetsTheEditsAndLaterSavesGoThere() async throws {
        let file = try TempFile.makePDF(pages: 3)
        let document = try await open(file)
        #expect(document.perform("delete-page"))
        let copy = file.deletingLastPathComponent().appending(path: "copy-\(UUID().uuidString).pdf")
        try await document.saveAs(document.unsavedEdits(), to: copy)
        #expect(PDFDocument(url: copy)?.pageCount == 2)
        #expect(PDFDocument(url: file)?.pageCount == 3, "the original stays")
        #expect(document.change(.rotatePages(pages: [0], by: 90)))
        try await document.save(try #require(document.unsavedEdits()), accepting: nil)
        #expect(PDFDocument(url: copy)?.page(at: 0)?.rotation == 90)
        #expect(PDFDocument(url: file)?.page(at: 0)?.rotation == 0)
    }

    @Test func aSignedPDFIsCopiedByteForByte() async throws {
        let file = try FormPDF.make(acroForm: "/SigFlags 3")
        let document = try await open(file)
        let copy = file.deletingLastPathComponent().appending(path: "copy-\(UUID().uuidString).pdf")
        try await document.saveAs(document.unsavedEdits(), to: copy)
        #expect(try Data(contentsOf: copy) == Data(contentsOf: file))
    }
}
