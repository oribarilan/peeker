import AppKit
import ImageIO
import PeekerKit
@testable import PeekerMarkdown
import Testing
import UniformTypeIdentifiers

@Suite struct MarkdownImageSources {
    private let folder = URL(filePath: "/notes/plan/", directoryHint: .isDirectory)

    private func resolved(_ source: String) -> String? {
        MarkdownImages.resolve(source, in: folder)?.path(percentEncoded: false)
    }

    @Test func pathsResolveAgainstTheMarkdownFilesFolder() {
        #expect(resolved("chart.png") == "/notes/plan/chart.png")
        #expect(resolved("img/chart.png") == "/notes/plan/img/chart.png")
        #expect(resolved("./img/chart.png") == "/notes/plan/img/chart.png")
        #expect(resolved("../assets/logo.png") == "/notes/assets/logo.png")
    }

    @Test func percentEncodingAndSpacesNameTheFileTheyMean() {
        #expect(resolved("my%20chart.png") == "/notes/plan/my chart.png")
        #expect(resolved("my chart.png") == "/notes/plan/my chart.png")  // a <…> destination, as swift-markdown hands it over
    }

    @Test func absolutePathsAndFileURLs() {
        #expect(resolved("/Shared/logo.png") == "/Shared/logo.png")
        #expect(resolved("file:///Shared/my%20logo.png") == "/Shared/my logo.png")
        #expect(resolved("file://localhost/Shared/logo.png") == "/Shared/logo.png")
        #expect(resolved("FILE:///Shared/logo.png") == "/Shared/logo.png")
    }

    @Test func aFileURLOnAnotherHostIsNotLocal() {
        #expect(resolved("file://server/Shared/logo.png") == nil)
        #expect(resolved("//server/Shared/logo.png") == nil)
    }

    @Test func aQueryOrFragmentIsIgnored() {
        #expect(resolved("chart.png?raw=true") == "/notes/plan/chart.png")
        #expect(resolved("chart.png#gh-dark-mode-only") == "/notes/plan/chart.png")
    }

    @Test func aTildeIsNotTheHomeFolder() {
        #expect(resolved("~/chart.png") == "/notes/plan/~/chart.png")
    }

    @Test func webDataAndOtherSchemesResolveToNothing() {
        for source in ["http://example.com/a.png", "https://example.com/badge.svg", "HTTPS://EXAMPLE.COM/A.PNG",
                       "data:image/png;base64,iVBORw0KGgo=", "x-custom:chart.png", "ftp://example.com/a.png", ""] {
            #expect(resolved(source) == nil, "\(source)")
        }
    }
}

/// A BMP header claiming `width`×`height` pixels, with almost no pixel data behind it.
func bmpHeader(width: Int, height: Int) throws -> URL {
    func le(_ value: Int, _ bytes: Int) -> [UInt8] { (0..<bytes).map { UInt8((value >> (8 * $0)) & 0xFF) } }
    var bytes: [UInt8] = [0x42, 0x4D] + le(64, 4) + le(0, 4) + le(54, 4)
    bytes += le(40, 4) + le(width, 4) + le(height, 4) + le(1, 2) + le(24, 2) + le(0, 4) + le(0, 4) + le(2835, 4) + le(2835, 4) + le(0, 4) + le(0, 4)
    return try TempFile.make(Data(bytes + [UInt8](repeating: 0, count: 10)), name: "huge.bmp")
}

@Suite struct MarkdownImageCheck {
    @Test func aPNGGivesItsPixelSize() throws {
        let file = try imageFile(try cornerImage(width: 40, height: 20), type: .png)
        let image = try #require(MarkdownImages.check(file))
        #expect(image.url == file)
        #expect(image.pixelSize == CGSize(width: 40, height: 20))
        #expect(image.modified != nil)
    }

    @Test func aTurnedJPEGGivesItsTurnedSize() throws {
        let file = try imageFile(try cornerImage(width: 40, height: 20), type: .jpeg, properties: [kCGImagePropertyOrientation: 6])
        #expect(MarkdownImages.check(file)?.pixelSize == CGSize(width: 20, height: 40))
    }

    @Test func aSymlinkIsFollowed() throws {
        let file = try imageFile(try cornerImage(), type: .png)
        let link = file.deletingLastPathComponent().appending(path: "link.png")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        #expect(MarkdownImages.check(link)?.pixelSize == CGSize(width: 40, height: 20))
    }

    @Test func filesThatArentPicturesGiveNothing() throws {
        let text = try TempFile.make(Data("not a picture".utf8), name: "f.png")
        #expect(MarkdownImages.check(text) == nil)
        #expect(MarkdownImages.check(text.deletingLastPathComponent().appending(path: "missing.png")) == nil)
        #expect(MarkdownImages.check(text.deletingLastPathComponent()) == nil)
    }

    @Test func aFileOver20MBGivesNothing() throws {
        let file = try imageFile(try cornerImage(), type: .png)
        let handle = try FileHandle(forWritingTo: file)
        try handle.truncate(atOffset: 21 * 1_048_576)  // sparse: takes no disk space
        try handle.close()
        #expect(MarkdownImages.check(file) == nil)
    }

    @Test func aHeaderClaimingOver50MegapixelsGivesNothing() throws {
        #expect(MarkdownImages.check(try bmpHeader(width: 10_000, height: 10_000)) == nil)
        #expect(MarkdownImages.check(try bmpHeader(width: 100, height: 100))?.pixelSize == CGSize(width: 100, height: 100))
    }
}

/// A folder holding `markdown` as notes.md and a solid red PNG of `size` pixels for each name in `pictures`.
func markdownFolder(_ markdown: String, pictures: [String] = [], size: CGSize = CGSize(width: 40, height: 20)) throws -> URL {
    let file = try TempFile.make(Data(markdown.utf8), name: "notes.md")
    let context = try #require(CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
                                         space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
    context.fill(CGRect(origin: .zero, size: size))
    let png = try Data(contentsOf: try imageFile(try #require(context.makeImage()), type: .png))
    for name in pictures {
        let url = file.deletingLastPathComponent().appending(path: name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try png.write(to: url)
    }
    return file
}

@Suite struct MarkdownImageFinding {
    private let folder = URL(filePath: "/notes/", directoryHint: .isDirectory)

    /// The images found in `markdown`, with every local source usable, and the files checked.
    private func find(_ markdown: String) -> (images: [String: LocalImage], checked: [String]) {
        var checked: [String] = []
        let images = MarkdownImages.find(in: MarkdownTree.blocks(from: markdown), folder: folder) { url in
            checked.append(url.lastPathComponent)
            return LocalImage(url: url, pixelSize: CGSize(width: 10, height: 10), modified: nil)
        }
        return (images, checked)
    }

    @Test func parseKeysEachUsableImageByItsSourceAsWritten() async throws {
        let file = try markdownFolder("![a](a.png) and ![again](./a.png)\n\n- ![sub](img/b.png)\n\n> ![gone](missing.png) ![web](https://example.com/c.png)\n",
                                      pictures: ["a.png", "img/b.png"])
        let images = try await MarkdownPlugin.parse(file).images
        #expect(Set(images.keys) == ["a.png", "./a.png", "img/b.png"])
        #expect(images["img/b.png"]?.pixelSize == CGSize(width: 40, height: 20))
        #expect(images["img/b.png"]?.url.lastPathComponent == "b.png")
    }

    @Test func imagesAreNumberedInDocumentOrder() {
        let images = find("# ![h](h.png)\n\n![p](p.png)\n\n- item\n  > ![q](q.png)\n").images
        #expect(images["h.png"]?.order == 0)
        #expect(images["p.png"]?.order == 1)
        #expect(images["q.png"]?.order == 2)
    }

    @Test func aRepeatedSourceIsCheckedOnce() {
        let found = find("![a](a.png)\n\n![a again](a.png)\n")
        #expect(found.checked == ["a.png"])
        #expect(found.images.count == 1)
    }

    @Test func imagesInTableCellsAreSkipped() {
        let found = find("| pic |\n| --- |\n| ![t](t.png) |\n")
        #expect(found.checked.isEmpty)
        #expect(found.images.isEmpty)
    }

    @Test func lookingStopsAfter50UsableImages() {
        let found = find((1...60).map { "![p\($0)](p\($0).png)" }.joined(separator: "\n\n"))
        #expect(found.images.count == 50)
        #expect(found.checked.count == 50)
        #expect(found.images["p50.png"] != nil && found.images["p51.png"] == nil)
    }

    @Test func aFileWithoutImagesChecksNothing() {
        let found = find("# Title\n\nText with a [link](a.png) and `![code](c.png)`.\n\n```\n![fenced](f.png)\n```\n")
        #expect(found.checked.isEmpty)
        #expect(found.images.isEmpty)
    }
}


/// The alpha of the middle pixel when `image` is drawn into a clear bitmap of its size.
@MainActor func middleAlpha(_ image: NSImage) throws -> CGFloat {
    let width = Int(image.size.width), height = Int(image.size.height)
    let rep = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
                                            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
    NSGraphicsContext.restoreGraphicsState()
    return try #require(rep.colorAt(x: width / 2, y: height / 2)).alphaComponent
}

@Suite struct MarkdownPictureRendering {
    private let logo = LocalImage(url: URL(filePath: "/notes/logo.png"), pixelSize: CGSize(width: 120, height: 40), modified: nil)

    private func render(_ markdown: String) -> (text: NSAttributedString, anchors: [Int: Int]) {
        MarkdownRenderer.render(MarkdownTree.blocks(from: markdown), theme: .system, images: ["logo.png": logo])
    }

    @Test func aKnownImageIsOneAttachmentHoldingATransparentImageOfItsSize() throws {
        let text = render("Before ![the logo](logo.png) after").text
        #expect(text.string == "Before \u{FFFC} after")
        let attachment = try #require(text.attribute(.attachment, at: 7, effectiveRange: nil) as? MarkdownImageAttachment)
        let image = try #require(attachment.image)
        #expect(image.size == CGSize(width: 120, height: 40))
        #expect(image.accessibilityDescription == "the logo")
        #expect(try middleAlpha(image) == 0)
        #expect(attachment.local == logo)
    }

    @Test func aPictureKeepsTheLinkItsAltTextHad() {
        let text = render("![the logo](logo.png)").text
        #expect(text.attribute(.link, at: 0, effectiveRange: nil) as? URL == URL(string: "logo.png"))
    }

    @Test func anUnknownImageStillShowsItsAltTextInTheMarkerColor() throws {
        let text = render("See ![other](other.png).").text
        #expect(text.string == "See [other].")
        #expect(text.attribute(.attachment, at: 4, effectiveRange: nil) == nil)
        #expect(text.attribute(.foregroundColor, at: 4, effectiveRange: nil) as? NSColor == TextTheme.system.marker)
    }

    @Test func anImageInATableCellShowsItsAltText() {
        let text = render("| pic |\n| --- |\n| ![the logo](logo.png) |\n").text
        #expect(text.string.contains("[the logo]"))
        #expect(!text.string.contains("\u{FFFC}"))
    }

    @Test func outlineAnchorsAfterAPictureFindTheirHeadings() throws {
        let rendered = render("![the logo](logo.png)\n\n# First\n\n![the logo](logo.png) ![the logo](logo.png)\n\n## Second\n")
        let string = rendered.text.string as NSString
        for (line, title) in [(3, "First"), (7, "Second")] {
            let location = try #require(rendered.anchors[line])
            #expect(string.substring(from: location).hasPrefix(title))
        }
    }
}

/// How large a picture is laid out in a text view whose lines are `width` points wide.
@Suite struct MarkdownPictureSizing {
    private func laidOutSize(_ pixels: CGSize, lineWidth width: CGFloat, indent: CGFloat = 0, textKit2: Bool) throws -> CGSize {
        let local = LocalImage(url: URL(filePath: "/notes/p.png"), pixelSize: pixels, modified: nil)
        let view = NSTextView(usingTextLayoutManager: textKit2)
        let container = try #require(view.textContainer)
        view.textContainerInset = .zero
        view.frame = NSRect(x: 0, y: 0, width: width + 2 * container.lineFragmentPadding, height: 100)
        let style = NSMutableParagraphStyle()
        style.headIndent = indent
        style.firstLineHeadIndent = indent
        view.textStorage?.setAttributedString(NSAttributedString(string: "Text \u{FFFC} text",
                                                                 attributes: [.attachment: MarkdownImageAttachment(local, alt: "p"), .paragraphStyle: style]))
        if textKit2 {
            let layout = try #require(view.textLayoutManager)
            let content = try #require(layout.textContentManager)
            layout.ensureLayout(for: layout.documentRange)
            let location = try #require(content.location(layout.documentRange.location, offsetBy: 5))
            let fragment = try #require(layout.textLayoutFragment(for: location))
            return fragment.frameForTextAttachment(at: location).size
        }
        let layout = try #require(view.layoutManager)
        layout.ensureLayout(for: container)
        return layout.attachmentSize(forGlyphAt: layout.glyphIndexForCharacter(at: 5))
    }

    @Test(arguments: [true, false]) func aWidePictureFitsTheLineAndGrowsWithIt(textKit2: Bool) throws {
        let wide = CGSize(width: 3000, height: 1500)
        #expect(try laidOutSize(wide, lineWidth: 600, textKit2: textKit2) == CGSize(width: 600, height: 300))
        #expect(try laidOutSize(wide, lineWidth: 1200, textKit2: textKit2) == CGSize(width: 1200, height: 600))
        #expect(try laidOutSize(wide, lineWidth: 5000, textKit2: textKit2) == wide)
    }

    @Test(arguments: [true, false]) func aPictureInAListFitsWhatTheIndentLeaves(textKit2: Bool) throws {
        #expect(try laidOutSize(CGSize(width: 3000, height: 1500), lineWidth: 600, indent: 40, textKit2: textKit2) == CGSize(width: 560, height: 280))
    }

    @Test(arguments: [true, false]) func aSmallPictureKeepsItsPixelSize(textKit2: Bool) throws {
        for width: CGFloat in [200, 600, 2000] {
            #expect(try laidOutSize(CGSize(width: 120, height: 40), lineWidth: width, textKit2: textKit2) == CGSize(width: 120, height: 40))
        }
    }
}
