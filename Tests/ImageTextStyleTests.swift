import AppKit
import PeekerKit
@testable import PeekerImage
import Testing

private let size = CGSize(width: 200, height: 100)

private func white() -> CGImage {
    let context = CGContext(
        data: nil, width: 200, height: 100, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(CGRect(origin: .zero, size: size))
    return context.makeImage()!
}

/// Yellow, so the outline is black and shows on white.
private func text(_ style: TextStyle, color: RGBA = RGBA(red: 1, green: 0.84, blue: 0.04, alpha: 1)) -> ImageMark {
    ImageMark(id: ImageMark.newID(), kind: .text(origin: CGPoint(x: 10, y: 10), string: "Hig", style: style), color: color, size: .medium, width: 6)
}

private func pixels(_ image: CGImage) -> Data { image.dataProvider?.data as Data? ?? Data() }

/// The red channel at `x`, `y` from the top left.
private func pixel(_ image: CGImage, _ x: Int, _ y: Int) -> Int {
    let context = CGContext(
        data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.draw(image, in: CGRect(x: -x, y: y - image.height + 1, width: image.width, height: image.height))
    return Int(context.data!.load(as: UInt8.self))
}

@Suite struct ImageTextStyles {
    @Test func everyFontWeightSlantAndEffectDrawsDifferently() throws {
        var styles: [TextStyle] = TextStyle.Font.allCases.map { TextStyle(font: $0, bold: true, italic: false, effect: .plain) }
        styles += [
            TextStyle(font: .system, bold: false, italic: false, effect: .plain), TextStyle(font: .rounded, bold: true, italic: true, effect: .plain),
        ]
        styles += [.outline, .shadow, .label].map { TextStyle(font: .system, bold: true, italic: false, effect: $0) }
        let drawn = try styles.map { pixels(try #require(MarkRenderer.render([text($0)], on: white(), imageSize: size))) }
        let same = drawn.indices.flatMap { a in drawn.indices.filter { $0 > a && drawn[$0] == drawn[a] }.map { "\(styles[a]) = \(styles[$0])" } }
        #expect(same.isEmpty, "each style looks different")
    }

    @Test func aShadowFallsBelowRightAndAPlainTextHasNone() throws {
        let black = RGBA(red: 0, green: 0, blue: 0, alpha: 1)
        let line = { (effect: TextStyle.Effect) in
            ImageMark(
                id: "t",
                kind: .text(origin: CGPoint(x: 10, y: 10), string: "I", style: TextStyle(font: .system, bold: true, italic: false, effect: effect)),
                color: black, size: .medium, width: 6)
        }
        let plain = try #require(MarkRenderer.render([line(.plain)], on: white(), imageSize: size))
        let shadow = try #require(MarkRenderer.render([line(.shadow)], on: white(), imageSize: size))
        // Somewhere right of the I's stem, where only a shadow lands: white with Plain, darker with Shadow.
        let changed = (0..<40).contains { x in
            let a = pixel(plain, 12 + x, 30), b = pixel(shadow, 12 + x, 30)
            return a == 255 && b < 230
        }
        #expect(changed)
    }

    @Test func theStyleRoundTrips() throws {
        let mark = text(TextStyle(font: .serif, bold: false, italic: true, effect: .shadow))
        #expect(try JSONDecoder().decode(ImageMark.self, from: JSONEncoder().encode(mark)) == mark)
    }

    @Test func italicRoundedLeansSinceItHasNoItalic() throws {
        let upright = try #require(
            MarkRenderer.render([text(TextStyle(font: .rounded, bold: false, italic: false, effect: .plain))], on: white(), imageSize: size))
        let italic = try #require(
            MarkRenderer.render([text(TextStyle(font: .rounded, bold: false, italic: true, effect: .plain))], on: white(), imageSize: size))
        #expect(pixels(upright) != pixels(italic))
        #expect(
            abs(MarkRenderer.font(TextStyle(font: .rounded, bold: false, italic: true, effect: .plain), size: 20).pointSize - 20) < 0.5,
            "not enlarged")
    }
}

/// An editable white 400 × 200 image in a window.
@MainActor private func shown(preferences: PluginPreferences? = nil) async throws -> (ImageDocument, NSWindow) {
    let context = CGContext(
        data: nil, width: 400, height: 200, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
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

@Suite(.serialized) struct ImageTextStyleStrip {
    @Test func theStripShowsTextControlsAndRestylesTheSelectedText() async throws {
        let scratch = ScratchDefaults()
        defer { scratch.close() }
        let (document, window) = try await shown(preferences: scratch.preferences("image"))
        defer { window.close() }
        #expect(document.perform("markup-text"))
        #expect(document.strip?.detail == .text)
        let caption = text(.standard)
        document.put(caption)
        document.overlay?.select(caption.id)
        let serif = TextStyle(font: .serif, bold: false, italic: true, effect: .shadow)
        document.setTextStyle(serif)
        #expect(document.marks.first?.kind == .text(origin: CGPoint(x: 10, y: 10), string: "Hig", style: serif))
        let checked = document.strip?.textMenu.itemArray.filter { $0.state == .on }.map(\.title)
        #expect(checked == ["Serif", "Italic", "Shadow"], "the menu checks the selected text's style")
        let (next, other) = try await shown(preferences: scratch.preferences("image"))
        defer { other.close() }
        #expect(next.markupStyle.text == serif, "remembered for the next image")
    }

    /// Found in review: a style picked while text was being typed was undone when typing ended.
    @Test func aStylePickedWhileTypingLandsWithTheText() async throws {
        let (document, window) = try await shown()
        defer { window.close() }
        #expect(document.perform("markup-text"))
        let overlay = try #require(document.overlay)
        let at = overlay.convert(overlay.viewPoint(CGPoint(x: 40, y: 40)), to: nil)
        overlay.mouseDown(
            with: NSEvent.mouseEvent(
                with: .leftMouseDown, location: at, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
                context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!)
        let field = try #require(overlay.subviews.compactMap { $0 as? NSTextField }.first)
        field.stringValue = "Note"
        let menu = try #require(document.strip?.textMenu.menu)
        menu.performActionForItem(at: try #require(menu.items.firstIndex { $0.title == "Serif" }))
        menu.performActionForItem(at: try #require(menu.items.firstIndex { $0.title == "Shadow" }))
        document.setMarkupColor(markupPalette[4].color)
        overlay.endTextEditing()
        let mark = try #require(document.marks.first)
        #expect(
            mark.kind
                == .text(origin: CGPoint(x: 40, y: 40), string: "Note", style: TextStyle(font: .serif, bold: true, italic: false, effect: .shadow)))
        #expect(mark.color == markupPalette[4].color && document.marks.count == 1)
    }

    @Test func aBadRememberedTextStyleIsTheStandardOne() {
        let scratch = ScratchDefaults()
        defer { scratch.close() }
        scratch.preferences("image").set("{\"font\": \"comic\"}", for: "textStyle")
        #expect(ImageDocument.markupStyle(in: scratch.preferences("image")).text == .standard)
    }
}
