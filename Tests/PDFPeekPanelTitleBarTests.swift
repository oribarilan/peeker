import AppKit
import PDFKit
import PeekerKit
@testable import PeekerPDF
import Testing

/// The pages start below the title bar, so in the Peek panel they never run under the file name and Open in Peeker.
@Suite(.serialized) struct PDFBelowTheTitleBar {
    @Test func inThePeekPanelThePagesStartBelowTheTitleBar() async throws {
        let (defaults, name) = scratchDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let document = await loadedDocument(try TempFile.makePDF(pages: 2), with: PDFPlugin.self, allowsEditing: false)
        defer { document.close() }
        let panel = PeekPanel(defaults: defaults)
        defer { panel.close() }
        panel.contentViewController = document
        panel.contentView?.layoutSubtreeIfNeeded()
        let pdfView = try #require((document.pluginDocument as? PDFPluginDocument)?.pdfView)
        #expect(pdfView.convert(pdfView.bounds, to: nil).maxY <= panel.contentLayoutRect.maxY, "the pages run under the title bar")
        let button = panel.openButton.convert(NSPoint(x: panel.openButton.bounds.midX, y: panel.openButton.bounds.midY), to: nil)
        let hit = try #require(panel.contentView?.superview?.hitTest(button))
        #expect(hit === panel.openButton || hit.isDescendant(of: panel.openButton), "a click on Open in Peeker reaches \(hit)")
    }
}
