import AppKit
import PeekerKit
@testable import PeekerPDF
import Testing

@Suite(.serialized) struct PDFZoomControl {
    @Test func aPDFInAnEditorGetsTheZoomControl() async throws {
        let document = await loadedDocument(try TempFile.makePDF(pages: 2), with: PDFPlugin.self)
        defer { document.close() }
        #expect(document.pluginDocument is any Zooming)
        #expect(document.zoomControl != nil)
        #expect(document.zoomControl?.superview != nil)
    }
}

@Suite(.serialized) struct PDFZoomControlInAWindow {
    @Test func aPDFWindowKeepsTheZoomControl() async throws {
        let controller = try await documentWindow(for: PDFPlugin.self, file: try TempFile.makePDF(pages: 2))
        defer { controller.window?.close() }
        try await Task.sleep(for: .milliseconds(300))
        let document = try #require(controller.current)
        #expect(document.zoomControl != nil)
        #expect(document.zoomControl?.window === controller.window)
    }
}

@Test func pdfHasTheZoomTools() {
    #expect(Set(PDFPlugin.tools.map(\.id)).isSuperset(of: ["zoom-in", "zoom-out", "zoom-actual", "zoom-fit"]))
}
