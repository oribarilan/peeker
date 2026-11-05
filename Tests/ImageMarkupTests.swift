import AppKit
import PeekerKit
@testable import PeekerImage
import Testing
import UniformTypeIdentifiers

/// An editable white image in a window, with a pasteboard of its own and, when given, preferences of their own.
@MainActor private func shown(preferences: PluginPreferences? = nil) async throws -> (ImageDocument, NSWindow) {
    let context = CGContext(data: nil, width: 400, height: 200, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 400, height: 200))
    let url = try imageFile(context.makeImage()!, type: .png)
    let document = try await openDocument(url, with: ImagePlugin.self, as: ImageDocument.self, maxPixels: 4096, preferences: preferences)
    document.undoManager.groupsByEvent = false
    document.pasteboard = NSPasteboard(name: NSPasteboard.Name("peeker-test-\(UUID().uuidString)"))
    let window = offscreenWindow(holding: document.contentView, width: 400, height: 260)
    document.contentView.layoutSubtreeIfNeeded()
    return (document, window)
}

@MainActor private func mouse(_ type: NSEvent.EventType, at pixel: CGPoint, in overlay: MarkupOverlay, option: Bool = false, clicks: Int = 1) -> NSEvent {
    NSEvent.mouseEvent(with: type, location: overlay.convert(overlay.viewPoint(pixel), to: nil), modifierFlags: option ? .option : [], timestamp: 0,
                       windowNumber: overlay.window!.windowNumber, context: nil, eventNumber: 0, clickCount: clicks, pressure: 1)!
}

@MainActor private func drag(_ overlay: MarkupOverlay, from a: CGPoint, to b: CGPoint, option: Bool = false) {
    overlay.mouseDown(with: mouse(.leftMouseDown, at: a, in: overlay, option: option))
    overlay.mouseDragged(with: mouse(.leftMouseDragged, at: CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2), in: overlay, option: option))
    overlay.mouseDragged(with: mouse(.leftMouseDragged, at: b, in: overlay, option: option))
    overlay.mouseUp(with: mouse(.leftMouseUp, at: b, in: overlay, option: option))
}

@MainActor private func key(_ code: UInt16, in window: NSWindow) -> NSEvent {
    NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil,
                     characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: code)!
}

@Suite(.serialized) struct ImageMarkupTools {
    @Test func markupShowsTheStripAndAToolArmsIt() async throws {
        let (document, window) = try await shown()
        defer { window.close() }
        #expect(!document.isMarkingUp && document.activeTool == nil)
        #expect(document.perform("markup"))
        #expect(document.isMarkingUp && document.activeTool == "markup")
        #expect(document.perform("markup-arrow"))
        #expect(document.isOn("markup-arrow") == true && document.isOn("markup-box") == false)
        #expect(document.perform("markup"))
        #expect(!document.isMarkingUp)
        #expect(document.perform("markup-box"), "a tool's key shows the strip too")
        #expect(document.isMarkingUp)
    }

    @Test func thePeekPanelHasNoMarkup() async throws {
        let file = try imageFile(try cornerImage(), type: .png)
        let panel = try await openDocument(file, with: ImagePlugin.self, as: ImageDocument.self, editing: false)
        #expect(!panel.tools.contains { $0.id.hasPrefix("markup") })
    }

    @Test func dragsDrawMarksInImagePixels() async throws {
        let (document, window) = try await shown()
        defer { window.close() }
        #expect(document.perform("markup-arrow"))
        let overlay = try #require(document.overlay)
        drag(overlay, from: CGPoint(x: 40, y: 40), to: CGPoint(x: 200, y: 120))
        guard case .arrow(let from, let to) = document.marks.first?.kind else { Issue.record("\(document.marks)"); return }
        #expect(abs(from.x - 40) < 1 && abs(to.y - 120) < 1)
        #expect(document.perform("markup-box"))
        drag(overlay, from: CGPoint(x: 250, y: 20), to: CGPoint(x: 350, y: 80), option: true)
        #expect(document.marks.last.map { if case .box(_, true) = $0.kind { true } else { false } } == true, "an ellipse with Option")
        drag(overlay, from: CGPoint(x: 300, y: 150), to: CGPoint(x: 301, y: 151))
        #expect(document.marks.count == 2, "a tiny drag draws nothing")
        document.undoManager.undo()
        #expect(document.marks.count == 1, "one Undo per mark")
    }

    @Test func aClickDropsStepsThatRenumber() async throws {
        let (document, window) = try await shown()
        defer { window.close() }
        #expect(document.perform("markup-step"))
        let overlay = try #require(document.overlay)
        for x in [50.0, 150, 250] {
            overlay.mouseDown(with: mouse(.leftMouseDown, at: CGPoint(x: x, y: 100), in: overlay))
            overlay.mouseUp(with: mouse(.leftMouseUp, at: CGPoint(x: x, y: 100), in: overlay))
        }
        #expect(document.marks.count == 3)
        document.removeMark(id: document.marks[1].id)
        #expect(ImageMark.stepNumbers(document.marks)[document.marks[1].id] == 2)
    }

    @Test func aMarkCanBeSelectedMovedAndDeleted() async throws {
        let (document, window) = try await shown()
        defer { window.close() }
        #expect(document.perform("markup-box"))
        let overlay = try #require(document.overlay)
        drag(overlay, from: CGPoint(x: 20, y: 20), to: CGPoint(x: 120, y: 80))
        drag(overlay, from: CGPoint(x: 70, y: 50), to: CGPoint(x: 170, y: 100))
        guard case .box(let rect, _) = document.marks.first?.kind else { Issue.record("\(document.marks)"); return }
        #expect(document.marks.count == 1 && abs(rect.minX - 120) < 1 && abs(rect.minY - 70) < 1, "dragging the box moved it")
        #expect(overlay.selectedID == document.marks.first?.id)
        overlay.keyDown(with: key(51, in: window))
        #expect(document.marks.isEmpty)
        document.undoManager.undo()
        #expect(document.marks.count == 1)
    }

    @Test func dragsOnTheEdgeOfABoxResizeIt() async throws {
        let (document, window) = try await shown()
        defer { window.close() }
        #expect(document.perform("markup-box"))
        let overlay = try #require(document.overlay)
        drag(overlay, from: CGPoint(x: 20, y: 20), to: CGPoint(x: 120, y: 80))
        overlay.mouseDown(with: mouse(.leftMouseDown, at: CGPoint(x: 70, y: 50), in: overlay))
        overlay.mouseUp(with: mouse(.leftMouseUp, at: CGPoint(x: 70, y: 50), in: overlay))  // selects
        drag(overlay, from: CGPoint(x: 120, y: 80), to: CGPoint(x: 200, y: 150))
        guard case .box(let rect, _) = document.marks.first?.kind else { Issue.record("\(document.marks)"); return }
        #expect(abs(rect.minX - 20) < 1 && abs(rect.maxX - 200) < 1 && abs(rect.maxY - 150) < 1)
    }

    @Test func theStyleIsRememberedAndAppliesToTheSelection() async throws {
        let scratch = ScratchDefaults()
        defer { scratch.close() }
        let (document, window) = try await shown(preferences: scratch.preferences("image"))
        defer { window.close() }
        let blue = markupPalette[4].color
        document.setMarkupColor(blue)
        document.setMarkupSize(.large)
        #expect(document.perform("markup-arrow"))
        let overlay = try #require(document.overlay)
        drag(overlay, from: CGPoint(x: 40, y: 40), to: CGPoint(x: 200, y: 120))
        #expect(document.marks.first?.color == blue && document.marks.first?.size == .large)
        overlay.select(document.marks.first?.id)
        document.setMarkupColor(markupPalette[3].color)
        #expect(document.marks.first?.color == markupPalette[3].color, "the selected mark takes the new color")
        let (next, other) = try await shown(preferences: scratch.preferences("image"))
        defer { other.close() }
        #expect(next.markupColor == markupPalette[3].color && next.markupSize == .large)
    }

    @Test func aBadStoredStyleIsIgnored() {
        let scratch = ScratchDefaults()
        defer { scratch.close() }
        scratch.preferences("image").set("zz", for: "markupColor")
        scratch.preferences("image").set("huge", for: "markupSize")
        let (color, size) = ImageDocument.markupStyle(in: scratch.preferences("image"))
        #expect(color == markupPalette[0].color && size == .medium)
    }

    @Test func copyAndPasteAMark() async throws {
        let (document, window) = try await shown()
        defer { window.close() }
        #expect(document.perform("markup-arrow"))
        let overlay = try #require(document.overlay)
        drag(overlay, from: CGPoint(x: 40, y: 40), to: CGPoint(x: 200, y: 120))
        overlay.select(document.marks.first?.id)
        document.copy()
        #expect(document.canPasteMark)
        document.paste()
        #expect(document.marks.count == 2 && document.marks[0].id != document.marks[1].id)
        guard case .arrow(let from, _) = document.marks[1].kind else { return }
        #expect(from.x > 40 && from.y > 40, "a little below and right")
    }

    @Test func copyWithNothingSelectedCopiesTheMarkedImage() async throws {
        let (document, window) = try await shown()
        defer { window.close() }
        document.put(ImageMark(id: ImageMark.newID(), kind: .box(CGRect(x: 100, y: 50, width: 200, height: 100), ellipse: false),
                               color: markupPalette[0].color, size: .medium, width: 6))
        document.copy()
        try await waitUntil(seconds: 3) { document.pasteboard.data(forType: .png) != nil }
        let png = try #require(document.pasteboard.data(forType: .png))
        let image = try #require(NSBitmapImageRep(data: png))
        #expect(image.pixelsWide == 400 && image.pixelsHigh == 200)
        let edge = try #require(image.colorAt(x: 200, y: 50)?.usingColorSpace(.sRGB))
        #expect(edge.redComponent > 0.8 && edge.greenComponent < 0.3, "the box is in the copy")
    }
}
