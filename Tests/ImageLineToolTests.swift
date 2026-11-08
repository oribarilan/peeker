import AppKit
import PeekerKit
@testable import PeekerImage
import Testing

private func white() -> CGImage {
    let context = CGContext(data: nil, width: 200, height: 100, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 200, height: 100))
    return context.makeImage()!
}

/// The red channel at `x`, `y` from the top left.
private func red(_ image: CGImage, _ x: Int, _ y: Int) -> Int {
    let context = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.draw(image, in: CGRect(x: -x, y: y - image.height + 1, width: image.width, height: image.height))
    return Int(context.data!.load(as: UInt8.self))
}

@Suite struct ImageLineTool {
    @Test func aLineIsDrawnWithoutAHead() throws {
        let blue = RGBA(red: 0, green: 0, blue: 1, alpha: 1)
        let line = ImageMark(id: "l", kind: .line(from: CGPoint(x: 20, y: 50), to: CGPoint(x: 180, y: 50)), color: blue, size: .medium, width: 4)
        let arrow = ImageMark(id: "a", kind: .arrow(from: CGPoint(x: 20, y: 50), to: CGPoint(x: 180, y: 50)), color: blue, size: .medium, width: 4)
        let lined = try #require(MarkRenderer.render([line], on: white(), imageSize: CGSize(width: 200, height: 100)))
        let arrowed = try #require(MarkRenderer.render([arrow], on: white(), imageSize: CGSize(width: 200, height: 100)))
        #expect(red(lined, 100, 50) < 60, "the line runs through the middle")
        #expect(red(lined, 170, 46) == 255 && red(arrowed, 170, 46) < 200, "only the arrow has a head")
    }

    @Test func aLineStaysALineWhenMovedOrReshaped() {
        let line = ImageMark(id: "l", kind: .line(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 10, y: 0)), color: RGBA(red: 0, green: 0, blue: 0, alpha: 1),
                             size: .medium, width: 2)
        #expect(line.moved(by: CGPoint(x: 5, y: 5)).kind == .line(from: CGPoint(x: 5, y: 5), to: CGPoint(x: 15, y: 5)))
        #expect(line.reshaped(fixed: .zero, moving: CGPoint(x: 0, y: 20), end: true).kind == .line(from: .zero, to: CGPoint(x: 0, y: 20)))
    }

    @Test func lineIsOnLAndMarkerOnH() {
        #expect(MarkupTool.line.key == "l" && MarkupTool.marker.key == "h")
        let keys = ImagePlugin.tools.compactMap(\.shortcut)
        #expect(Set(keys).count == keys.count, "every image tool with a key has one of its own, Crop's C and Markup's M included")
    }

    /// Found in review: a line was padded for an arrowhead it doesn't have, so it was selectable well off its ends.
    @Test func aLineIsHitOnlyNearItself() {
        let line = ImageMark(id: "l", kind: .line(from: CGPoint(x: 20, y: 50), to: CGPoint(x: 180, y: 50)), color: RGBA(red: 0, green: 0, blue: 0, alpha: 1),
                             size: .medium, width: 4)
        #expect(line.contains(CGPoint(x: 100, y: 55), tolerance: 2))
        #expect(!line.contains(CGPoint(x: 100, y: 70), tolerance: 2))
        #expect(line.bounds == CGRect(x: 16, y: 46, width: 168, height: 8), "padded by its width, not an arrowhead's")
    }
}
