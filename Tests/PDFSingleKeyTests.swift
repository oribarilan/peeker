import AppKit
import PDFKit
import PeekerKit
@testable import PeekerPDF
import Testing

/// The PDF tools' single keys in a real window, as Crop's C is tested for images.
@Suite(.serialized) struct PDFSingleKeys {
    private let h = (character: "h", code: UInt16(4))

    @Test func hHighlightsTheSelection() async throws {
        let controller = try await documentWindow(for: PDFPlugin.self, file: try TempFile.makePDF(pages: 1))
        defer { controller.close() }
        let document = try #require(controller.current?.pluginDocument as? PDFPluginDocument)
        let page = try #require(document.pdfView.document?.page(at: 0))
        document.pdfView.setCurrentSelection(page.selection(for: page.bounds(for: .mediaBox)), animate: false)
        #expect(controller.handleToolKey(key(h.character, code: h.code, in: try #require(controller.window))))
        #expect(document.pendingEdits.count == 1)
    }

    @Test func anHTypedIntoAFieldStaysAnH() async throws {
        let controller = try await documentWindow(for: PDFPlugin.self, file: try TempFile.makePDF(pages: 1))
        defer { controller.close() }
        let window = try #require(controller.window)
        let document = try #require(controller.current?.pluginDocument as? PDFPluginDocument)
        let field = NSTextView(frame: NSRect(x: 0, y: 0, width: 50, height: 20))
        window.contentView?.addSubview(field)
        window.makeFirstResponder(field)
        #expect(!controller.handleToolKey(key(h.character, code: h.code, in: window)))
        #expect(document.pendingEdits.isEmpty)
    }
}
