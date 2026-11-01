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
