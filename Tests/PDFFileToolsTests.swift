import AppKit
import PDFKit
import PeekerKit
@testable import PeekerPDF
import Testing

@MainActor private func open(_ file: URL) async throws -> PDFPluginDocument {
    let document = try await openDocument(file, with: PDFPlugin.self, as: PDFPluginDocument.self)
    document.undoManager.groupsByEvent = false
    return document
}

/// The text of each page, as `TempFile.makePDF(texts:)` drew it.
@MainActor private func texts(_ document: PDFDocument?) -> [String] {
    guard let document else { return [] }
    return (0..<document.pageCount).map { document.page(at: $0)?.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" }
}

/// A PNG of `width` by `height` pixels.
private func png(width: Int, height: Int) throws -> URL {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let url = try TempFile.make(try #require(rep.representation(using: .png, properties: [:])), name: "photo.png")
    return url
}

@Suite(.serialized) struct PDFInsertPages {
    @Test func anotherPDFsPagesGoAfterTheShownPageAndUndoTakesThemOut() async throws {
        let document = try await open(try TempFile.makePDF(texts: ["One", "Two"]))
        #expect(await document.insertPages(from: [try TempFile.makePDF(texts: ["A", "B"])]))
        #expect(texts(document.pdfView.document) == ["One", "A", "B", "Two"])
        document.undoManager.undo()
        #expect(texts(document.pdfView.document) == ["One", "Two"])
        document.undoManager.redo()
        #expect(texts(document.pdfView.document) == ["One", "A", "B", "Two"])
    }

    @Test func anImageBecomesAPageOfItsSize() async throws {
        let document = try await open(try TempFile.makePDF(texts: ["One"]))
        #expect(await document.insertPages(from: [try png(width: 300, height: 200)]))
        let page = try #require(document.pdfView.document?.page(at: 1))
        #expect(page.bounds(for: .mediaBox).size == CGSize(width: 300, height: 200))
    }

    @Test func insertedPagesAreSavedAndComeBackFromRecovery() async throws {
        let file = try TempFile.makePDF(texts: ["One", "Two"])
        let document = try await open(file)
        #expect(await document.insertPages(from: [try TempFile.makePDF(texts: ["A"])]))
        let record = try #require(document.unsavedEdits()).encoded()
        try await document.save(try #require(document.unsavedEdits()), accepting: nil)
        #expect(texts(PDFDocument(url: file)) == ["One", "A", "Two"])
        let fresh = try await open(try TempFile.makePDF(texts: ["One", "Two"]))
        #expect(fresh.restore(encoded: record))
        #expect(texts(fresh.pdfView.document) == ["One", "A", "Two"])
    }

    @Test func somethingElseIsRefusedWithItsName() async throws {
        let document = try await open(try TempFile.makePDF(texts: ["One"]))
        let notes = try TempFile.make(Data("hello".utf8), name: "notes.txt")
        await #expect(throws: PluginError.self) { try await PDFPluginDocument.insertable(from: [notes]) }
        #expect(!(await document.insertPages(from: [notes])))
        #expect(document.pdfView.document?.pageCount == 1)
    }
}

@Suite(.serialized) struct PDFExportAndSplit {
    @Test func savingSelectedPagesWritesThemAndLeavesTheDocument() async throws {
        let document = try await open(try TempFile.makePDF(texts: ["One", "Two", "Three", "Four"]))
        #expect(document.change(.rotatePages(pages: [2], by: 90)))
        let out = FileManager.default.temporaryDirectory.appending(path: "pages-\(UUID().uuidString).pdf")
        try await document.writePages([2, 3], to: out)
        let written = PDFDocument(url: out)
        #expect(texts(written) == ["Three", "Four"] && written?.page(at: 0)?.rotation == 90, "as shown, edits included")
        #expect(document.pdfView.document?.pageCount == 4)
    }

    @Test func splittingEveryPageOrAtPagesNamesFilesWithoutOverwriting() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "split-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appending(path: "book.pdf")
        try FileManager.default.copyItem(at: try TempFile.makePDF(texts: ["1", "2", "3", "4", "5"]), to: file)
        try Data("keep".utf8).write(to: folder.appending(path: "book 1.pdf"))
        let document = try await open(file)
        let written = try await document.split(at: [0, 2, 4])
        #expect(written.map(\.lastPathComponent) == ["book 2.pdf", "book 3.pdf", "book 4.pdf"])
        #expect(texts(PDFDocument(url: written[0])) == ["1", "2"] && texts(PDFDocument(url: written[2])) == ["5"])
        #expect(try String(contentsOf: folder.appending(path: "book 1.pdf"), encoding: .utf8) == "keep")
        #expect(PDFPluginDocument.splitStarts(every: true, selected: [3], pageCount: 5) == [0, 1, 2, 3, 4])
        #expect(PDFPluginDocument.splitStarts(every: false, selected: [3, 1], pageCount: 5) == [0, 1, 3])
    }

    @Test func theFileToolsAreInTheFileMenu() {
        let file = PDFPlugin.tools.filter { $0.menu == .file }.map(\.id)
        #expect(file == ["insert-pages", "save-selected-pages", "split"])
        #expect(PDFPlugin.tools.filter { $0.menu == .file }.allSatisfy { $0.isEditTool && !$0.showsInToolbar })
    }
}

@Suite struct PDFDroppedFiles {
    @Test func onlyPDFsAndImagesAreTaken() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("peeker-test-\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        let pdf = try TempFile.makePDF(pages: 1), notes = try TempFile.make(Data("x".utf8), name: "notes.txt")
        let photo = try TempFile.make(Data(), name: "photo.jpg")
        pasteboard.clearContents()
        pasteboard.writeObjects([pdf as NSURL, notes as NSURL, photo as NSURL])
        #expect(PeekerPDFView.droppedFiles(on: pasteboard) == [pdf, photo])
    }
}
