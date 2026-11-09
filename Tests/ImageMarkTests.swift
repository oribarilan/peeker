import CoreGraphics
import Foundation
import PeekerKit
@testable import PeekerImage
import Testing
import UniformTypeIdentifiers

private let red = RGBA(red: 1, green: 0, blue: 0, alpha: 1)
private func mark(_ kind: ImageMark.Kind, width: Double = 4) -> ImageMark {
    ImageMark(id: ImageMark.newID(), kind: kind, color: red, size: .medium, width: width)
}

@Suite struct ImageMarkModel {
    @Test func marksRoundTripThroughRecovery() throws {
        let marks = [mark(.arrow(from: .zero, to: CGPoint(x: 10, y: 20))), mark(.line(from: .zero, to: CGPoint(x: 5, y: 9))), mark(.box(CGRect(x: 1, y: 2, width: 3, height: 4), ellipse: true)),
                     mark(.text(origin: CGPoint(x: 5, y: 5), string: "Hi", style: TextStyle(font: .system, bold: true, italic: false, effect: .label))), mark(.pixelate(CGRect(x: 0, y: 0, width: 9, height: 9), strength: MarkStyle.defaultStrength)),
                     mark(.step(center: CGPoint(x: 3, y: 3))), mark(.pen([.zero, CGPoint(x: 1, y: 1)])), mark(.marker([.zero])),
                     mark(.spotlight(CGRect(x: 2, y: 2, width: 5, height: 5), ellipse: false))]
        let decoded = try JSONDecoder().decode([ImageMark].self, from: try JSONEncoder().encode(marks))
        #expect(decoded == marks && decoded.allSatisfy(\.isValid))
    }

    @Test func badMarksAreRefused() {
        #expect(!mark(.pen([])).isValid, "no points")
        #expect(!mark(.text(origin: .zero, string: "", style: .standard)).isValid)
        #expect(!mark(.arrow(from: CGPoint(x: CGFloat.nan, y: 0), to: .zero)).isValid)
        #expect(!mark(.step(center: .zero), width: 0).isValid)
        #expect(!ImageMark(id: "x", kind: .step(center: .zero), color: RGBA(red: 2, green: 0, blue: 0, alpha: 1), size: .small, width: 4).isValid)
        #expect(!mark(.pen(Array(repeating: .zero, count: ImageMark.maxPoints + 1))).isValid)
    }

    @Test func stepsNumberInOrderAndRenumberWhenOneGoes() {
        var marks = [mark(.step(center: .zero)), mark(.arrow(from: .zero, to: .zero)), mark(.step(center: .zero)), mark(.step(center: .zero))]
        #expect(ImageMark.stepNumbers(marks)[marks[3].id] == 3)
        marks.remove(at: 2)
        #expect(ImageMark.stepNumbers(marks)[marks[2].id] == 2)
    }

    @Test func aCropMovesMarksAndDropsTheOnesLeftOut() {
        let size = CGSize(width: 400, height: 200)
        let inside = mark(.step(center: CGPoint(x: 300, y: 100))), outside = mark(.step(center: CGPoint(x: 50, y: 100)))
        let kept = ImageMark.mapped([inside, outside], through: .crop(CGRect(x: 0.5, y: 0, width: 0.5, height: 1)), from: size)
        #expect(kept.map(\.id) == [inside.id])
        #expect(kept.first?.kind == .step(center: CGPoint(x: 100, y: 100)))
        #expect(kept.first?.width == inside.width, "a crop keeps the line width")
    }

    @Test func turnsFlipsAndResizesMoveMarks() {
        let size = CGSize(width: 400, height: 200)
        let arrow = mark(.arrow(from: CGPoint(x: 10, y: 20), to: CGPoint(x: 30, y: 40)))
        #expect(arrow.mapped(through: .rotate(by: 90), from: size)?.kind == .arrow(from: CGPoint(x: 180, y: 10), to: CGPoint(x: 160, y: 30)))
        #expect(arrow.mapped(through: .rotate(by: -90), from: size)?.kind == .arrow(from: CGPoint(x: 20, y: 390), to: CGPoint(x: 40, y: 370)))
        #expect(arrow.mapped(through: .flip(horizontal: true), from: size)?.kind == .arrow(from: CGPoint(x: 390, y: 20), to: CGPoint(x: 370, y: 40)))
        let resized = arrow.mapped(through: .resize(width: 200, height: 100), from: size)
        #expect(resized?.kind == .arrow(from: CGPoint(x: 5, y: 10), to: CGPoint(x: 15, y: 20)) && resized?.width == 2)
        let line = mark(.line(from: CGPoint(x: 10, y: 20), to: CGPoint(x: 30, y: 40)))
        #expect(line.mapped(through: .rotate(by: 90), from: size)?.kind == .line(from: CGPoint(x: 180, y: 10), to: CGPoint(x: 160, y: 30)))
        let box = mark(.box(CGRect(x: 10, y: 20, width: 30, height: 40), ellipse: false))
        #expect(box.mapped(through: .rotate(by: 90), from: size)?.kind == .box(CGRect(x: 140, y: 10, width: 40, height: 30), ellipse: false))
    }

    @Test func boxesAndEllipsesAreHitOnlyNearTheirOutline() {
        let rect = CGRect(x: 100, y: 100, width: 200, height: 100)
        for ellipse in [false, true] {
            let box = mark(.box(rect, ellipse: ellipse))
            #expect(box.contains(CGPoint(x: 101, y: 150), tolerance: 3), "on the left edge")
            #expect(box.contains(CGPoint(x: 200, y: 98), tolerance: 3), "just off the top")
            #expect(!box.contains(CGPoint(x: 200, y: 150), tolerance: 3), "the middle is left to the armed tool")
        }
        #expect(!mark(.box(rect, ellipse: true)).contains(CGPoint(x: 103, y: 103), tolerance: 3), "an ellipse misses the corner of its rect")
    }

    @Test func pixelateAndSpotlightAreHitAnywhereInside() {
        let rect = CGRect(x: 100, y: 100, width: 200, height: 100)
        #expect(mark(.pixelate(rect, strength: 10)).contains(CGPoint(x: 200, y: 150), tolerance: 3))
        #expect(mark(.spotlight(rect, ellipse: true)).contains(CGPoint(x: 200, y: 150), tolerance: 3))
    }

    @Test func sizesScaleWithTheImage() {
        #expect(MarkSize.medium.width(for: CGSize(width: 2000, height: 1000)) == 8)
        #expect(MarkSize.large.width(for: CGSize(width: 2000, height: 1000)) > MarkSize.small.width(for: CGSize(width: 2000, height: 1000)))
        #expect(MarkSize.small.width(for: CGSize(width: 10, height: 10)) == 1, "at least a pixel")
    }
}

/// A white RGB image, or one with a black-and-white checkerboard of `cell` pixels, to draw on.
private func canvas(width: Int = 200, height: Int = 100, checker cell: Int = 0) -> CGImage {
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    if cell > 0 {
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        for x in stride(from: 0, to: width, by: cell) { for y in stride(from: 0, to: height, by: cell) where (x / cell + y / cell) % 2 == 0 {
            context.fill(CGRect(x: x, y: y, width: cell, height: cell))
        } }
    }
    return context.makeImage()!
}

/// The sRGB components at (x, y) from the top left, 0 to 255.
private func pixel(_ image: CGImage, _ x: Int, _ y: Int) -> (r: Int, g: Int, b: Int) {
    let context = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.draw(image, in: CGRect(x: -x, y: y - image.height + 1, width: image.width, height: image.height))
    let p = context.data!.assumingMemoryBound(to: UInt8.self)
    return (Int(p[0]), Int(p[1]), Int(p[2]))
}

@Suite struct MarkDrawing {
    private let size = CGSize(width: 200, height: 100)

    @Test func anArrowAndABoxAreDrawnInTheirColor() throws {
        let image = try #require(MarkRenderer.render([mark(.arrow(from: CGPoint(x: 10, y: 50), to: CGPoint(x: 190, y: 50))),
                                                      mark(.box(CGRect(x: 20, y: 10, width: 40, height: 20), ellipse: false))], on: canvas(), imageSize: size))
        #expect(pixel(image, 100, 50) == (255, 0, 0), "on the arrow's shaft")
        #expect(pixel(image, 40, 10) == (255, 0, 0), "on the box's top edge")
        #expect(pixel(image, 40, 20) == (255, 255, 255), "inside the box")
        #expect(pixel(image, 100, 90) == (255, 255, 255), "elsewhere")
    }

    @Test func marksScaleToASmallerDecode() throws {
        let image = try #require(MarkRenderer.render([mark(.box(CGRect(x: 20, y: 10, width: 40, height: 20), ellipse: false), width: 8)],
                                                     on: canvas(width: 100, height: 50), imageSize: size))
        #expect(pixel(image, 20, 5) == (255, 0, 0), "the top edge at half scale")
    }

    @Test func pixelateLeavesUniformBlocks() throws {
        let image = try #require(MarkRenderer.render([mark(.pixelate(CGRect(x: 0, y: 0, width: 64, height: 64), strength: MarkStyle.defaultStrength))], on: canvas(checker: 2), imageSize: size))
        // Blocks are at least 8 pixels, so a 2-pixel checkerboard averages to one gray in each.
        let a = pixel(image, 1, 1), b = pixel(image, 2, 1), c = pixel(image, 6, 6)
        #expect(a == b && b == c && a.r > 60 && a.r < 200)
        #expect(pixel(image, 150, 80) != pixel(image, 152, 80), "outside, the checkerboard stays")
    }

    @Test func spotlightDimsOutsideItsBoxes() throws {
        let image = try #require(MarkRenderer.render([mark(.spotlight(CGRect(x: 10, y: 10, width: 30, height: 30), ellipse: false)),
                                                      mark(.spotlight(CGRect(x: 100, y: 10, width: 30, height: 30), ellipse: false))], on: canvas(), imageSize: size))
        #expect(pixel(image, 20, 20) == (255, 255, 255) && pixel(image, 110, 20) == (255, 255, 255), "inside both")
        #expect(pixel(image, 70, 80).r < 140, "dimmed outside")
    }

    @Test func aLabelFillsItsBoxAndPlainTextDoesNot() throws {
        let labeled = try #require(MarkRenderer.render([mark(.text(origin: CGPoint(x: 10, y: 10), string: "Hi", style: TextStyle(font: .system, bold: true, italic: false, effect: .label)))], on: canvas(), imageSize: size))
        #expect(pixel(labeled, 12, 26) == (255, 0, 0), "the label's fill left of its text")
        let plain = try #require(MarkRenderer.render([mark(.text(origin: CGPoint(x: 10, y: 10), string: "Hi", style: .standard))], on: canvas(), imageSize: size))
        #expect(pixel(plain, 12, 12) == (255, 255, 255), "no box behind plain text")
    }

    @Test func aStepIsAFilledBadge() throws {
        let image = try #require(MarkRenderer.render([mark(.step(center: CGPoint(x: 50, y: 50)))], on: canvas(), imageSize: size))
        #expect(pixel(image, 50 - 10, 50) == (255, 0, 0), "inside the badge, beside its number")
        #expect(pixel(image, 50 + 20, 50) == (255, 255, 255), "outside it")
    }
}

@Suite(.serialized) struct ImageMarkSaving {
    private func open(_ url: URL) async throws -> ImageDocument {
        let document = try await openDocument(url, with: ImagePlugin.self, as: ImageDocument.self, maxPixels: 4096)
        document.undoManager.groupsByEvent = false
        return document
    }

    private func white(width: Int = 400, height: Int = 200, type: UTType = .png) throws -> URL {
        try imageFile(canvas(width: width, height: height), type: type)
    }

    @Test func aSavedMarkIsInTheFileAtFullSize() async throws {
        let url = try white()
        let document = try await open(url)
        document.put(mark(.box(CGRect(x: 100, y: 50, width: 200, height: 100), ellipse: false), width: 6))
        try await document.save(try #require(document.unsavedEdits()), accepting: nil)
        let file = try stored(url).image
        #expect((file.width, file.height) == (400, 200))
        #expect(pixel(file, 200, 50) == (255, 0, 0) && pixel(file, 200, 100) == (255, 255, 255))
        #expect(document.unsavedEdits() == nil)
    }

    @Test func movingASavedMarkLeavesNoTraceOfItsOldPlace() async throws {
        let url = try white()
        let document = try await open(url)
        var box = mark(.box(CGRect(x: 20, y: 20, width: 60, height: 60), ellipse: false), width: 6)
        document.put(box)
        try await document.save(try #require(document.unsavedEdits()), accepting: nil)
        box.kind = .box(CGRect(x: 250, y: 20, width: 60, height: 60), ellipse: false)
        document.put(box)
        try await document.save(try #require(document.unsavedEdits()), accepting: nil)
        let file = try stored(url).image
        #expect(pixel(file, 50, 20) == (255, 255, 255), "the old top edge is gone")
        #expect(pixel(file, 280, 20) == (255, 0, 0))
        document.undoManager.undo()
        #expect(document.marks.first?.kind == .box(CGRect(x: 20, y: 20, width: 60, height: 60), ellipse: false), "Undo past a save")
    }

    @Test func aJPEGIsEncodedFromTheFileAsItOpenedAtEachSave() async throws {
        let url = try white(type: .jpeg)
        let document = try await open(url)
        document.put(mark(.step(center: CGPoint(x: 50, y: 50))))
        try await document.save(try #require(document.unsavedEdits()), accepting: nil)
        let first = try Data(contentsOf: url)
        document.put(mark(.step(center: CGPoint(x: 150, y: 50))))
        document.undoManager.undo()  // back to the saved marks, but counted as a change since the save
        document.put(mark(.step(center: CGPoint(x: 150, y: 50))))
        document.undoManager.undo()
        try await document.save(UnsavedEdits(ImageSnapshot(state: ImageState(edits: [], marks: document.marks), original: nil)), accepting: nil)
        #expect(try Data(contentsOf: url) == first, "the same marks on the same original give the same bytes, not a second generation")
    }

    @Test func editsAfterASaveComeBackFromRecovery() async throws {
        let url = try white()
        let document = try await open(url)
        var box = mark(.box(CGRect(x: 20, y: 20, width: 60, height: 60), ellipse: false))
        document.put(box)
        try await document.save(try #require(document.unsavedEdits()), accepting: nil)
        box.kind = .box(CGRect(x: 250, y: 20, width: 60, height: 60), ellipse: false)
        document.put(box)
        let record = try #require(document.unsavedEdits()).encoded()
        let relaunched = try await open(url)
        #expect(relaunched.restore(encoded: record))
        #expect(relaunched.marks == document.marks)
        try await relaunched.save(try #require(relaunched.unsavedEdits()), accepting: nil)
        #expect(pixel(try stored(url).image, 50, 20) == (255, 255, 255), "drawn on the file as it opened, without the old box")
    }

    @Test func aCropMovesTheMarks() async throws {
        let document = try await open(try white())
        document.put(mark(.step(center: CGPoint(x: 300, y: 100))))
        document.apply(.crop(CGRect(x: 0.5, y: 0, width: 0.5, height: 1)))
        #expect(document.marks.first?.kind == .step(center: CGPoint(x: 100, y: 100)))
        document.undoManager.undo()
        #expect(document.marks.first?.kind == .step(center: CGPoint(x: 300, y: 100)))
    }
}

@Suite(.serialized) struct ImageMarkRevert {
    @Test func revertAfterRecoveringOnASavedFileShowsTheFileOnDisk() async throws {
        let url = try imageFile(canvas(width: 400, height: 200), type: .png)
        let document = try await openDocument(url, with: ImagePlugin.self, as: ImageDocument.self, maxPixels: 4096)
        document.apply(.crop(CGRect(x: 0, y: 0, width: 0.5, height: 1)))
        try await document.save(try #require(document.unsavedEdits()), accepting: nil)
        document.put(mark(.step(center: CGPoint(x: 50, y: 50))))
        let record = try #require(document.unsavedEdits()).encoded()
        let relaunched = try await openDocument(url, with: ImagePlugin.self, as: ImageDocument.self, maxPixels: 4096)
        #expect(relaunched.restore(encoded: record))
        #expect(relaunched.pixelSize == CGSize(width: 200, height: 200), "the crop from the original, as before the crash")
        relaunched.revertEdits()
        #expect(relaunched.pixelSize == CGSize(width: 200, height: 200) && relaunched.marks.isEmpty && relaunched.unsavedEdits() == nil,
                "the saved, cropped file, with nothing pending")
    }
}

@Suite(.serialized) struct ImageSymlinkSaving {
    /// Saving through a link writes the file it points to; the second save must still start from the file as it opened.
    @Test func aLinkedImageGetsItsEditsOnce() async throws {
        let target = try imageFile(canvas(width: 400, height: 200), type: .png)
        let link = target.deletingLastPathComponent().appending(path: "link-\(UUID().uuidString).png")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        let document = try await openDocument(link, with: ImagePlugin.self, as: ImageDocument.self, maxPixels: 4096)
        document.apply(.crop(CGRect(x: 0, y: 0, width: 0.5, height: 1)))
        try await document.save(try #require(document.unsavedEdits()), accepting: nil)
        document.put(mark(.step(center: CGPoint(x: 50, y: 50))))
        try await document.save(try #require(document.unsavedEdits()), accepting: nil)
        #expect(try stored(target).image.width == 200, "cropped once, not twice")
    }
}
