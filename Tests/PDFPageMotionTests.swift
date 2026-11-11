import AppKit
import PDFKit
import PeekerKit
@testable import PeekerPDF
import Testing

/// A PDF in the Editor, in a window, as the host shows it.
@MainActor private func shown(pages: Int) async throws -> (PDFPluginDocument, NSWindow) {
    let document = try await openDocument(try TempFile.makePDF(pages: pages), with: PDFPlugin.self, as: PDFPluginDocument.self)
    document.undoManager.groupsByEvent = false
    let window = offscreenWindow(holding: document.contentView)
    window.contentView?.layoutSubtreeIfNeeded()
    document.pdfView.layoutDocumentView()
    return (document, window)
}

@MainActor private func motion(in document: PDFPluginDocument) -> NSView? {
    document.pdfView.subviews.first { $0.identifier == PageMotion.identifier }
}

@Suite(.serialized) @MainActor struct PDFPageMotion {
    init() { PageMotion.reducesMotion = { false } }

    @Test func aRotatedPageTurnsIntoPlaceWhileTheEditIsAlreadyApplied() async throws {
        let (document, window) = try await shown(pages: 2)
        defer { window.close() }
        #expect(document.perform("rotate-right"))
        #expect(document.pdfView.document?.page(at: 0)?.rotation == 90, "the edit doesn't wait for the animation")
        let overlay = try #require(motion(in: document))
        #expect(overlay.layer?.sublayers?.isEmpty == false)
        try await waitUntil(seconds: 2) { motion(in: document) == nil }
    }

    @Test func aDeletedPageShrinksAway() async throws {
        let (document, window) = try await shown(pages: 3)
        defer { window.close() }
        #expect(document.perform("delete-page"))
        #expect(document.pdfView.document?.pageCount == 2)
        #expect(motion(in: document) != nil)
        try await waitUntil(seconds: 2) { motion(in: document) == nil }
    }

    @Test func undoingADeleteBringsThePageBackWithMotion() async throws {
        let (document, window) = try await shown(pages: 3)
        defer { window.close() }
        #expect(document.perform("delete-page"))
        try await waitUntil(seconds: 2) { motion(in: document) == nil }
        document.undoManager.undo()
        #expect(document.pdfView.document?.pageCount == 3)
        #expect(motion(in: document) != nil)
    }

    @Test func undoingADeleteShowsThePageWhenItWasOutOfView() async throws {
        let (document, window) = try await shown(pages: 3)
        defer { window.close() }
        let first = try #require(document.pdfView.document?.page(at: 0))
        #expect(document.perform("delete-page"))
        try await waitUntil(seconds: 2) { motion(in: document) == nil }
        document.pdfView.go(to: try #require(document.pdfView.document?.page(at: 1)))
        #expect(PageMotion.frame(of: first, in: document.pdfView) == nil)
        document.undoManager.undo()
        #expect(PageMotion.frame(of: first, in: document.pdfView) != nil)
        #expect(motion(in: document) != nil)
    }

    @Test func reduceMotionAppliesTheEditWithoutAnimating() async throws {
        PageMotion.reducesMotion = { true }
        defer { PageMotion.reducesMotion = { false } }
        let (document, window) = try await shown(pages: 2)
        defer { window.close() }
        #expect(document.perform("rotate-left"))
        #expect(document.perform("delete-page"))
        #expect(motion(in: document) == nil)
    }

    /// Recovered edits are applied while the document opens, before it's in a window: nothing to animate.
    @Test func editsOutsideAWindowDontAnimate() async throws {
        let document = try await openDocument(try TempFile.makePDF(pages: 2), with: PDFPlugin.self, as: PDFPluginDocument.self)
        #expect(document.change(.rotatePages(pages: [0], by: 90)))
        #expect(motion(in: document) == nil)
    }

    /// Only pages on screen get an image; one scrolled out of view changes without one.
    @Test func onlyVisiblePagesAnimate() async throws {
        let (document, window) = try await shown(pages: 6)
        defer { window.close() }
        #expect(document.change(.rotatePages(pages: [5], by: 90)))
        #expect(motion(in: document) == nil)
    }
}
