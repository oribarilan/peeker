import AppKit
import PeekerKit
@testable import PeekerMarkdown
import Testing

/// The Peek panel's Markdown view with local pictures: text first, pictures decoded in the background.
@Suite struct MarkdownPictureDecoding {
    /// A view-only document on `file`, made without a suspension point so a test can act before decoding starts.
    private func document(_ file: URL, width: CGFloat = 700) async throws -> (MarkdownDocument, NSWindow) {
        let parsed = try await MarkdownPlugin.parse(file)
        let document = MarkdownDocument(url: file, parsed: parsed)
        return (document, offscreenWindow(holding: document.contentView, width: width))
    }

    private func textView(_ document: MarkdownDocument) throws -> NSTextView {
        try #require(document.focusView as? NSTextView)
    }

    private func attachments(_ document: MarkdownDocument) throws -> [MarkdownImageAttachment] {
        let text = try textView(document).attributedString()
        var found: [MarkdownImageAttachment] = []
        text.enumerateAttribute(.attachment, in: NSRange(location: 0, length: text.length)) { value, _, _ in
            if let attachment = value as? MarkdownImageAttachment { found.append(attachment) }
        }
        return found
    }

    /// The decoded picture's width in pixels, or nil while the attachment holds its transparent stand-in.
    private func pixelWidth(_ attachment: MarkdownImageAttachment) -> Int? {
        attachment.isDecoded ? attachment.image?.cgImage(forProposedRect: nil, context: nil, hints: nil)?.width : nil
    }

    private func height(of view: NSTextView) throws -> CGFloat {
        let layout = try #require(view.textLayoutManager)
        layout.ensureLayout(for: layout.documentRange)
        return layout.usageBoundsForTextContainer.height
    }

    @Test func theTextShowsAtOnceWithSpaceForThePictureAndThePictureArrivesLater() async throws {
        let file = try markdownFolder("# Plan\n\n![chart](img/chart.png)\n\nAfter the chart.\n", pictures: ["img/chart.png"],
                                      size: CGSize(width: 3000, height: 1500))
        let (document, window) = try await document(file)
        defer { window.close() }
        let view = try textView(document)
        #expect(!document.renderedText.contains("[chart]"))
        let attachment = try #require(try attachments(document).first)
        #expect(pixelWidth(attachment) == nil)
        let text = document.renderedText, height = try height(of: view)
        #expect(height > 300)  // the picture's space is laid out before it decodes
        try await waitUntil(seconds: 5) { document.pictures.decodes == 1 }
        let scale = window.backingScaleFactor
        let lineWidth = try #require(view.textContainer).size.width
        let decoded = try #require(pixelWidth(attachment))
        #expect(decoded <= Int((min(3000, lineWidth) * scale).rounded(.up)))
        #expect(decoded < 3000)
        #expect(document.renderedText == text)
        #expect(try self.height(of: view) == height)
    }

    @Test func theDecodedPictureDrawsWhereThePictureIs() async throws {
        let file = try markdownFolder("![red](red.png)\n", pictures: ["red.png"], size: CGSize(width: 200, height: 100))
        let (document, window) = try await document(file)
        defer { window.close() }
        try await waitUntil(seconds: 5) { document.pictures.decodes == 1 }
        let view = try textView(document)
        let rep = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: rep)
        let scale = CGFloat(rep.pixelsWide) / view.bounds.width
        let origin = view.textContainerOrigin  // the picture starts at the first line, after the padding
        let color = try #require(rep.colorAt(x: Int((origin.x + 5 + 100) * scale), y: Int((origin.y + 50) * scale))?.usingColorSpace(.sRGB))
        #expect(color.redComponent > 0.8 && color.greenComponent < 0.3 && color.blueComponent < 0.3, "\(color)")
    }

    @Test func aThemeChangeRefillsPicturesWithoutDecodingAgain() async throws {
        let file = try markdownFolder("![a](a.png) ![b](b.png)\n", pictures: ["a.png", "b.png"])
        let (document, window) = try await document(file)
        defer { window.close() }
        try await waitUntil(seconds: 5) { document.pictures.decodes == 2 }
        let before = try attachments(document)
        NotificationCenter.default.post(name: TextTheme.didChange, object: nil)
        let after = try attachments(document)
        #expect(after.count == 2 && after.allSatisfy { a in !before.contains { $0 === a } })
        #expect(after.allSatisfy { pixelWidth($0) == 40 })
        try await Task.sleep(for: .milliseconds(100))
        #expect(document.pictures.decodes == 2)
    }

    @Test func aReloadKeepsDecodedPicturesAndDecodesOnlyNewOnes() async throws {
        let file = try markdownFolder("![a](a.png)\n", pictures: ["a.png", "b.png"])
        let (document, window) = try await document(file)
        defer { window.close() }
        try await waitUntil(seconds: 5) { document.pictures.decodes == 1 }
        try Data("![a](a.png)\n\n![b](b.png)\n".utf8).write(to: file)
        #expect(try await document.reload())
        let shown = try attachments(document)
        #expect(shown.count == 2 && pixelWidth(shown[0]) == 40)
        try await waitUntil(seconds: 5) { document.pictures.decodes == 2 }
        try await Task.sleep(for: .milliseconds(100))
        #expect(document.pictures.decodes == 2)
    }

    @Test func closingCancelsDecodingBeforeLaterPicturesDecode() async throws {
        let names = (1...5).map { "p\($0).png" }
        let file = try markdownFolder(names.map { "![\($0)](\($0))" }.joined(separator: "\n\n"), pictures: names)
        let parsed = try await MarkdownPlugin.parse(file)
        weak var released: MarkdownDocument?
        let pictures = autoreleasepool {
            let document = MarkdownDocument(url: file, parsed: parsed)
            released = document
            return document.pictures
        }
        #expect(released == nil)
        let task = try #require(pictures.task)
        #expect(task.isCancelled)
        await task.value
        #expect(pictures.decodes == 0)
    }

    @Test func aPictureThatFailsToDecodeFallsBackToItsAltText() async throws {
        let file = try markdownFolder("![broken](a.png)\n\n# After\n\nText.\n\n## Later\n", pictures: ["a.png"])
        let parsed = try await MarkdownPlugin.parse(file)
        // Passed the check, then changed before it could decode.
        try Data("not a picture any more".utf8).write(to: file.deletingLastPathComponent().appending(path: "a.png"))
        let document = MarkdownDocument(url: file, parsed: parsed)
        try await waitUntil(seconds: 5) { document.renderedText.contains("[broken]") }
        #expect(try attachments(document).isEmpty)
        let text = document.renderedText as NSString
        for (line, title) in [(3, "After"), (7, "Later")] {
            #expect(text.substring(from: try #require(document.anchors[line])).hasPrefix(title))
        }
    }

    @Test func decodingStaysWithinTheDrawnSizeAnd4096Pixels() {
        let wide = LocalImage(url: URL(filePath: "/p.png"), pixelSize: CGSize(width: 8000, height: 2000), modified: nil)
        #expect(MarkdownImages.decodePixels(for: wide, width: 600, scale: 2) == 1200)
        #expect(MarkdownImages.decodePixels(for: wide, width: 3000, scale: 2) == 4096)
        let tall = LocalImage(url: URL(filePath: "/p.png"), pixelSize: CGSize(width: 1000, height: 3000), modified: nil)
        #expect(MarkdownImages.decodePixels(for: tall, width: 500, scale: 2) == 3000)  // 500×1500 points at 2x, the image's own size
        #expect(MarkdownImages.decodePixels(for: tall, width: 200, scale: 1) == 600)
    }
}
