import AppKit
import PDFKit
import PeekerKit
@testable import PeekerPDF
import Testing

nonisolated private let place = CGRect(x: 100, y: 300, width: 180, height: 60)

private func open(_ file: URL) async throws -> PDFPluginDocument {
    let document = try await openDocument(file, with: PDFPlugin.self, as: PDFPluginDocument.self)
    document.undoManager.groupsByEvent = false  // no event loop here to close each step's group
    document.setEditing(true)
    return document
}

/// `document`'s view in an off-screen window, laid out at 100%.
@discardableResult
private func inWindow(_ document: PDFPluginDocument) -> NSWindow {
    let window = offscreenWindow(holding: document.pdfView)
    document.pdfView.autoScales = false
    document.pdfView.scaleFactor = 1
    document.pdfView.layoutDocumentView()
    return window
}

/// A mouse event at `point` in page 0's space.
private func mouse(_ type: NSEvent.EventType, at point: CGPoint, in document: PDFPluginDocument, window: NSWindow) -> NSEvent {
    let page = document.pdfView.document!.page(at: 0)!
    let location = document.pdfView.convert(document.pdfView.convert(point, from: page), to: nil)
    return NSEvent.mouseEvent(with: type, location: location, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
                              context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
}

/// Drags the mark under `start` to `end` (page 0's space) with the mouse, through the tools as the view hands them
/// the events.
private func drag(in document: PDFPluginDocument, window: NSWindow, from start: CGPoint, to end: CGPoint) throws {
    let tools = try #require(document.tools)
    let page = try #require(document.pdfView.document?.page(at: 0))
    #expect(tools.mouseDown(with: mouse(.leftMouseDown, at: start, in: document, window: window), at: document.pdfView.convert(start, from: page)))
    #expect(tools.mouseDragged(with: mouse(.leftMouseDragged, at: end, in: document, window: window)))
    #expect(tools.mouseUp(with: mouse(.leftMouseUp, at: end, in: document, window: window)))
}

@Suite struct PDFSelecting {
    private func annotation(id: String?, _ rect: CGRect = place, type: PDFAnnotationSubtype = .freeText) -> PDFAnnotation {
        let annotation = PDFAnnotation(bounds: rect, forType: type, withProperties: nil)
        if let id { annotation.setValue(id, forAnnotationKey: .name) }
        return annotation
    }

    @Test func onlyPeekersOwnAnnotationsCanBeSelected() {
        let ours = annotation(id: "peeker-1"), theirs = annotation(id: "acrobat-1"), unnamed = annotation(id: nil)
        let point = CGPoint(x: place.midX, y: place.midY)
        #expect(EditController.hit([ours], at: point) === ours)
        #expect(EditController.hit([theirs, unnamed], at: point) == nil)
        #expect(EditController.hit([ours], at: CGPoint(x: 10, y: 10)) == nil)
    }

    @Test func theTopmostOfOverlappingMarksIsHit() {
        let lower = annotation(id: "peeker-1"), upper = annotation(id: "peeker-2")
        #expect(EditController.hit([lower, upper], at: CGPoint(x: place.midX, y: place.midY)) === upper)
    }

    @Test func formFieldsAndLinksAreNotSelectable() {
        let widget = annotation(id: "peeker-w", type: .widget), link = annotation(id: "peeker-l", type: .link)
        #expect(EditController.hit([widget, link], at: CGPoint(x: place.midX, y: place.midY)) == nil)
    }

    @Test func cornerHandlesAreFoundWithinTheTolerance() {
        #expect(EditController.corner(at: CGPoint(x: 102, y: 358), of: place, tolerance: 5) == .topLeft)
        #expect(EditController.corner(at: CGPoint(x: 280, y: 300), of: place, tolerance: 5) == .bottomRight)
        #expect(EditController.corner(at: CGPoint(x: 190, y: 330), of: place, tolerance: 5) == nil)
    }

    @Test func resizingMovesOnlyTheDraggedCorner() {
        #expect(EditController.resized(place, corner: .bottomRight, by: CGSize(width: 20, height: -10)) == CGRect(x: 100, y: 290, width: 200, height: 70))
        #expect(EditController.resized(place, corner: .topLeft, by: CGSize(width: -10, height: 5)) == CGRect(x: 90, y: 300, width: 190, height: 65))
    }

    @Test func resizingStopsAtAMinimumSize() {
        let rect = EditController.resized(place, corner: .topRight, by: CGSize(width: -500, height: -500))
        #expect(rect.width == EditController.minimumSize && rect.height == EditController.minimumSize)
        #expect(rect.minX == 100 && rect.minY == 300, "the opposite corner stays put")
    }
}

@Suite struct PDFAdjusting {
    /// Leaving Edit mode mid-drag must not leave a moved mark that isn't pending or undoable.
    @Test func leavingEditModeMidDragPutsTheMarkBack() async throws {
        let document = try await open(try TempFile.makePDF(pages: 1))
        let window = inWindow(document)
        let mark = PDFMark(id: PDFEdit.newID(), page: 0, rect: place, kind: .textBox(text: "x", fontSize: 12))
        #expect(document.change(.add(mark)))
        let pending = document.pendingEdits
        let page = try #require(document.pdfView.document?.page(at: 0))
        func event(_ type: NSEvent.EventType, _ point: CGPoint) -> NSEvent { mouse(type, at: point, in: document, window: window) }
        let tools = try #require(document.tools)
        let start = CGPoint(x: place.midX, y: place.midY)
        #expect(tools.mouseDown(with: event(.leftMouseDown, start), at: document.pdfView.convert(start, from: page)))
        #expect(tools.mouseDragged(with: event(.leftMouseDragged, CGPoint(x: start.x + 50, y: start.y))))
        #expect(PDFMarks.find(mark.id, on: page)?.bounds != place)
        document.setEditing(false)
        #expect(PDFMarks.find(mark.id, on: page)?.bounds == place)
        #expect(document.pendingEdits == pending)
    }

    /// A mark off its page can't be saved, so every later save would fail until an undo.
    @Test func aMarkDraggedOffThePageStaysOnItAndSaves() async throws {
        let file = try TempFile.makePDF(pages: 1)
        let document = try await open(file)
        let window = inWindow(document)
        let mark = PDFMark(id: PDFEdit.newID(), page: 0, rect: place, kind: .textBox(text: "x", fontSize: 12))
        #expect(document.change(.add(mark)))
        let page = try #require(document.pdfView.document?.page(at: 0))
        func event(_ type: NSEvent.EventType, _ point: CGPoint) -> NSEvent { mouse(type, at: point, in: document, window: window) }
        let tools = try #require(document.tools)
        let start = CGPoint(x: place.midX, y: place.midY)
        let off = CGPoint(x: start.x + 2000, y: start.y - 2000)
        #expect(tools.mouseDown(with: event(.leftMouseDown, start), at: document.pdfView.convert(start, from: page)))
        #expect(tools.mouseDragged(with: event(.leftMouseDragged, off)))
        #expect(tools.mouseUp(with: event(.leftMouseUp, off)))
        let moved = try #require(PDFMarks.find(mark.id, on: page)?.bounds)
        #expect(moved.intersects(page.bounds(for: .mediaBox)))
        try await document.save(try #require(document.unsavedEdits()), accepting: nil)
    }

    @Test func movingASavedMarkIsAnEditThatKeepsItsName() async throws {
        let file = try TempFile.makePDF(pages: 1)
        try await PDFPlugin.write([.add(PDFMark(id: "peeker-s", page: 0, rect: place, kind: .signature(strokes: [[.zero, CGPoint(x: 1, y: 1)]])))], to: file.path)
        let document = try await open(file)
        let window = inWindow(document)
        var edits = 0
        document.onEdit = { edits += 1 }
        let moved = place.offsetBy(dx: 30, dy: 0)
        try drag(in: document, window: window, from: CGPoint(x: place.midX, y: place.midY), to: CGPoint(x: moved.midX, y: moved.midY))
        #expect(edits == 1)
        #expect(document.pendingEdits == [.setBounds(id: "peeker-s", type: .signature, page: 0, rect: moved)])
        try await document.save(try #require(document.unsavedEdits()), accepting: nil)
        let saved = try #require(PDFDocument(url: file)?.page(at: 0)?.annotations)
        #expect(saved.count == 1 && PDFMarks.id(of: saved[0]) == "peeker-s" && abs(saved[0].bounds.minX - 130) < 0.5)
    }

    @Test func deletingTheSelectionRemovesIt() async throws {
        let document = try await open(try TempFile.makePDF(pages: 1))
        let mark = PDFMark(id: PDFEdit.newID(), page: 0, rect: place, kind: .textBox(text: "x", fontSize: 12))
        #expect(document.change(.add(mark)))
        let tools = try #require(document.tools)
        tools.select(mark.id, page: 0)
        #expect(tools.deleteSelection())
        #expect(document.pendingEdits.isEmpty, "an unsaved mark removed again leaves nothing to save")
        #expect(document.pdfView.document?.page(at: 0)?.annotations.isEmpty == true)
        #expect(tools.selectedID == nil)
    }
}

@Suite struct PDFUndo {
    private func signature(_ id: String = PDFEdit.newID()) -> PDFEdit {
        .add(PDFMark(id: id, page: 0, rect: place, kind: .signature(strokes: [[.zero, CGPoint(x: 1, y: 1)]])))
    }

    @Test func undoAfterSavingIsANewEdit() async throws {
        let document = try await open(try TempFile.makePDF(pages: 1))
        #expect(document.change(signature()))
        try await document.save(try #require(document.unsavedEdits()), accepting: nil)
        #expect(document.unsavedEdits() == nil)
        var edits = 0
        document.onEdit = { edits += 1 }
        document.undoManager.undo()
        #expect(edits == 1)
        #expect(document.pdfView.document?.page(at: 0)?.annotations.isEmpty == true)
        guard case .delete = document.pendingEdits.first else { Issue.record("\(document.pendingEdits)"); return }
    }

    @Test func redoReappliesTheChange() async throws {
        let document = try await open(try TempFile.makePDF(pages: 1))
        let id = PDFEdit.newID()
        #expect(document.change(signature(id)))
        document.undoManager.undo()
        #expect(document.pendingEdits.isEmpty)
        document.undoManager.redo()
        #expect(document.pdfView.document?.page(at: 0)?.annotations.count == 1)
        #expect(document.pendingEdits.count == 1 && document.pendingEdits[0].markID == id)
    }

    @Test func undoOfAMoveMovesItBack() async throws {
        let document = try await open(try TempFile.makePDF(pages: 1))
        let window = inWindow(document)
        #expect(document.change(signature()))
        try drag(in: document, window: window, from: CGPoint(x: place.midX, y: place.midY), to: CGPoint(x: place.midX + 40, y: place.midY))
        #expect(document.pdfView.document?.page(at: 0)?.annotations.first?.bounds == place.offsetBy(dx: 40, dy: 0))
        document.undoManager.undo()
        #expect(document.pdfView.document?.page(at: 0)?.annotations.first?.bounds == place)
    }

    /// The window outlives the document (Open With, reload), so its undo manager must never hold the document's steps.
    @Test func theHistoryIsTheDocumentsNotTheWindows() async throws {
        let document = try await open(try TempFile.makePDF(pages: 1))
        let window = inWindow(document)
        #expect(document.change(signature()))
        #expect(window.undoManager?.canUndo != true)
        #expect(document.pdfView.undoManager === document.undoManager)
    }

    @Test func undoIsOutOfReachInTheReadView() async throws {
        let document = try await open(try TempFile.makePDF(pages: 1))
        inWindow(document)
        #expect(document.change(signature()))
        document.setEditing(false)
        #expect(document.pdfView.undoManager !== document.undoManager)
    }

    @Test func dontSaveClearsTheHistory() async throws {
        let document = try await open(try TempFile.makePDF(pages: 1))
        #expect(document.change(signature()))
        document.revertEdits()
        #expect(!document.undoManager.canUndo)
    }
}

@Suite struct PDFTextBoxes {
    @Test func aCommittedTextBoxIsBlackHelveticaOnClear() async throws {
        let document = try await open(try TempFile.makePDF(pages: 1))
        let tools = try #require(document.tools)
        tools.commitTextBox(id: nil, page: 0, topLeft: CGPoint(x: 100, y: 500), text: "31 October", fontSize: 14)
        let annotation = try #require(document.pdfView.document?.page(at: 0)?.annotations.first)
        #expect(annotation.type == "FreeText" && annotation.contents == "31 October")
        #expect(annotation.font?.fontName == "Helvetica" && annotation.font?.pointSize == 14)
        #expect(annotation.fontColor?.usingColorSpace(.sRGB)?.brightnessComponent == 0)
        #expect(annotation.color.alphaComponent == 0)
        #expect(annotation.border?.lineWidth == 0)
        #expect(PDFMarks.id(of: annotation) != nil)
    }

    @Test func theBoxFitsItsText() {
        let short = TextBoxEditor.fittedRect(text: "Hi", fontSize: 12, topLeft: CGPoint(x: 100, y: 500))
        let long = TextBoxEditor.fittedRect(text: "A much longer line of text", fontSize: 12, topLeft: CGPoint(x: 100, y: 500))
        let twoLines = TextBoxEditor.fittedRect(text: "Hi\nthere", fontSize: 12, topLeft: CGPoint(x: 100, y: 500))
        #expect(short.minX == 100 && short.maxY == 500, "it grows right and down from where you clicked")
        #expect(long.width > short.width * 3)
        #expect(twoLines.height > short.height * 1.5)
        #expect(TextBoxEditor.fittedRect(text: "Hi", fontSize: 24, topLeft: .zero).height > short.height * 1.5)
    }

    @Test func editingABoxsTextIsOneChange() async throws {
        let document = try await open(try TempFile.makePDF(pages: 1))
        let tools = try #require(document.tools)
        tools.commitTextBox(id: nil, page: 0, topLeft: CGPoint(x: 100, y: 500), text: "a", fontSize: 12)
        let id = try #require(document.pendingEdits.first?.markID)
        tools.commitTextBox(id: id, page: 0, topLeft: CGPoint(x: 100, y: 500), text: "abc", fontSize: 20)
        guard document.pendingEdits.count == 1, case .add(let mark) = document.pendingEdits[0] else { Issue.record("\(document.pendingEdits)"); return }
        #expect(mark.kind == .textBox(text: "abc", fontSize: 20))
    }

    /// Saving or leaving Edit mode takes focus from the box, which must count as finishing it.
    @Test func losingFocusEndsTheBox() async throws {
        let document = try await open(try TempFile.makePDF(pages: 1))
        let window = offscreenWindow(holding: document.pdfView, width: 600, height: 800)
        let page = try #require(document.pdfView.document?.page(at: 0))
        var ended: (String, Double)?
        let editor = TextBoxEditor(view: document.pdfView, page: page, topLeft: CGPoint(x: 100, y: 500), text: "", fontSize: 12, hiding: nil) { ended = ($0, $1) }
        let textView = try #require(window.firstResponder as? NSTextView)
        textView.string = "Typed"
        window.makeFirstResponder(nil)
        #expect(ended?.0 == "Typed" && ended?.1 == 12)
        withExtendedLifetime(editor) {}
    }

    @Test func typingInABoxKeepsItsOwnUndo() async throws {
        let document = try await open(try TempFile.makePDF(pages: 1))
        let window = inWindow(document)
        let page = try #require(document.pdfView.document?.page(at: 0))
        let editor = TextBoxEditor(view: document.pdfView, page: page, topLeft: CGPoint(x: 100, y: 500), text: "", fontSize: 12, hiding: nil) { _, _ in }
        let textView = try #require(window.firstResponder as? NSTextView)
        #expect(textView.undoManager != nil && textView.undoManager !== document.undoManager)
        editor.end()
    }

    @Test func anEmptyBoxIsRemoved() async throws {
        let document = try await open(try TempFile.makePDF(pages: 1))
        let tools = try #require(document.tools)
        tools.commitTextBox(id: nil, page: 0, topLeft: CGPoint(x: 100, y: 500), text: "   ", fontSize: 12)
        #expect(document.pendingEdits.isEmpty)
        tools.commitTextBox(id: nil, page: 0, topLeft: CGPoint(x: 100, y: 500), text: "a", fontSize: 12)
        let id = try #require(document.pendingEdits.first?.markID)
        tools.commitTextBox(id: id, page: 0, topLeft: CGPoint(x: 100, y: 500), text: "", fontSize: 12)
        #expect(document.pendingEdits.isEmpty)
        #expect(document.pdfView.document?.page(at: 0)?.annotations.isEmpty == true)
    }
}

@Suite(.serialized) struct PDFSignatures {
    @Test func strokesAreNormalizedToTheirBounds() throws {
        let signature = try #require(Signature(strokes: [[CGPoint(x: 10, y: 20), CGPoint(x: 210, y: 70)], [CGPoint(x: 110, y: 45)]]))
        #expect(signature.strokes == [[CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)], [CGPoint(x: 0.5, y: 0.5)]])
        #expect(signature.aspect == 0.25)
    }

    @Test func anEmptyDrawingIsNoSignature() {
        #expect(Signature(strokes: []) == nil)
        #expect(Signature(strokes: [[]]) == nil)
    }

    @Test func aPlacedSignatureIs180PointsWideAndKeepsItsShape() throws {
        let signature = try #require(Signature(strokes: [[CGPoint(x: 0, y: 0), CGPoint(x: 200, y: 50)]]))
        let mark = EditController.signatureMark(signature, page: 0, centeredAt: CGPoint(x: 300, y: 200))
        #expect(mark.rect == CGRect(x: 210, y: 177.5, width: 180, height: 45))
        #expect(mark.kind == .signature(strokes: signature.strokes))
        let annotation = PDFMarks.annotation(for: mark)
        #expect(annotation.type == "Ink" && annotation.border?.lineWidth == 1.5)
        #expect(annotation.color.usingColorSpace(.sRGB)?.brightnessComponent == 0)
        #expect(abs((annotation.paths?.first?.bounds.width ?? 0) - 180) < 0.5)
    }

    @Test func placingASignatureIsAnEditAndEndsTheTool() async throws {
        let document = try await open(try TempFile.makePDF(pages: 2))
        let tools = try #require(document.tools)
        let signature = try #require(Signature(strokes: [[CGPoint(x: 0, y: 0), CGPoint(x: 200, y: 50)]]))
        tools.startPlacing(signature)
        #expect(tools.place(at: CGPoint(x: 300, y: 200), page: 1))
        #expect(document.pdfView.document?.page(at: 1)?.annotations.first?.type == "Ink")
        #expect(!tools.place(at: CGPoint(x: 300, y: 200), page: 1), "one click places one signature")
    }

    /// The signature lives only in memory; nothing about it reaches the disk.
    @Test func theLastSignatureIsKeptInMemoryOnly() throws {
        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        func listing() -> [String] { (FileManager.default.subpaths(atPath: support.appending(path: "Peeker").path) ?? []).sorted() }
        let before = listing(), defaults = Set(UserDefaults.standard.dictionaryRepresentation().keys)
        let signature = try #require(Signature(strokes: [[CGPoint(x: 0, y: 0), CGPoint(x: 200, y: 50)]]))
        SignatureMemory.last = nil
        SignaturePad.finish(with: signature)
        #expect(SignatureMemory.last == signature)
        #expect(listing() == before)
        #expect(Set(UserDefaults.standard.dictionaryRepresentation().keys) == defaults)
    }
}
