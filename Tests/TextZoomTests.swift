import AppKit
import PeekerKit
@testable import PeekerText
import Testing

@MainActor private func open(_ scratch: ScratchDefaults, name: String = "a.txt") async throws -> TextDocument {
    try await openDocument(
        try TempFile.make(Data("a\n".utf8), name: name), with: TextPlugin.self, as: TextDocument.self,
        preferences: scratch.preferences("text"))
}

@MainActor private func pointSize(_ document: TextDocument) -> CGFloat? { (document.focusView as? NSTextView)?.font?.pointSize }

@Suite(.serialized) struct TextZoom {
    @Test func percentIsOneHundredAtTheDefaultSizeAndFollowsZoomIn() async throws {
        let scratch = ScratchDefaults()
        defer { scratch.close() }
        let document = try await open(scratch)
        #expect(document.zoomPercent == 100)
        #expect(document.perform("zoom-in"))
        #expect(document.zoomPercent == 13.0 / 12 * 100)
        #expect(document.zoomRange == 50...600, "6 to 72 points over the default 12")
    }

    @Test func setZoomScalesTheFontAndIsRememberedForTheNextFile() async throws {
        let scratch = ScratchDefaults()
        defer { scratch.close() }
        let document = try await open(scratch)
        let other = try await open(scratch, name: "other.txt")
        document.setZoom(200, around: nil)
        #expect(pointSize(document) == 24 && document.zoomPercent == 200)
        #expect(scratch.preferences("text").double("fontSize") == 24)
        #expect(pointSize(other) == 12, "a file already open keeps its size")
        #expect(pointSize(try await open(scratch, name: "next.txt")) == 24)
    }

    @Test func setZoomTakesFractionalSizesAndClamps() async throws {
        let scratch = ScratchDefaults()
        defer { scratch.close() }
        let document = try await open(scratch)
        document.setZoom(110, around: NSPoint(x: 5, y: 5))
        try await waitUntil(seconds: 1) { pointSize(document) == 13.2 }
        document.setZoom(10_000, around: nil)
        try await waitUntil(seconds: 1) { pointSize(document) == 72 && document.zoomPercent == 600 }
        document.setZoom(1, around: nil)
        try await waitUntil(seconds: 1) { pointSize(document) == 6 && document.zoomPercent == 50 }
        document.setZoom(.nan, around: nil)
        try await waitUntil(seconds: 1) { pointSize(document) == 6 }
    }

    @Test func onZoomChangeFiresForTheMenuAndSetZoom() async throws {
        let scratch = ScratchDefaults()
        defer { scratch.close() }
        let document = try await open(scratch)
        var changes = 0
        document.onZoomChange = { changes += 1 }
        #expect(document.perform("zoom-in") && document.perform("zoom-out") && document.perform("zoom-actual"))
        #expect(changes == 2, "Actual Size at the default size changes nothing")
        document.setZoom(150, around: nil)
        #expect(changes == 3)
        document.setZoom(150, around: nil)
        #expect(changes == 3, "the same zoom again is no change")
        #expect(!document.pinchesNatively)
    }
}
