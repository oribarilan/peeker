import AppKit
import PDFKit
import PeekerKit
@testable import PeekerPDF
import Testing

/// A one-page PDF laid out in an off-screen window, fitted to it.
private func shown() async throws -> (PDFPluginDocument, NSWindow) {
    let document = try await openDocument(try TempFile.makePDF(pages: 1), with: PDFPlugin.self, as: PDFPluginDocument.self)
    let window = offscreenWindow(holding: document.contentView, width: 600, height: 800)
    window.contentView?.layoutSubtreeIfNeeded()
    return (document, window)
}

@Suite(.serialized) struct PDFZoomContract {
    @Test func actualSizeIs100Percent() async throws {
        let (document, window) = try await shown()
        defer { window.close() }
        #expect(document.perform("zoom-actual"))
        #expect(document.zoomPercent == 100)
        #expect(document.zoomRange.contains(100))
        #expect(!document.pinchesNatively)
    }

    @Test func setZoomScalesThePagesAndSaysSo() async throws {
        let (document, window) = try await shown()
        defer { window.close() }
        var changes = 0
        document.onZoomChange = { changes += 1 }
        document.setZoom(200, around: nil)
        #expect(!document.pdfView.autoScales)
        #expect(abs(document.pdfView.scaleFactor - 2) < 0.001)
        #expect(abs(document.zoomPercent - 200) < 0.1)
        #expect(changes > 0)
    }

    @Test func setZoomStaysInItsRange() async throws {
        let (document, window) = try await shown()
        defer { window.close() }
        document.setZoom(1_000_000, around: nil)
        #expect(abs(document.zoomPercent - document.zoomRange.upperBound) < 0.1)
        document.setZoom(0, around: nil)
        #expect(abs(document.zoomPercent - document.zoomRange.lowerBound) < 0.1)
    }

    @Test(arguments: ["zoom-in", "zoom-out", "zoom-actual", "zoom-fit"])
    func theMenuToolsSaySo(_ tool: String) async throws {
        let (document, window) = try await shown()
        defer { window.close() }
        document.setZoom(150, around: nil)
        var changes = 0
        document.onZoomChange = { changes += 1 }
        #expect(document.perform(tool))
        document.contentView.layoutSubtreeIfNeeded()
        #expect(changes > 0)
    }

    @Test func theSpotUnderThePointerStaysPut() async throws {
        let (document, window) = try await shown()
        defer { window.close() }
        #expect(document.perform("zoom-actual"))
        let pdfView = document.pdfView
        let pointer = NSPoint(x: 200, y: 500)  // in the content view
        let page = try #require(pdfView.page(for: pdfView.convert(pointer, from: document.contentView), nearest: true))
        let onPage = pdfView.convert(pdfView.convert(pointer, from: document.contentView), to: page)
        document.setZoom(250, around: pointer)
        #expect(abs(pdfView.scaleFactor - 2.5) < 0.001)
        let after = document.contentView.convert(pdfView.convert(onPage, from: page), from: pdfView)
        #expect(abs(after.x - pointer.x) < 2 && abs(after.y - pointer.y) < 2, "\(after) should be \(pointer)")
    }
}
