import AppKit
import ImageIO
import PeekerKit
@testable import PeekerImage
import Testing
import UniformTypeIdentifiers

private func open(_ url: URL, editing: Bool = true) async throws -> ImageDocument {
    let document = try await openDocument(url, with: ImagePlugin.self, as: ImageDocument.self, editing: editing, maxPixels: 1000)
    document.undoManager.groupsByEvent = false
    return document
}

@Suite struct ImageEditability {
    @Test func onlyWritableSingleFrameImagesOfSaneSizeCanBeEdited() {
        #expect(ImagePlugin.uneditableReason(type: UTType.png.identifier, frames: 1, pixels: 1_000_000, isFloat: false) == nil)
        #expect(ImagePlugin.uneditableReason(type: UTType.jpeg.identifier, frames: 1, pixels: 100_000_000, isFloat: false) == nil)
        #expect(ImagePlugin.uneditableReason(type: "org.webmproject.webp", frames: 1, pixels: 100, isFloat: false) == "Peeker can't save this format.")
        #expect(ImagePlugin.uneditableReason(type: "com.adobe.raw-image", frames: 1, pixels: 100, isFloat: false) == "Peeker can't save this format.")
        #expect(ImagePlugin.uneditableReason(type: UTType.gif.identifier, frames: 3, pixels: 100, isFloat: false) == "This image has several frames.")
        #expect(ImagePlugin.uneditableReason(type: UTType.jpeg.identifier, frames: 1, pixels: 100_000_001, isFloat: false) == "This image is too large to edit.")
        #expect(ImagePlugin.uneditableReason(type: UTType.tiff.identifier, frames: 1, pixels: 100, isFloat: true) == "Peeker can't save this format.")
    }

    @Test func aPNGOffersEditModeInAWindowOnly() async throws {
        let url = try imageFile(try cornerImage(), type: .png)
        #expect(try await open(url).editMode == .available)
        #expect(try await open(url, editing: false).editMode == .none)
    }

    @Test func anAnimatedGIFSaysWhy() async throws {
        let url = try TempFile.make(Data(), name: "f.gif")
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, 2, nil))
        for _ in 0..<2 { CGImageDestinationAddImage(destination, try cornerImage(), nil) }
        #expect(CGImageDestinationFinalize(destination))
        #expect(try await open(url).editMode == .unavailable(reason: "This image has several frames."))
    }
}

@Suite(.serialized) struct ImageDocumentEditing {
    @Test func editsShowAtOnceAndUndoOneByOne() async throws {
        let document = try await open(try imageFile(try cornerImage(), type: .png))
        document.setEditing(true)
        #expect(document.shownSize == CGSize(width: 40, height: 20))
        document.apply(.rotate(by: 90))
        document.apply(.crop(CGRect(x: 0, y: 0, width: 1, height: 0.5)))
        #expect(document.shownSize == CGSize(width: 20, height: 20))
        #expect(document.pixelSize == CGSize(width: 20, height: 20))
        #expect(document.unsavedEdits() != nil)
        document.undoManager.undo()
        #expect(document.shownSize == CGSize(width: 20, height: 40))
        document.undoManager.redo()
        #expect(document.shownSize == CGSize(width: 20, height: 20))
        document.revertEdits()
        #expect(document.shownSize == CGSize(width: 40, height: 20) && document.unsavedEdits() == nil)
    }

    @Test func savingWritesTheFileAndStartsFromIt() async throws {
        let url = try imageFile(try cornerImage(width: 400, height: 200), type: .png)
        let document = try await open(url)
        document.setEditing(true)
        document.apply(.crop(CGRect(x: 0, y: 0, width: 0.5, height: 1)))
        try await document.save(try #require(document.unsavedEdits()), accepting: nil)
        #expect(document.unsavedEdits() == nil)
        #expect(try stored(url).image.width == 200)
        #expect(document.pixelSize == CGSize(width: 200, height: 200))
        #expect(!document.undoManager.canUndo, "the cropped pixels are gone from the file")
    }

    @Test func theInfoShowsTheSavedFile() async throws {
        let url = try imageFile(try cornerImage(width: 400, height: 200), type: .png)
        let document = try await open(url)
        document.setEditing(true)
        document.apply(.crop(CGRect(x: 0, y: 0, width: 0.5, height: 1)))
        try await document.save(try #require(document.unsavedEdits()), accepting: nil)
        #expect(document.info.contains(InfoRow(label: "Dimensions", value: "200 × 200")))
        let bytes = try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(document.info.contains(InfoRow(label: "File size", value: ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file))))
    }

    /// The host counts each `onEdit` as a change; one after a save would leave the window marked as edited.
    @Test func aSaveNeverReportsAnEdit() async throws {
        let document = try await open(try imageFile(try cornerImage(width: 400, height: 200), type: .png))
        document.setEditing(true)
        document.apply(.rotate(by: 90))
        var edits = 0
        document.onEdit = { edits += 1 }
        try await document.save(try #require(document.unsavedEdits()), accepting: nil)
        #expect(edits == 0)
    }

    @Test func recoveryReappliesEditsAndRefusesBadOnes() async throws {
        let url = try imageFile(try cornerImage(), type: .png)
        let first = try await open(url)
        first.setEditing(true)
        first.apply(.rotate(by: -90))
        first.apply(.resize(width: 10, height: 20))
        let record = try #require(first.unsavedEdits()).encoded()
        let second = try await open(url)
        #expect(second.restore(encoded: record))
        #expect(second.pixelSize == CGSize(width: 10, height: 20))
        let bad = try JSONEncoder().encode([ImageEdit.rotate(by: 45)])
        #expect(!(try await open(url)).restore(encoded: bad))
        #expect(!(try await open(url, editing: false)).restore(encoded: record))
    }
}

@Suite(.serialized) struct ImageTools {
    /// The document shown in a window, in Edit mode.
    private func shown(_ width: Int = 400, _ height: Int = 200) async throws -> (ImageDocument, NSWindow) {
        let document = try await open(try imageFile(try cornerImage(width: width, height: height), type: .png))
        let window = offscreenWindow(holding: document.contentView, width: 400, height: 200)
        document.canvas.frame = document.contentView.bounds
        document.setEditing(true)
        return (document, window)
    }

    private func mouse(_ type: NSEvent.EventType, _ point: CGPoint, in view: NSView) -> NSEvent {
        NSEvent.mouseEvent(with: type, location: view.convert(point, to: nil), modifierFlags: [], timestamp: 0, windowNumber: view.window!.windowNumber,
                           context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
    }

    private func key(_ characters: String, code: UInt16, window: NSWindow) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil,
                         characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: code)!
    }

    @Test func theCommandsAreCropOnCAndRotateAndResizeOnCmdR() {
        let byID = Dictionary(uniqueKeysWithValues: ImagePlugin.commands.map { ($0.id, $0) })
        #expect(byID["crop"]?.shortcut == "c" && byID["crop"]?.isEditTool == true)
        #expect(byID["transform"]?.shortcut == "cmd+r" && byID["transform"]?.isEditTool == true)
    }

    @Test func viewRectsAndFractionsMapBothWays() {
        let image = CGRect(x: 50, y: 0, width: 300, height: 150)
        let fractions = CropOverlay.fractions(of: CGRect(x: 50, y: 75, width: 150, height: 75), in: image)
        #expect(fractions == CGRect(x: 0, y: 0, width: 0.5, height: 0.5), "the top left quarter")
        #expect(CropOverlay.rect(for: fractions, in: image) == CGRect(x: 50, y: 75, width: 150, height: 75))
        #expect(CropOverlay.fractions(of: CGRect(x: 0, y: -50, width: 500, height: 500), in: image) == CGRect(x: 0, y: 0, width: 1, height: 1), "clamped")
    }

    @Test func returnCropsToTheDraggedRectangle() async throws {
        let (document, window) = try await shown()
        defer { window.close() }
        #expect(document.perform("crop"))
        let overlay = try #require(document.cropOverlay)
        let image = document.canvas.imageRect
        overlay.mouseDown(with: mouse(.leftMouseDown, CGPoint(x: image.minX, y: image.maxY), in: overlay))
        overlay.mouseDragged(with: mouse(.leftMouseDragged, CGPoint(x: image.midX, y: image.minY), in: overlay))
        overlay.mouseUp(with: mouse(.leftMouseUp, CGPoint(x: image.midX, y: image.minY), in: overlay))
        overlay.keyDown(with: key("\r", code: 36, window: window))
        #expect(document.cropOverlay == nil)
        #expect(document.pixelSize == CGSize(width: 200, height: 200), "the left half")
    }

    @Test func escapeCancelsTheCrop() async throws {
        let (document, window) = try await shown()
        defer { window.close() }
        #expect(document.perform("crop"))
        let overlay = try #require(document.cropOverlay)
        let image = document.canvas.imageRect
        overlay.mouseDown(with: mouse(.leftMouseDown, CGPoint(x: image.minX, y: image.maxY), in: overlay))
        overlay.mouseDragged(with: mouse(.leftMouseDragged, CGPoint(x: image.midX, y: image.midY), in: overlay))
        overlay.keyDown(with: key("\u{1b}", code: 53, window: window))
        #expect(document.cropOverlay == nil && document.edits.isEmpty)
    }

    @Test func panelKeysTurnAndFlip() async throws {
        let (document, window) = try await shown()
        defer { window.close() }
        let panel = document.transform
        for (character, code) in [("r", UInt16(15)), ("r", 15), ("h", 4), ("v", 9), ("l", 37), ("x", 7)] {
            panel.view.keyDown(with: key(character, code: code, window: window))
        }
        #expect(document.edits == [.rotate(by: 90), .rotate(by: 90), .flip(horizontal: true), .flip(horizontal: false), .rotate(by: -90)])
    }

    /// The size fields must follow a key turn as they follow a button: stale fields would resize to 400 × 800.
    @Test func applyAfterAKeyTurnKeepsTheTurnedSize() async throws {
        let (document, window) = try await shown()
        defer { window.close() }
        let panel = document.transform
        panel.view.keyDown(with: key("r", code: 15, window: window))
        panel.applySize(nil)
        #expect(document.edits == [.rotate(by: 90)])
    }

    @Test func sizesFollowTheLockAndUnit() {
        let current = CGSize(width: 400, height: 200)
        #expect(TransformPanel.targetSize(width: 50, height: 100, unit: .percent, lock: true, edited: .width, current: current)! == (200, 100))
        #expect(TransformPanel.targetSize(width: 50, height: 100, unit: .percent, lock: false, edited: .width, current: current)! == (200, 200))
        #expect(TransformPanel.targetSize(width: 800, height: 1, unit: .pixels, lock: true, edited: .width, current: current)! == (800, 400))
        #expect(TransformPanel.targetSize(width: 1, height: 50, unit: .pixels, lock: true, edited: .height, current: current)! == (100, 50))
        #expect(TransformPanel.targetSize(width: 0, height: 0, unit: .pixels, lock: false, edited: .width, current: current) == nil)
    }
}

@Suite(.serialized) struct ImageEditingReviewFixes {
    /// ImageIO ignores a PNG's orientation in the thumbnail unless the properties were read first; the window and the
    /// save must agree.
    @Test func aPNGWithOrientationShowsAndSavesTheSameWay() async throws {
        let exif: [CFString: Any] = [kCGImagePropertyOrientation: 6, kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: "2026:10:31 09:00:00"]]
        let url = try imageFile(try cornerImage(), type: .png, properties: exif)
        let document = try await open(url)
        #expect(document.shownSize.width < document.shownSize.height, "turned, as the tag says")
        #expect(document.pixelSize == CGSize(width: 20, height: 40))
        document.setEditing(true)
        document.apply(.crop(CGRect(x: 0, y: 0, width: 1, height: 0.5)))
        try await document.save(try #require(document.unsavedEdits()), accepting: nil)
        let after = try stored(url)
        #expect((after.image.width, after.image.height) == (20, 20))
        #expect(try corners(after.image) == ["blue", "red", "black", "black"])
    }

    /// An undo while saving must not leave the window showing something other than the file.
    @Test func anUndoDuringASaveStillStartsFromTheSavedFile() async throws {
        let url = try imageFile(try cornerImage(width: 400, height: 200), type: .png)
        let document = try await open(url)
        document.setEditing(true)
        document.apply(.crop(CGRect(x: 0, y: 0, width: 0.5, height: 1)))
        let snapshot = try #require(document.unsavedEdits())
        document.undoManager.undo()
        try await document.save(snapshot, accepting: nil)
        #expect(try stored(url).image.width == 200)
        #expect(document.pixelSize == CGSize(width: 200, height: 200))
        #expect(document.unsavedEdits() == nil)
    }

    @Test func enlargingStaysWithinTheEditablePixels() {
        #expect(!ImageEdit.resize(width: 20_000, height: 10_000).isValid)
        #expect(ImageEdit.resize(width: 10_000, height: 10_000).isValid)
        #expect(TransformPanel.targetSize(width: 800, height: 800, unit: .percent, lock: true, edited: .width, current: CGSize(width: 4000, height: 3000)) == nil)
    }

    @Test func aSliverAtTheEdgeStillCropsAPixel() throws {
        let rect = ImageEditing.cropRect(CGRect(x: 0.999, y: 0.999, width: 0.001, height: 0.001), in: CGSize(width: 100, height: 50))
        #expect(rect == CGRect(x: 99, y: 49, width: 1, height: 1))
        #expect(ImageEditing.apply([.crop(CGRect(x: 0.999, y: 0, width: 0.001, height: 1))], to: try cornerImage(width: 100, height: 50)) != nil)
    }

    @Test func recoveryRefusesAHugeList() async throws {
        let url = try imageFile(try cornerImage(), type: .png)
        let record = try JSONEncoder().encode(Array(repeating: ImageEdit.rotate(by: 90), count: 10_001))
        #expect(!(try await open(url)).restore(encoded: record))
    }
}

@Suite(.serialized) struct ImageZoom {
    @Test func actualSizeIsOneImagePixelPerScreenPixel() {
        #expect(ImageDocument.actualMagnification(pixelWidth: 4000, backingScale: 2, fittedWidth: 1000) == 2)
        #expect(ImageDocument.actualMagnification(pixelWidth: 64, backingScale: 2, fittedWidth: 640) == 0.05)
    }

    @Test func zoomOutGoesBelowFitAndAnImageStaysCentered() async throws {
        let document = try await open(try imageFile(try cornerImage(width: 400, height: 200), type: .png))
        let window = offscreenWindow(holding: document.contentView, width: 400, height: 200)
        defer { window.close() }
        let scroll = try #require(document.contentView as? NSScrollView)
        #expect(scroll.minMagnification <= 0.125)
        #expect(scroll.contentView is CenteringClipView)
        for _ in 0..<4 { #expect(document.perform("zoom-out")) }
        #expect(scroll.magnification < 1)
        let clip = scroll.contentView.bounds, image = document.canvas.frame
        #expect(abs(clip.midX - image.midX) < 1 && abs(clip.midY - image.midY) < 1, "centered")
        #expect(document.perform("zoom-actual"))
        let expected = ImageDocument.actualMagnification(pixelWidth: 400, backingScale: window.backingScaleFactor, fittedWidth: document.canvas.imageRect.width)
        #expect(abs(scroll.magnification - expected) < 0.001)
    }

    @Test func actualSizeIsACommandOnCmd0() {
        #expect(ImagePlugin.commands.first { $0.id == "zoom-actual" }?.shortcut == "cmd+0")
    }
}

@Suite(.serialized) struct ImageAnimation {
    /// A GIF of three solid frames (red, green, blue), 50 ms each, looping forever.
    private func gif() throws -> URL {
        let url = try TempFile.make(Data(), name: "f.gif")
        let loop = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, 3, nil))
        CGImageDestinationSetProperties(destination, loop)
        for (r, g, b) in [(1.0, 0.0, 0.0), (0, 1, 0), (0, 0, 1)] {
            let context = try #require(CGContext(data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 0,
                                                 space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.setFillColor(red: r, green: g, blue: b, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
            let delay = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.05]] as CFDictionary
            CGImageDestinationAddImage(destination, try #require(context.makeImage()), delay)
        }
        #expect(CGImageDestinationFinalize(destination))
        return url
    }

    @Test func framesPlayAndAClickPausesAndResumes() async throws {
        let document = try await open(try gif())
        let animation = try #require(document.animation)
        let first = animation.frameIndex
        try await waitUntil(seconds: 3) { animation.frameIndex != first }
        animation.toggle()
        #expect(animation.isPaused)
        let paused = animation.frameIndex
        try await Task.sleep(for: .milliseconds(300))
        #expect(animation.frameIndex == paused)
        animation.toggle()
        try await waitUntil(seconds: 3) { animation.frameIndex != paused }
    }

    @Test func aTwoPageTIFFIsNotAnimated() async throws {
        let url = try TempFile.make(Data(), name: "f.tiff")
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.tiff.identifier as CFString, 2, nil))
        for _ in 0..<2 { CGImageDestinationAddImage(destination, try cornerImage(), nil) }
        #expect(CGImageDestinationFinalize(destination))
        #expect(try await open(url).animation == nil)
    }
}
