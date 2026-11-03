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

@Suite(.serialized) struct ImageTools {
    /// The document shown in a window, ready to edit.
    private func shown(_ width: Int = 400, _ height: Int = 200) async throws -> (ImageDocument, NSWindow) {
        let document = try await open(try imageFile(try cornerImage(width: width, height: height), type: .png))
        let window = offscreenWindow(holding: document.contentView, width: 400, height: 200)
        document.canvas.frame = document.contentView.bounds
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

    @Test func theToolsAreCropOnCAndRotateAndResizeOnCmdR() {
        let byID = Dictionary(uniqueKeysWithValues: ImagePlugin.tools.map { ($0.id, $0) })
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

    /// Drags a rectangle over the image's left half.
    private func dragLeftHalf(_ overlay: CropOverlay, of document: ImageDocument) {
        let image = document.canvas.imageRect
        overlay.mouseDown(with: mouse(.leftMouseDown, CGPoint(x: image.minX, y: image.maxY), in: overlay))
        overlay.mouseDragged(with: mouse(.leftMouseDragged, CGPoint(x: image.midX, y: image.minY), in: overlay))
        overlay.mouseUp(with: mouse(.leftMouseUp, CGPoint(x: image.midX, y: image.minY), in: overlay))
    }

    /// Starts a crop and drags a rectangle over the image's left half.
    private func croppingLeftHalf(_ document: ImageDocument) throws -> CropOverlay {
        #expect(document.perform("crop"))
        let overlay = try #require(document.cropOverlay)
        dragLeftHalf(overlay, of: document)
        return overlay
    }

    @Test func cropButtonsShowOnlyOnceThereIsARectangle() async throws {
        let (document, window) = try await shown()
        defer { window.close() }
        #expect(document.perform("crop"))
        let overlay = try #require(document.cropOverlay)
        let controls = overlay.controls
        #expect(controls.superview === document.contentView, "in the scroll view, not on the zoomed image")
        #expect(controls.isHidden)
        dragLeftHalf(overlay, of: document)
        #expect(!controls.isHidden)
        #expect(document.contentView.bounds.contains(controls.frame))
    }

    @Test func cropButtonsSitBelowTheRectangle() async throws {
        let (document, window) = try await shown()
        defer { window.close() }
        #expect(document.perform("crop"))
        let overlay = try #require(document.cropOverlay)
        let image = document.canvas.imageRect
        let top = CGPoint(x: image.minX + 20, y: image.maxY - 20), bottom = CGPoint(x: image.midX, y: image.midY)
        overlay.mouseDown(with: mouse(.leftMouseDown, top, in: overlay))
        overlay.mouseDragged(with: mouse(.leftMouseDragged, bottom, in: overlay))
        let rectangle = overlay.convert(CGRect(x: top.x, y: bottom.y, width: bottom.x - top.x, height: top.y - bottom.y), to: nil)
        let buttons = overlay.controls.convert(overlay.controls.bounds, to: nil)
        #expect(buttons.maxY <= rectangle.minY, "below, in the window's upward coordinates")
        #expect(abs(buttons.maxX - rectangle.maxX) <= 1)
    }

    @Test func theCropButtonCrops() async throws {
        let (document, window) = try await shown()
        defer { window.close() }
        let controls = try croppingLeftHalf(document).controls
        controls.crop.performClick(nil)
        #expect(document.cropOverlay == nil && controls.superview == nil)
        #expect(document.edits.count == 1)
        #expect(document.pixelSize == CGSize(width: 200, height: 200), "the left half")
    }

    @Test func theCancelButtonChangesNothing() async throws {
        let (document, window) = try await shown()
        defer { window.close() }
        let controls = try croppingLeftHalf(document).controls
        controls.cancel.performClick(nil)
        #expect(document.cropOverlay == nil && controls.superview == nil)
        #expect(document.edits.isEmpty)
    }

    @Test func cropButtonsKeepTheirSizeWhenZoomed() async throws {
        let (document, window) = try await shown()
        defer { window.close() }
        let controls = try croppingLeftHalf(document).controls
        let size = controls.frame.size
        #expect(document.perform("zoom-in") && document.perform("zoom-in"))
        #expect(controls.convert(controls.bounds, to: nil).size == size)
        #expect(document.contentView.bounds.contains(controls.frame))
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

    @Test func rotateAndResizeHangsBelowTheToolbar() async throws {
        let document = try await open(try imageFile(try cornerImage(width: 400, height: 200), type: .png))
        let window = toolbarWindow(holding: document.contentView, width: 400, height: 300)
        defer { window.close() }
        let anchor = document.contentView.convert(TransformPanel.anchor(in: document.contentView), to: nil)
        #expect(window.contentLayoutRect.height < window.frame.height)  // the toolbar takes a strip
        #expect(anchor.maxY <= window.contentLayoutRect.maxY)
        #expect(abs(anchor.midX - window.contentLayoutRect.midX) <= 1)
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

/// L, R, H and V in Rotate & Resize press its turn buttons.
@Suite struct TransformPanelKeys {
    @Test func eachTurnLetterPressesItsButton() throws {
        var edits: [ImageEdit] = []
        let panel = TransformPanel(currentSize: { CGSize(width: 400, height: 200) }, onEdit: { edits.append($0) })
        for (code, letter) in [(UInt16(37), "l"), (15, "r"), (4, "h"), (9, "v")] {
            let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
                                                      context: nil, characters: letter, charactersIgnoringModifiers: letter, isARepeat: false, keyCode: code))
            panel.view.keyDown(with: event)
        }
        #expect(edits == [.rotate(by: -90), .rotate(by: 90), .flip(horizontal: true), .flip(horizontal: false)])
    }
}

/// Where the Crop and Cancel buttons sit next to the crop rectangle.
@Suite struct CropControlsPlacement {
    let size = CGSize(width: 120, height: 24)
    let visible = CGRect(x: 0, y: 0, width: 400, height: 300)

    @Test func belowTheBottomRightCornerWhenThereIsRoom() {
        let frame = CropControls.frame(size: size, selection: CGRect(x: 100, y: 100, width: 200, height: 100), visible: visible, flipped: false)
        #expect(frame == CGRect(x: 180, y: 70, width: 120, height: 24))
    }

    @Test func insideTheCornerWhenThereIsNoRoomBelow() {
        let frame = CropControls.frame(size: size, selection: CGRect(x: 100, y: 10, width: 200, height: 100), visible: visible, flipped: false)
        #expect(frame == CGRect(x: 180, y: 16, width: 120, height: 24))
    }

    @Test func keptInsideTheVisibleAreaSideways() {
        let narrow = CropControls.frame(size: size, selection: CGRect(x: 0, y: 100, width: 50, height: 50), visible: visible, flipped: false)
        #expect(narrow.minX == 0)
        let pastTheRight = CropControls.frame(size: size, selection: CGRect(x: 300, y: 100, width: 200, height: 50), visible: visible, flipped: false)
        #expect(pastTheRight.maxX == 400)
    }

    @Test func belowMeansLargerYInAFlippedView() {
        let frame = CropControls.frame(size: size, selection: CGRect(x: 100, y: 100, width: 200, height: 100), visible: visible, flipped: true)
        #expect(frame == CGRect(x: 180, y: 206, width: 120, height: 24))
        let noRoom = CropControls.frame(size: size, selection: CGRect(x: 100, y: 190, width: 200, height: 100), visible: visible, flipped: true)
        #expect(noRoom == CGRect(x: 180, y: 260, width: 120, height: 24))
    }

    @Test func keptInsideTheVisibleAreaWhenTheBottomIsScrolledAway() {
        let frame = CropControls.frame(size: size, selection: CGRect(x: 100, y: -200, width: 200, height: 400), visible: visible, flipped: false)
        #expect(frame.minY == 0)
    }
}
