import AppKit
import PeekerKit
@testable import PeekerImage
import Testing

/// An editable white 400 × 200 image in a window.
@MainActor private func shown(preferences: PluginPreferences? = nil) async throws -> (ImageDocument, NSWindow) {
    let context = CGContext(data: nil, width: 400, height: 200, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 400, height: 200))
    let url = try imageFile(context.makeImage()!, type: .png)
    let document = try await openDocument(url, with: ImagePlugin.self, as: ImageDocument.self, maxPixels: 4096, preferences: preferences)
    document.undoManager.groupsByEvent = false
    let window = offscreenWindow(holding: document.contentView, width: 400, height: 260)
    document.contentView.layoutSubtreeIfNeeded()
    return (document, window)
}

private func white(width: Int = 200, height: Int = 100) -> CGImage {
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()!
}

/// The red channel at `x`, `y` from the top left.
private func red(_ image: CGImage, _ x: Int, _ y: Int) -> Int {
    let context = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.draw(image, in: CGRect(x: -x, y: y - image.height + 1, width: image.width, height: image.height))
    return Int(context.data!.load(as: UInt8.self))
}

private func mark(_ kind: ImageMark.Kind) -> ImageMark {
    ImageMark(id: ImageMark.newID(), kind: kind, color: RGBA(red: 0, green: 0, blue: 1, alpha: 1), size: .medium, width: 4)
}

/// Found when the maintainer tried markup: blurry marks, keys not shown, one pixelate strength, square spotlights.
@Suite(.serialized) struct ImageMarkupPolish {
    @Test func marksDrawOverTheImageAndOnlyPixelateIsInItsPixels() async throws {
        let (document, window) = try await shown()
        defer { window.close() }
        let arrow = mark(.arrow(from: CGPoint(x: 20, y: 100), to: CGPoint(x: 380, y: 100)))
        let blocks = mark(.pixelate(CGRect(x: 0, y: 0, width: 100, height: 50), strength: 0.5))
        document.put(arrow)
        document.put(blocks)
        #expect(document.marksView.shownMarks.map(\.id) == [arrow.id], "the arrow is drawn over the image")
        #expect(red(document.canvas.image, 200, 100) == 255, "and isn't painted into the shown image")
        let saved = try #require(MarkRenderer.render(document.marks, on: white(width: 400, height: 200), imageSize: CGSize(width: 400, height: 200)))
        #expect(red(saved, 200, 100) < 60, "saving paints it")
    }

    @Test func strengthSetsTheBlockSize() {
        let size = CGSize(width: 6000, height: 3000)
        #expect(MarkStyle.block(strength: 0, imageSize: size) < MarkStyle.block(strength: MarkStyle.defaultStrength, imageSize: size))
        #expect(MarkStyle.block(strength: MarkStyle.defaultStrength, imageSize: size) < MarkStyle.block(strength: 1, imageSize: size))
        #expect(abs(MarkStyle.block(strength: MarkStyle.defaultStrength, imageSize: size) - 3000.0 / 60) < 0.5, "the default is 1/60")
        #expect(MarkStyle.block(strength: 0, imageSize: CGSize(width: 300, height: 200)) == 6, "never under 6 pixels")
    }

    @Test func anOvalSpotlightDimsItsCorners() throws {
        let image = try #require(MarkRenderer.render([mark(.spotlight(CGRect(x: 40, y: 20, width: 120, height: 60), ellipse: true))], on: white(),
                                                     imageSize: CGSize(width: 200, height: 100)))
        #expect(red(image, 100, 50) == 255, "the middle is lit")
        #expect(red(image, 42, 22) < 140, "a corner of its box is dimmed")
    }

    @Test func strengthAndShapeAreRememberedAndChangeTheSelectedMark() async throws {
        let scratch = ScratchDefaults()
        defer { scratch.close() }
        let (document, window) = try await shown(preferences: scratch.preferences("image"))
        defer { window.close() }
        #expect(document.perform("markup-pixelate"))
        #expect(document.strip?.detail == .strength, "Strength takes the size's place")
        let blocks = mark(.pixelate(CGRect(x: 0, y: 0, width: 100, height: 50), strength: 0.2))
        document.put(blocks)
        document.overlay?.select(blocks.id)
        document.setMarkupStrength(0.9)
        #expect(document.marks.first?.kind == .pixelate(CGRect(x: 0, y: 0, width: 100, height: 50), strength: 0.9))
        #expect(document.perform("markup-spotlight"))
        document.overlay?.select(nil)
        #expect(document.strip?.detail == .shape)
        document.setSpotlightOval(true)
        #expect(document.perform("markup-arrow"))
        #expect(document.strip?.detail == .size)
        let (next, other) = try await shown(preferences: scratch.preferences("image"))
        defer { other.close() }
        #expect(next.markupStyle.strength == 0.9 && next.markupStyle.ovalSpotlight)
    }

    @Test func theStripShowsEachToolsKey() {
        let strip = MarkupStrip()
        #expect((0..<MarkupTool.allCases.count).map { strip.tools.label(forSegment: $0) } == ["A", "B", "T", "X", "N", "P", "K", "S"])
    }

    /// A new window is 960 points wide; the info sidebar takes about 200 of them.
    @Test func theStripFitsBesideTheSidebar() {
        let strip = MarkupStrip()
        for detail in [MarkupStrip.Detail.size, .strength, .shape] {
            strip.show(tool: nil, style: MarkStyle(color: markupPalette[0].color, size: .medium, strength: 0.4, ovalSpotlight: false), detail: detail)
            #expect(strip.fittingSize.width <= 760, "\(detail): \(strip.fittingSize.width) points")
        }
    }

    /// Found in review: zooming kept the marks' old drawing, stretched; Print dropped them; the marker didn't multiply.
    @Test func zoomingDrawsTheMarksAgain() async throws {
        let (document, window) = try await shown()
        defer { window.close() }
        document.put(mark(.arrow(from: CGPoint(x: 20, y: 100), to: CGPoint(x: 380, y: 100))))
        window.displayIfNeeded()
        #expect(!document.marksView.needsDisplay)
        #expect(document.perform("zoom-in"))
        #expect(document.marksView.needsDisplay)
    }

    @Test func printingIncludesTheMarks() async throws {
        let (document, window) = try await shown()
        defer { window.close() }
        document.put(mark(.arrow(from: CGPoint(x: 20, y: 100), to: CGPoint(x: 380, y: 100))))
        let operation = try #require(document.printJob?(NSPrintInfo()))
        let view = try #require(operation.view as? NSImageView)
        let image = try #require(view.image?.cgImage(forProposedRect: nil, context: nil, hints: nil))
        #expect(red(image, image.width / 2, image.height / 2) < 60, "the blue arrow is on the page")
    }

    @Test func aMarkerOnScreenMultipliesWithTheImage() async throws {
        let (document, window) = try await shown()
        defer { window.close() }
        // On a black image the saved file keeps the marker's stroke black; on screen it must look the same.
        let context = CGContext(data: nil, width: 400, height: 200, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 400, height: 200))
        document.canvas.image = context.makeImage()!
        let yellow = RGBA(red: 1, green: 0.84, blue: 0.04, alpha: 1)
        let marker = ImageMark(id: "m", kind: .marker([CGPoint(x: 50, y: 100), CGPoint(x: 350, y: 100)]), color: yellow, size: .medium, width: 4)
        let view = document.marksView
        view.show([marker], numbering: [marker], imageSize: CGSize(width: 400, height: 200))
        let rep = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: rep)
        let middle = view.convert(document.canvas.imageRect, from: document.canvas)
        let x = Int(CGFloat(rep.pixelsWide) * middle.midX / view.bounds.width), y = Int(CGFloat(rep.pixelsHigh) * (1 - middle.midY / view.bounds.height))
        let color = try #require(rep.colorAt(x: x, y: y))
        #expect(color.redComponent < 0.15 && color.alphaComponent > 0.9, "multiplied with black, not a pale yellow")
    }

    @Test func aBadStrengthIsRefused() {
        #expect(!mark(.pixelate(CGRect(x: 0, y: 0, width: 9, height: 9), strength: .nan)).isValid)
        #expect(!mark(.pixelate(CGRect(x: 0, y: 0, width: 9, height: 9), strength: 2)).isValid)
    }
}
