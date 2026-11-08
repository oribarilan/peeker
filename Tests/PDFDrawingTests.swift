import AppKit
import PDFKit
import PeekerKit
@testable import PeekerPDF
import Testing

nonisolated private let red = RGBA(red: 0xDB / 255, green: 0x26 / 255, blue: 0x26 / 255, alpha: 1)
nonisolated private let blue = RGBA(red: 0x1A / 255, green: 0x66 / 255, blue: 0xE6 / 255, alpha: 1)

private func drawing(_ shape: PDFDrawing.Shape, from: CGPoint = CGPoint(x: 100, y: 300), to: CGPoint = CGPoint(x: 200, y: 340),
                     width: Double = 2, id: String = "peeker-d") throws -> PDFMark {
    let made = try #require(PDFDrawing.make(shape, from: from, to: to, points: [from, to], color: red, width: width))
    return PDFMark(id: id, page: 0, rect: made.rect, kind: .drawing(made.drawing))
}

private func drawingOf(_ annotation: PDFAnnotation) -> PDFDrawing? {
    if case .drawing(let drawing)? = PDFMarks.mark(of: annotation, page: 0)?.kind { drawing } else { nil }
}

/// The length of an arrow's head in points, from its tip to one barb.
private func headLength(_ drawing: PDFDrawing, in size: CGSize) -> Double {
    let head = drawing.strokes[1]
    return hypot((head[0].x - head[1].x) * size.width, (head[0].y - head[1].y) * size.height)
}

@Suite struct PDFDrawingShapes {
    @Test func eachShapeHasStrokesInsideItsRect() throws {
        for shape in PDFDrawing.Shape.allCases {
            let mark = try drawing(shape)
            guard case .drawing(let made) = mark.kind else { Issue.record("\(shape)"); continue }
            #expect(!made.strokes.isEmpty && made.isValid, "\(shape)")
            #expect(mark.rect.width > 0 && mark.rect.height > 0, "\(shape)")
        }
    }

    @Test func aLineRunsBetweenTheDragsEnds() throws {
        let mark = try drawing(.line, from: CGPoint(x: 100, y: 300), to: CGPoint(x: 200, y: 300))
        guard case .drawing(let line) = mark.kind else { Issue.record("\(mark)"); return }
        let ends = try #require(line.strokes.first).map { CGPoint(x: mark.rect.minX + $0.x * mark.rect.width, y: mark.rect.minY + $0.y * mark.rect.height) }
        #expect(abs(ends[0].x - 100) < 0.01 && abs(ends[1].x - 200) < 0.01 && abs(ends[0].y - 300) < 0.01)
        #expect(line.strokes.count == 1, "no head")
    }

    @Test func aDotIsACircleWideEnoughToFillItself() throws {
        let mark = try drawing(.dot, from: CGPoint(x: 100, y: 100), to: CGPoint(x: 120, y: 120))
        guard case .drawing(let dot) = mark.kind else { Issue.record("\(mark)"); return }
        #expect(dot.width == 10, "half the side")
        #expect(mark.rect == CGRect(x: 100, y: 100, width: 20, height: 20))
    }

    @Test func badDrawingsAreRefused() throws {
        guard case .drawing(var made) = try drawing(.pen).kind else { return }
        let good = made
        made.color = RGBA(red: 1, green: 0, blue: 0, alpha: 0)
        #expect(!made.isValid, "see-through")
        made = good
        made.width = .nan
        #expect(!made.isValid)
        made = good
        made.width = 500
        #expect(!made.isValid, "too wide")
        made = good
        made.strokes = []
        #expect(!made.isValid, "nothing to draw")
    }
}

@Suite struct PDFDrawingAnnotations {
    @Test func aDrawingIsInkInItsColorAndWidthAndReadsBackWithItsShape() throws {
        let mark = try drawing(.arrow, width: 3.5)
        let annotation = PDFMarks.annotation(for: mark)
        #expect(annotation.type == "Ink" && annotation.border?.lineWidth == 3.5)
        #expect(PDFMarks.type(of: annotation) == .drawing && (annotation.userName ?? "").isEmpty)
        let back = try #require(drawingOf(annotation))
        #expect(back.shape == .arrow && back.color == red && back.width == 3.5 && back.strokes.count == 2)
    }

    @Test func inkWithoutAShapeIsStillASignature() {
        let signature = PDFMarks.annotation(for: PDFMark(id: "peeker-s", page: 0, rect: CGRect(x: 10, y: 10, width: 100, height: 40),
                                                         kind: .signature(strokes: [[.zero, CGPoint(x: 1, y: 1)]])))
        #expect(PDFMarks.type(of: signature) == .signature)
    }

    @Test func resizingAnArrowKeepsItsHeadTheSameSize() throws {
        let mark = try drawing(.arrow, from: CGPoint(x: 100, y: 300), to: CGPoint(x: 200, y: 300), width: 2)
        let annotation = PDFMarks.annotation(for: mark)
        let before = headLength(try #require(drawingOf(annotation)), in: annotation.bounds.size)
        PDFMarks.setBounds(CGRect(origin: mark.rect.origin, size: CGSize(width: mark.rect.width * 2, height: mark.rect.height * 3)), of: annotation)
        let after = try #require(drawingOf(annotation))
        #expect(abs(headLength(after, in: annotation.bounds.size) - before) < 0.1, "\(before)")
    }

    @Test func aResizedDotStaysFilled() throws {
        let mark = try drawing(.dot, from: CGPoint(x: 100, y: 100), to: CGPoint(x: 120, y: 120))
        let annotation = PDFMarks.annotation(for: mark)
        PDFMarks.setBounds(CGRect(x: 100, y: 100, width: 40, height: 40), of: annotation)
        #expect(annotation.border?.lineWidth == 20)
    }

    @Test func aNewLookRecolorsAndRewidens() throws {
        let annotation = PDFMarks.annotation(for: try drawing(.box))
        PDFMarks.setLook(color: blue, width: 1, of: annotation)
        let back = try #require(drawingOf(annotation))
        #expect(back.color == blue && back.width == 1 && back.shape == .box)
    }
}

@Suite struct PDFDrawingEdits {
    @Test func aLookFoldsIntoItsAddAndOnlyTheLatestIsKept() throws {
        let mark = try drawing(.x)
        guard case .drawing(let made) = mark.kind else { return }
        let folded = PDFEdit.folded([.add(mark), .setLook(id: mark.id, page: 0, color: blue, width: 1)])
        var blueX = made
        blueX.color = blue
        blueX.width = 1
        #expect(folded == [.add(PDFMark(id: mark.id, page: 0, rect: mark.rect, kind: .drawing(blueX.rebuilt(in: mark.rect.size))))], "kept inside its rect at the new width")
        let saved = PDFEdit.folded([.setLook(id: "peeker-old", page: 0, color: blue, width: 1), .setLook(id: "peeker-old", page: 0, color: red, width: 2)])
        #expect(saved == [.setLook(id: "peeker-old", page: 0, color: red, width: 2)])
    }

    @Test func drawingsSurviveSavingAndReopening() throws {
        let file = try TempFile.makePDF(pages: 1)
        let edits: [PDFEdit] = try PDFDrawing.Shape.allCases.enumerated().map { index, shape in
            .add(try drawing(shape, from: CGPoint(x: 60, y: 60 + Double(index) * 60), to: CGPoint(x: 110, y: 100 + Double(index) * 60), id: "peeker-\(shape)"))
        }
        let saved = try #require(PDFDocument(data: try PDFPlugin.edited(edits, from: file.path))?.page(at: 0))
        let shapes = saved.annotations.compactMap(drawingOf).map(\.shape)
        #expect(Set(shapes) == Set(PDFDrawing.Shape.allCases))
        #expect(saved.annotations.allSatisfy { PDFMarks.id(of: $0) != nil && $0.color.usingColorSpace(.sRGB).map { abs($0.redComponent - red.red) < 0.01 } == true })
    }

    /// PDFKit writes a moved page's annotations from scratch, dropping keys it doesn't know.
    @Test func aDrawingOnAMovedPageKeepsItsShape() throws {
        let file = try TempFile.makePDF(pages: 2)
        let made = try #require(PDFDrawing.make(.arrow, from: CGPoint(x: 100, y: 300), to: CGPoint(x: 200, y: 340), points: [], color: red, width: 2))
        let edits: [PDFEdit] = [.add(PDFMark(id: "peeker-a", page: 1, rect: made.rect, kind: .drawing(made.drawing))), .reorderPages(order: [1, 0])]
        let saved = try #require(PDFDocument(data: try PDFPlugin.edited(edits, from: file.path))?.page(at: 0))
        #expect(saved.annotations.compactMap(drawingOf).map(\.shape) == [.arrow])
        // Saved first, moved in a later save.
        try PDFPlugin.edited([edits[0]], from: file.path).write(to: file)
        let moved = try #require(PDFDocument(data: try PDFPlugin.edited([edits[1]], from: file.path))?.page(at: 0))
        #expect(moved.annotations.compactMap(drawingOf).map(\.shape) == [.arrow])
    }

    @Test func aLookIsSavedAndUndoneThroughItsInverse() throws {
        let file = try TempFile.makePDF(pages: 1)
        let mark = try drawing(.circle)
        let document = try #require(PDFDocument(data: try PDFPlugin.edited([.add(mark)], from: file.path)))
        let look = PDFEdit.setLook(id: mark.id, page: 0, color: blue, width: 1)
        let inverse = try #require(PDFEditing.inverse(of: look, in: document))
        try PDFEditing.apply(look, to: document, fileName: "test.pdf")
        #expect(drawingOf(try #require(document.page(at: 0)?.annotations.first))?.color == blue)
        try PDFEditing.apply(inverse, to: document, fileName: "test.pdf")
        let annotation = try #require(document.page(at: 0)?.annotations.first)
        let back = try #require(drawingOf(annotation))
        #expect(abs(back.color.red - red.red) < 0.01 && abs(back.color.blue - red.blue) < 0.01, "\(back.color)")
    }

    @Test func aBadLookIsRefused() throws {
        let file = try TempFile.makePDF(pages: 1)
        let mark = try drawing(.circle)
        let document = try #require(PDFDocument(data: try PDFPlugin.edited([.add(mark)], from: file.path)))
        #expect(throws: PluginError.self) {
            try PDFEditing.apply(.setLook(id: mark.id, page: 0, color: RGBA(red: 1, green: 0, blue: 0, alpha: 0.5), width: 1), to: document, fileName: "t.pdf")
        }
    }
}
