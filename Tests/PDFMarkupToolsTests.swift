import AppKit
import PDFKit
import PeekerKit
@testable import PeekerPDF
import Testing

nonisolated private let blue = RGBA(red: 0x1A / 255, green: 0x66 / 255, blue: 0xE6 / 255, alpha: 1)

private func open(_ file: URL) async throws -> (PDFPluginDocument, NSWindow) {
    let document = try await openDocument(file, with: PDFPlugin.self, as: PDFPluginDocument.self)
    document.undoManager.groupsByEvent = false  // no event loop here to close each step's group
    let window = offscreenWindow(holding: document.pdfView)
    document.pdfView.autoScales = false
    document.pdfView.scaleFactor = 1
    document.pdfView.layoutDocumentView()
    return (document, window)
}

/// A mouse event at `point` in page 0's space.
private func mouse(
    _ type: NSEvent.EventType, at point: CGPoint, in document: PDFPluginDocument, window: NSWindow,
    flags: NSEvent.ModifierFlags = []
) -> NSEvent {
    let page = document.pdfView.document!.page(at: 0)!
    let location = document.pdfView.convert(document.pdfView.convert(point, from: page), to: nil)
    return NSEvent.mouseEvent(
        with: type, location: location, modifierFlags: flags, timestamp: 0, windowNumber: window.windowNumber,
        context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
}

/// A press at `start`, moves through `through`, and a release at the last point, all in page 0's space.
private func drag(
    _ document: PDFPluginDocument, _ window: NSWindow, from start: CGPoint, through points: [CGPoint], flags: NSEvent.ModifierFlags = []
) throws {
    let tools = try #require(document.prepareEditing())
    let page = try #require(document.pdfView.document?.page(at: 0))
    #expect(tools.mouseDown(with: mouse(.leftMouseDown, at: start, in: document, window: window), at: document.pdfView.convert(start, from: page)))
    for point in points { _ = tools.mouseDragged(with: mouse(.leftMouseDragged, at: point, in: document, window: window, flags: flags)) }
    _ = tools.mouseUp(with: mouse(.leftMouseUp, at: points.last ?? start, in: document, window: window, flags: flags))
}

private func drawings(_ document: PDFPluginDocument) -> [PDFDrawing] {
    (document.pdfView.document?.page(at: 0)?.annotations ?? []).compactMap(PDFMarks.drawing(of:))
}

@Suite(.serialized) struct PDFDrawingTools {
    @Test func aDragDrawsWithPenLineArrowOrBoxAndTheToolStaysArmed() async throws {
        let (document, window) = try await open(try TempFile.makePDF(pages: 1))
        defer { window.close() }
        let tools = try #require(document.prepareEditing())
        for (index, shape) in [PDFDrawing.Shape.pen, .line, .arrow, .box].enumerated() {
            tools.arm(shape)
            let y = 200 + Double(index) * 80
            try drag(document, window, from: CGPoint(x: 100, y: y), through: [CGPoint(x: 140, y: y + 30), CGPoint(x: 200, y: y + 50)])
            #expect(drawings(document).last?.shape == shape)
            #expect(tools.armedShape == shape, "\(shape) stays armed")
        }
        #expect(drawings(document).count == 4)
        #expect(drawings(document).allSatisfy { $0.color == document.markupColor && $0.width == document.markupSize.width })
    }

    @Test func optionMakesTheBoxAnEllipse() async throws {
        let (document, window) = try await open(try TempFile.makePDF(pages: 1))
        defer { window.close() }
        try #require(document.prepareEditing()).arm(.box)
        try drag(document, window, from: CGPoint(x: 100, y: 300), through: [CGPoint(x: 200, y: 360)], flags: .option)
        #expect(drawings(document).map(\.shape) == [.ellipse])
    }

    @Test func aClickDropsAStampAtTheStripsSizeAndAPenClickDrawsNothing() async throws {
        let (document, window) = try await open(try TempFile.makePDF(pages: 1))
        defer { window.close() }
        let tools = try #require(document.prepareEditing())
        tools.arm(.pen)
        try drag(document, window, from: CGPoint(x: 150, y: 400), through: [])
        #expect(drawings(document).isEmpty)
        tools.arm(.check)
        try drag(document, window, from: CGPoint(x: 150, y: 400), through: [])
        let stamp = try #require(document.pdfView.document?.page(at: 0)?.annotations.first)
        let side = document.markupSize.stampSide
        #expect(stamp.bounds == CGRect(x: 150 - side / 2, y: 400 - side / 2, width: side, height: side))
        #expect(PDFMarks.drawing(of: stamp)?.shape == .check)
    }

    @Test func aDragFitsAStampToItsRectangle() async throws {
        let (document, window) = try await open(try TempFile.makePDF(pages: 1))
        defer { window.close() }
        try #require(document.prepareEditing()).arm(.x)
        try drag(document, window, from: CGPoint(x: 100, y: 300), through: [CGPoint(x: 160, y: 340)])
        let bounds = try #require(document.pdfView.document?.page(at: 0)?.annotations.first?.bounds)
        #expect([bounds.minX - 100, bounds.minY - 300, bounds.width - 60, bounds.height - 40].allSatisfy { abs($0) < 0.5 }, "\(bounds)")
    }

    @Test func aDragStartingOnAMarkMovesItInstead() async throws {
        let (document, window) = try await open(try TempFile.makePDF(pages: 1))
        defer { window.close() }
        let tools = try #require(document.prepareEditing())
        tools.arm(.box)
        try drag(document, window, from: CGPoint(x: 100, y: 300), through: [CGPoint(x: 200, y: 360)])
        tools.arm(.line)
        try drag(document, window, from: CGPoint(x: 100, y: 330), through: [CGPoint(x: 120, y: 330)])
        #expect(drawings(document).map(\.shape) == [.box], "no line")
        #expect(document.pdfView.document?.page(at: 0)?.annotations.first.map { abs($0.bounds.minX - 120) < 0.5 } == true)
    }

    @Test func eachMarkIsOneUndoStep() async throws {
        let (document, window) = try await open(try TempFile.makePDF(pages: 1))
        defer { window.close() }
        try #require(document.prepareEditing()).arm(.pen)
        try drag(document, window, from: CGPoint(x: 100, y: 300), through: (1...20).map { CGPoint(x: 100 + Double($0) * 5, y: 300 + Double($0 % 3)) })
        try drag(document, window, from: CGPoint(x: 100, y: 500), through: [CGPoint(x: 200, y: 520)])
        document.undoManager.undo()
        #expect(drawings(document).count == 1)
    }

    @Test func escapeDisarms() async throws {
        let (document, window) = try await open(try TempFile.makePDF(pages: 1))
        defer { window.close() }
        let tools = try #require(document.prepareEditing())
        tools.arm(.arrow)
        #expect(document.activeTool == "markup" && document.isOn("markup-arrow") == true && document.isOn("markup-pen") == false)
        tools.end()
        #expect(tools.armedShape == nil)
    }
}

@Suite(.serialized) struct PDFDrawingSelection {
    @Test func aLineIsHitOnlyNearItsStroke() throws {
        let made = try #require(PDFDrawing.make(.line, from: CGPoint(x: 100, y: 100), to: CGPoint(x: 300, y: 300), points: [], color: blue, width: 2))
        let line = PDFMarks.annotation(for: PDFMark(id: "peeker-l", page: 0, rect: made.rect, kind: .drawing(made.drawing)))
        #expect(EditController.hit([line], at: CGPoint(x: 200, y: 201)) === line)
        #expect(EditController.hit([line], at: CGPoint(x: 280, y: 120)) == nil, "inside its rect, far from the line")
    }

    @Test func restylingTheSelectedDrawingIsOneUndoableEditAndIsRemembered() async throws {
        let (document, window) = try await open(try TempFile.makePDF(pages: 1))
        defer { window.close() }
        let tools = try #require(document.prepareEditing())
        tools.arm(.box)
        try drag(document, window, from: CGPoint(x: 100, y: 300), through: [CGPoint(x: 200, y: 360)])
        let before = try #require(drawings(document).first)
        tools.end()
        try drag(document, window, from: CGPoint(x: 100, y: 330), through: [])  // a click selects it
        #expect(tools.selectedID != nil)
        tools.applyDrawingLook(color: blue, size: .large)
        #expect(drawings(document).first.map { $0.color == blue && $0.width == MarkupSize.large.width } == true)
        #expect(document.markupColor == blue && document.markupSize == .large)
        document.undoManager.undo()
        #expect(drawings(document).first?.color == before.color)
    }
}

@Suite(.serialized) struct PDFMarkupStripTests {
    private func shown() async throws -> (PDFPluginDocument, NSWindow) {
        let document = try await openDocument(try TempFile.makePDF(pages: 1), with: PDFPlugin.self, as: PDFPluginDocument.self)
        document.undoManager.groupsByEvent = false
        return (document, offscreenWindow(holding: document.contentView))
    }

    @Test func markupShowsTheStripAndItsToolsSwapTheDetails() async throws {
        let (document, window) = try await shown()
        defer { window.close() }
        #expect(document.perform("markup"))
        let strip = try #require(document.markupStrip)
        #expect(!strip.showsText && strip.tools.selectedSegment == -1)
        #expect(document.perform("markup-check"))
        #expect(strip.tools.selectedSegment == PDFPlugin.markupTools.firstIndex { $0.id == "markup-check" })
        #expect(document.perform("text-box"))
        #expect(strip.showsText && strip.tools.selectedSegment == 0)
        #expect(document.perform("markup"))
        #expect(document.markupStrip == nil && document.editController?.armedShape == nil)
    }

    @Test func aSwatchRecolorsTheSelectedDrawing() async throws {
        let (document, window) = try await shown()
        defer { window.close() }
        let tools = try #require(document.prepareEditing())
        let made = try #require(
            PDFDrawing.make(
                .box, from: CGPoint(x: 100, y: 300), to: CGPoint(x: 200, y: 360), points: [], color: PDFMarkupStrip.palette[0].color, width: 2))
        let mark = PDFMark(id: PDFEdit.newID(), page: 0, rect: made.rect, kind: .drawing(made.drawing))
        #expect(document.change(.add(mark)))
        tools.select(mark.id, page: 0)
        let strip = try #require(document.markupStrip, "a selected drawing shows the strip")
        strip.swatches[4].performClick(nil)
        let annotation = try #require(document.pdfView.document?.page(at: 0)?.annotations.first)
        #expect(PDFMarks.drawing(of: annotation)?.color == PDFMarkupStrip.palette[4].color)
    }

    /// A new window is 960 points wide; the sidebar takes about 200 of them.
    @Test func theStripFitsBesideTheSidebar() {
        let strip = PDFMarkupStrip()
        for state in [EditController.StripState.text(.standard, 12), .drawing(PDFMarkupStrip.palette[0].color, .medium)] {
            strip.show(tool: nil, state: state)
            #expect(strip.fittingSize.width <= 760, "\(state): \(strip.fittingSize.width) points")
        }
    }
}

/// Found in review.
@Suite(.serialized) struct PDFMarkupReviewFixes {
    private func shown() async throws -> (PDFPluginDocument, NSWindow) {
        let document = try await openDocument(try TempFile.makePDF(pages: 1), with: PDFPlugin.self, as: PDFPluginDocument.self)
        document.undoManager.groupsByEvent = false
        return (document, offscreenWindow(holding: document.contentView))
    }

    private func add(
        _ shape: PDFDrawing.Shape, color: RGBA, to document: PDFPluginDocument, from: CGPoint = CGPoint(x: 100, y: 300),
        to: CGPoint = CGPoint(x: 160, y: 360)
    ) throws -> PDFMark {
        let made = try #require(PDFDrawing.make(shape, from: from, to: to, points: [from, to], color: color, width: 2))
        let mark = PDFMark(id: PDFEdit.newID(), page: 0, rect: made.rect, kind: .drawing(made.drawing))
        #expect(document.change(.add(mark)))
        try #require(document.prepareEditing()).select(mark.id, page: 0)
        return mark
    }

    @Test func aSizeKeepsTheSelectedDrawingsColor() async throws {
        let (document, window) = try await shown()
        defer { window.close() }
        _ = try add(.arrow, color: PDFMarkupStrip.palette[1].color, to: document)
        let strip = try #require(document.markupStrip)
        let sizes = strip.sizes
        sizes.selectedSegment = 2
        _ = sizes.sendAction(sizes.action, to: sizes.target)
        let drawing = try #require(document.pdfView.document?.page(at: 0)?.annotations.first.flatMap(PDFMarks.drawing(of:)))
        #expect(drawing.color == PDFMarkupStrip.palette[1].color && drawing.width == MarkupSize.large.width)
    }

    @Test func aPenLoopThatEndsWhereItStartedIsKept() async throws {
        let (document, window) = try await shown()
        defer { window.close() }
        let tools = try #require(document.prepareEditing())
        tools.arm(.pen)
        let page = try #require(document.pdfView.document?.page(at: 0))
        let points = [CGPoint(x: 100, y: 300), CGPoint(x: 140, y: 300), CGPoint(x: 140, y: 340), CGPoint(x: 101, y: 301)]
        let event = { (type: NSEvent.EventType, point: CGPoint) in
            NSEvent.mouseEvent(
                with: type, location: document.pdfView.convert(document.pdfView.convert(point, from: page), to: nil), modifierFlags: [],
                timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
        }
        #expect(tools.mouseDown(with: event(.leftMouseDown, points[0]), at: document.pdfView.convert(points[0], from: page)))
        for point in points.dropFirst() { _ = tools.mouseDragged(with: event(.leftMouseDragged, point)) }
        _ = tools.mouseUp(with: event(.leftMouseUp, points.last!))
        #expect(page.annotations.count == 1)
    }

    @Test func aBigDotIsValidAndResizesFilled() async throws {
        let (document, window) = try await shown()
        defer { window.close() }
        let mark = try add(.dot, color: PDFMarkupStrip.palette[0].color, to: document, from: CGPoint(x: 100, y: 100), to: CGPoint(x: 300, y: 300))
        let annotation = try #require(document.pdfView.document?.page(at: 0)?.annotations.first)
        #expect(annotation.border?.lineWidth == 100)
        #expect(document.change(.setBounds(id: mark.id, type: .drawing, page: 0, rect: CGRect(x: 100, y: 100, width: 400, height: 400))))
        #expect(annotation.border?.lineWidth == 200 && PDFMarks.drawing(of: annotation) != nil)
    }

    @Test func aSizeForADotResizesItAroundItsCenter() async throws {
        let (document, window) = try await shown()
        defer { window.close() }
        _ = try add(.dot, color: PDFMarkupStrip.palette[0].color, to: document, from: CGPoint(x: 100, y: 100), to: CGPoint(x: 122, y: 122))
        try #require(document.editController).applyDrawingLook(color: PDFMarkupStrip.palette[0].color, size: .large)
        let bounds = try #require(document.pdfView.document?.page(at: 0)?.annotations.first?.bounds)
        #expect(bounds == CGRect(x: 111 - 17, y: 111 - 17, width: 34, height: 34))
    }

    @Test func aReopenedColorIsTheSwatchsOwn() throws {
        let file = try TempFile.makePDF(pages: 1)
        let made = try #require(
            PDFDrawing.make(
                .box, from: CGPoint(x: 100, y: 300), to: CGPoint(x: 160, y: 360), points: [], color: PDFMarkupStrip.palette[1].color, width: 2))
        let saved = try #require(
            PDFDocument(
                data: try PDFPlugin.edited([.add(PDFMark(id: "peeker-b", page: 0, rect: made.rect, kind: .drawing(made.drawing)))], from: file.path)))
        let annotation = try #require(saved.page(at: 0)?.annotations.first)
        #expect(PDFMarks.drawing(of: annotation)?.color == PDFMarkupStrip.palette[1].color)
    }

    @Test func aBoxIsHitOnlyOnItsOutline() throws {
        let made = try #require(PDFDrawing.make(.box, from: CGPoint(x: 100, y: 100), to: CGPoint(x: 300, y: 300), points: [], color: blue, width: 2))
        let box = PDFMarks.annotation(for: PDFMark(id: "peeker-b", page: 0, rect: made.rect, kind: .drawing(made.drawing)))
        #expect(EditController.hit([box], at: CGPoint(x: 101, y: 200)) === box)
        #expect(EditController.hit([box], at: CGPoint(x: 200, y: 200)) == nil, "a field inside it stays clickable")
    }

    @Test func turningMarkupOffHidesTheStripEvenWithAMarkSelected() async throws {
        let (document, window) = try await shown()
        defer { window.close() }
        #expect(document.perform("markup"))
        _ = try add(.x, color: blue, to: document)
        #expect(document.perform("markup"))
        #expect(document.markupStrip == nil)
    }

    @Test func aDrawingWithAnUnknownShapeIsLeftAlone() {
        let annotation = PDFAnnotation(bounds: CGRect(x: 10, y: 10, width: 50, height: 50), forType: .ink, withProperties: nil)
        PDFMarks.setID("peeker-x", on: annotation)
        annotation.setValue("spiral", forAnnotationKey: PDFMarks.shapeKey)
        #expect(PDFMarks.type(of: annotation) == nil)
    }

    @Test func drawingsAndLooksComeBackFromARecoveryRecord() async throws {
        let (document, window) = try await shown()
        defer { window.close() }
        let made = try #require(
            PDFDrawing.make(.arrow, from: CGPoint(x: 100, y: 300), to: CGPoint(x: 200, y: 340), points: [], color: blue, width: 2))
        let mark = PDFMark(id: "peeker-r", page: 0, rect: made.rect, kind: .drawing(made.drawing))
        let record = try JSONEncoder().encode([PDFEdit.add(mark), .setLook(id: mark.id, page: 0, color: PDFMarkupStrip.palette[1].color, width: 3.5)])
        #expect(document.restore(encoded: record))
        let annotation = try #require(document.pdfView.document?.page(at: 0)?.annotations.first)
        #expect(PDFMarks.drawing(of: annotation).map { $0.shape == .arrow && $0.width == 3.5 } == true)
    }
}
