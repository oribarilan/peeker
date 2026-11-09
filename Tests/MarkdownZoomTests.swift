import AppKit
import PeekerKit
@testable import PeekerMarkdown
import Testing

@MainActor private func edit(_ scratch: ScratchDefaults, name: String = "a.md") async throws -> MarkdownEditor {
    try await openDocument(try TempFile.make(Data("# Big\nbody\n".utf8), name: name), with: MarkdownPlugin.self, as: MarkdownEditor.self,
                           preferences: scratch.preferences("markdown"))
}

/// The body text's size, after the heading.
@MainActor private func bodySize(_ editor: MarkdownEditor) -> CGFloat? {
    ((editor.focusView as? NSTextView)?.textStorage?.attribute(.font, at: 7, effectiveRange: nil) as? NSFont)?.pointSize
}

@Suite(.serialized) struct MarkdownZoom {
    @Test func percentIsOneHundredAtTheDefaultSizeAndFollowsZoomIn() async throws {
        let scratch = ScratchDefaults()
        defer { scratch.close() }
        let editor = try await edit(scratch)
        #expect(editor.zoomPercent == 100)
        #expect(editor.perform("zoom-in"))
        #expect(editor.zoomPercent == 15.0 / 14 * 100)
        #expect(editor.zoomRange == (8.0 / 14 * 100)...(48.0 / 14 * 100), "8 to 48 points over the default 14")
    }

    @Test func setZoomScalesTheTextAndIsRememberedForTheNextFile() async throws {
        let scratch = ScratchDefaults()
        defer { scratch.close() }
        let editor = try await edit(scratch)
        let other = try await edit(scratch, name: "other.md")
        editor.setZoom(200, around: nil)
        #expect(bodySize(editor) == 28 && editor.zoomPercent == 200)
        #expect(scratch.preferences("markdown").double("textSize") == 28)
        #expect(bodySize(other) == 14, "a file already open keeps its size")
        #expect(bodySize(try await edit(scratch, name: "next.md")) == 28)
    }

    @Test func setZoomClamps() async throws {
        let scratch = ScratchDefaults()
        defer { scratch.close() }
        let editor = try await edit(scratch)
        editor.setZoom(10_000, around: nil)
        try await waitUntil(seconds: 1) { bodySize(editor) == 48 }
        editor.setZoom(1, around: nil)
        try await waitUntil(seconds: 1) { bodySize(editor) == 8 }
        editor.setZoom(.infinity, around: nil)
        try await waitUntil(seconds: 1) { bodySize(editor) == 8 }
    }

    @Test func onZoomChangeFiresForTheMenuAndSetZoom() async throws {
        let scratch = ScratchDefaults()
        defer { scratch.close() }
        let editor = try await edit(scratch)
        var changes = 0
        editor.onZoomChange = { changes += 1 }
        #expect(editor.perform("zoom-in") && editor.perform("zoom-actual") && editor.perform("zoom-actual"))
        #expect(changes == 2)
        editor.setZoom(150, around: nil)
        #expect(changes == 3)
        #expect(!editor.pinchesNatively)
    }
}

/// The Peek panel's Markdown re-renders the whole file to change size, so a gesture's many steps apply once it stops.
@Suite(.serialized) struct MarkdownPanelZoom {
    @Test func cmdScrollAppliesTheSizeOnceTheGestureStops() async throws {
        let scratch = ScratchDefaults()
        defer { scratch.close() }
        let file = try TempFile.make(Data("# Notes\n\nSome text.\n".utf8), name: "n.md")
        let document = try await openDocument(file, with: MarkdownPlugin.self, as: MarkdownDocument.self, editing: false,
                                              preferences: scratch.preferences("markdown"))
        var changes = 0
        document.onZoomChange = { changes += 1 }
        #expect(document.zoomPercent == 100)
        document.setZoom(150, around: nil)
        document.setZoom(200, around: nil)
        #expect(document.zoomPercent == 200 && changes == 2, "the control would follow at once")
        #expect(document.renderedSize == 14, "not drawn yet")
        try await waitUntil(seconds: 2) { document.renderedSize == 28 }
        #expect(scratch.preferences("markdown").double("textSize") == 28, "remembered like a window's zoom")
        document.setZoom(10_000, around: nil)
        #expect(document.zoomPercent == document.zoomRange.upperBound)
    }
}
