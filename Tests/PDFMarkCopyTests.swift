import AppKit
import PDFKit
import PeekerKit
@testable import PeekerPDF
import Testing

private func open(_ file: URL, pasteboard: NSPasteboard) async throws -> PDFPluginDocument {
    let document = try await openDocument(file, with: PDFPlugin.self, as: PDFPluginDocument.self)
    document.undoManager.groupsByEvent = false
    document.pasteboard = pasteboard
    return document
}

/// A pasteboard of the test's own, so a run never touches the user's clipboard.
private func scratchPasteboard() -> NSPasteboard { NSPasteboard(name: NSPasteboard.Name("peeker-test-\(UUID().uuidString)")) }

private func check(at rect: CGRect = CGRect(x: 100, y: 300, width: 22, height: 22)) throws -> PDFMark {
    let made = try #require(
        PDFDrawing.make(
            .check, from: rect.origin, to: CGPoint(x: rect.maxX, y: rect.maxY), points: [],
            color: PDFMarkupStrip.palette[1].color, width: 2))
    return PDFMark(id: PDFEdit.newID(), page: 0, rect: made.rect, kind: .drawing(made.drawing))
}

private func added(_ mark: PDFMark, to document: PDFPluginDocument) throws -> EditController {
    let tools = try #require(document.prepareEditing())
    #expect(document.change(.add(mark)))
    tools.select(mark.id, page: 0)
    return tools
}

@Suite(.serialized) struct PDFMarkCopying {
    @Test func aCopiedStampPastesIntoAnotherPDFBelowAndRightSelected() async throws {
        let pasteboard = scratchPasteboard()
        defer { pasteboard.releaseGlobally() }
        let source = try await open(try TempFile.makePDF(pages: 1), pasteboard: pasteboard)
        let mark = try check()
        _ = try added(mark, to: source)
        #expect(source.copyMark())
        let target = try await open(try TempFile.makePDF(pages: 1), pasteboard: pasteboard)
        #expect(target.canPasteMark)
        #expect(target.pasteMark())
        let pasted = try #require(target.pdfView.document?.page(at: 0)?.annotations.first)
        #expect(PDFMarks.id(of: pasted) != mark.id && PDFMarks.drawing(of: pasted)?.shape == .check)
        #expect(pasted.bounds.origin == CGPoint(x: mark.rect.minX + 12, y: mark.rect.minY - 12))
        #expect(target.editController?.selectedID == PDFMarks.id(of: pasted))
        target.undoManager.undo()
        #expect(target.pdfView.document?.page(at: 0)?.annotations.isEmpty == true, "one undo step")
    }

    @Test func aTextBoxIsCopiedWithItsText() async throws {
        let pasteboard = scratchPasteboard()
        defer { pasteboard.releaseGlobally() }
        let document = try await open(try TempFile.makePDF(pages: 1), pasteboard: pasteboard)
        let box = PDFMark(
            id: PDFEdit.newID(), page: 0, rect: CGRect(x: 100, y: 300, width: 80, height: 20), kind: .textBox(text: "Seen", fontSize: 14))
        _ = try added(box, to: document)
        #expect(document.copyMark() && document.pasteMark())
        let texts = document.pdfView.document?.page(at: 0)?.annotations.map(\.contents)
        #expect(texts == ["Seen", "Seen"])
    }

    @Test func signaturesAndHighlightsAreNotCopied() async throws {
        let pasteboard = scratchPasteboard()
        defer { pasteboard.releaseGlobally() }
        let document = try await open(try TempFile.makePDF(pages: 1), pasteboard: pasteboard)
        let signature = PDFMark(
            id: PDFEdit.newID(), page: 0, rect: CGRect(x: 100, y: 300, width: 180, height: 60),
            kind: .signature(strokes: [[.zero, CGPoint(x: 1, y: 1)]]))
        _ = try added(signature, to: document)
        _ = document.copyMark()
        #expect(!document.canPasteMark, "the signature never reaches the pasteboard")
        let highlight = PDFMark(
            id: PDFEdit.newID(), page: 0, rect: CGRect(x: 100, y: 500, width: 100, height: 14),
            kind: .highlight(RGBA(red: 1, green: 0.8, blue: 0, alpha: 1)))
        _ = try added(highlight, to: document)
        _ = document.copyMark()
        #expect(!document.canPasteMark)
    }

    @Test func withNoMarkSelectedCopyIsLeftToTheText() async throws {
        let pasteboard = scratchPasteboard()
        defer { pasteboard.releaseGlobally() }
        let document = try await open(try TempFile.makePDF(pages: 1), pasteboard: pasteboard)
        _ = document.prepareEditing()
        #expect(!document.copyMark())
    }

    @Test func aPasteNearTheEdgeStaysOnThePage() async throws {
        let pasteboard = scratchPasteboard()
        defer { pasteboard.releaseGlobally() }
        let document = try await open(try TempFile.makePDF(pages: 1), pasteboard: pasteboard)
        let page = try #require(document.pdfView.document?.page(at: 0)).bounds(for: .mediaBox)
        _ = try added(try check(at: CGRect(x: page.maxX - 10, y: 5, width: 22, height: 22)), to: document)
        #expect(document.copyMark() && document.pasteMark())
        let pasted = try #require(document.pdfView.document?.page(at: 0)?.annotations.last)
        #expect(
            pasted.bounds.intersection(page).width >= EditController.minimumSize
                && pasted.bounds.intersection(page).height >= EditController.minimumSize)
    }

    @Test func aSignaturePutOnThePasteboardByAnotherAppIsRefused() async throws {
        let pasteboard = scratchPasteboard()
        defer { pasteboard.releaseGlobally() }
        let document = try await open(try TempFile.makePDF(pages: 1), pasteboard: pasteboard)
        _ = document.prepareEditing()
        let signature = PDFMark(
            id: "peeker-s", page: 0, rect: CGRect(x: 100, y: 300, width: 180, height: 60), kind: .signature(strokes: [[.zero, CGPoint(x: 1, y: 1)]]))
        pasteboard.clearContents()
        pasteboard.setData(try JSONEncoder().encode(signature), forType: PDFPluginDocument.markPasteboardType)
        #expect(!document.pasteMark())
        #expect(document.pdfView.document?.page(at: 0)?.annotations.isEmpty == true)
    }

    @Test func aBadMarkOnThePasteboardIsRefused() async throws {
        let pasteboard = scratchPasteboard()
        defer { pasteboard.releaseGlobally() }
        let document = try await open(try TempFile.makePDF(pages: 1), pasteboard: pasteboard)
        _ = document.prepareEditing()
        var mark = try check()
        if case .drawing(var drawing) = mark.kind {
            drawing.width = 1_000
            mark.kind = .drawing(drawing)
        }
        pasteboard.clearContents()
        pasteboard.setData(try JSONEncoder().encode(mark), forType: PDFPluginDocument.markPasteboardType)
        #expect(!document.pasteMark())
        #expect(document.pdfView.document?.page(at: 0)?.annotations.isEmpty == true)
    }
}
