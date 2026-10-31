import Foundation
import PDFKit
import PeekerKit
@testable import PeekerPDF
import Testing

/// Each page's text, such as ["Page 1", "Page 2"].
private func texts(_ document: PDFDocument) -> [String] {
    (0..<document.pageCount).map { document.page(at: $0)?.string ?? "" }
}

private func pdf(_ pages: Int) throws -> PDFDocument {
    try #require(PDFDocument(url: try TempFile.makePDF(pages: pages)))
}

private func apply(_ edit: PDFEdit, to document: PDFDocument, stash: PageStash = PageStash()) throws(PluginError) {
    try PDFMarks.apply(edit, to: document, fileName: "f.pdf", stash: stash)
}

@Suite struct PDFPageEdits {
    @Test func rotationTurnsPagesAndWrapsAround() throws {
        let document = try pdf(3)
        try apply(.rotatePages(pages: [0, 2], by: 90), to: document)
        #expect((0..<3).map { document.page(at: $0)!.rotation } == [90, 0, 90])
        try apply(.rotatePages(pages: [0], by: -90), to: document)
        try apply(.rotatePages(pages: [1], by: -90), to: document)
        #expect((0..<3).map { document.page(at: $0)!.rotation } == [0, 270, 90])
        #expect(throws: PluginError.self) { try apply(.rotatePages(pages: [0], by: 45), to: document) }
        #expect(throws: PluginError.self) { try apply(.rotatePages(pages: [3], by: 90), to: document) }
    }

    @Test func reorderMovesTheSamePageObjects() throws {
        let document = try pdf(4)
        let last = document.page(at: 3)
        try apply(.reorderPages(order: [3, 0, 1, 2]), to: document)
        #expect(texts(document) == ["Page 4", "Page 1", "Page 2", "Page 3"])
        #expect(document.page(at: 0) === last)
        #expect(throws: PluginError.self) { try apply(.reorderPages(order: [0, 0, 1, 2]), to: document) }
        #expect(throws: PluginError.self) { try apply(.reorderPages(order: [0, 1, 2]), to: document) }
        #expect(texts(document) == ["Page 4", "Page 1", "Page 2", "Page 3"], "a refused reorder changes nothing")
    }

    @Test func deleteRemovesPagesButNeverTheLast() throws {
        let document = try pdf(3)
        try apply(.deletePages(pages: [2, 0], token: "t"), to: document)
        #expect(texts(document) == ["Page 2"])
        #expect(throws: PluginError.self) { try apply(.deletePages(pages: [0], token: "u"), to: document) }
        #expect(throws: PluginError.self) { try apply(.deletePages(pages: [], token: "u"), to: try pdf(2)) }
        #expect(throws: PluginError.self) { try apply(.deletePages(pages: [1, 1], token: "u"), to: try pdf(3)) }
    }

    @Test func restorePutsBackTheStashedPages() throws {
        let document = try pdf(3)
        let first = document.page(at: 0)
        let stash = PageStash()
        try apply(.deletePages(pages: [0, 2], token: "t"), to: document, stash: stash)
        try apply(.restorePages(pages: [0, 2], token: "t", data: Data()), to: document, stash: stash)
        #expect(texts(document) == ["Page 1", "Page 2", "Page 3"])
        #expect(document.page(at: 0) === first)
    }

    @Test func aStashedPageComesBackOnlyOnce() throws {
        let document = try pdf(3)
        let stash = PageStash()
        try apply(.deletePages(pages: [1], token: "t"), to: document, stash: stash)
        try apply(.restorePages(pages: [1], token: "t", data: Data()), to: document, stash: stash)
        #expect(throws: PluginError.self) { try apply(.restorePages(pages: [1], token: "t", data: Data()), to: document, stash: stash) }
        #expect(document.pageCount == 3)
    }

    /// An annotation with no name still takes its own place when names are matched back after a page moved.
    @Test func repairDoesNotGiveANameToAnotherAppsTwin() throws {
        let document = try pdf(2)
        let bounds = CGRect(x: 72, y: 600, width: 100, height: 20)
        let theirs = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
        let ours = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
        ours.setValue("peeker-ours", forAnnotationKey: .name)
        document.page(at: 1)!.addAnnotation(theirs)
        document.page(at: 1)!.addAnnotation(ours)
        let data = try #require(document.dataRepresentation())
        let saved = try #require(PDFDocument(data: data))
        saved.removePage(at: 0)
        let kept = MovedPageRepair.kept(in: saved)
        let written = try #require(saved.dataRepresentation())
        let repaired = try #require(MovedPageRepair.repaired(written, kept: kept))
        let page = try #require(PDFDocument(data: repaired)?.page(at: 0))
        let names = page.annotations.map { $0.value(forAnnotationKey: .name) as? String }
        #expect(names == [nil, "peeker-ours"])
    }

    @Test func restoreFallsBackToTheCopyAndChecksIt() throws {
        let copy = try pdf(1)
        let data = try #require(copy.dataRepresentation())
        let document = try pdf(2)
        try apply(.restorePages(pages: [1], token: "gone", data: data), to: document)
        #expect(texts(document) == ["Page 1", "Page 1", "Page 2"])
        #expect(throws: PluginError.self) { try apply(.restorePages(pages: [0, 1], token: "gone", data: data), to: try pdf(2)) }
        #expect(throws: PluginError.self) { try apply(.restorePages(pages: [0], token: "gone", data: Data("not a pdf".utf8)), to: try pdf(2)) }
        #expect(throws: PluginError.self) { try apply(.restorePages(pages: [5], token: "gone", data: data), to: try pdf(2)) }
    }

    @Test func pageEditsRoundTripAndStayInPlaceWhenFolded() throws {
        let mark = PDFMark(id: "peeker-a", page: 0, rect: CGRect(x: 1, y: 2, width: 3, height: 4), kind: .highlight(RGBA(red: 1, green: 0, blue: 0, alpha: 1)))
        let edits: [PDFEdit] = [
            .add(mark), .rotatePages(pages: [0], by: 90), .reorderPages(order: [1, 0]),
            .deletePages(pages: [1], token: "t"), .restorePages(pages: [1], token: "t", data: Data([1, 2])),
            .setBounds(id: "peeker-a", type: .highlight, page: 1, rect: CGRect(x: 5, y: 6, width: 7, height: 8)),
        ]
        let decoded = try JSONDecoder().decode(PDFEdits.self, from: JSONEncoder().encode(PDFEdits.operations(edits)))
        #expect(decoded == .operations(edits))
        var moved = mark
        moved.rect = CGRect(x: 5, y: 6, width: 7, height: 8)
        #expect(PDFEdit.folded(edits) == [.add(moved)] + edits[1...4])
    }
}

@Suite(.serialized) struct PDFPageDocument {
    private func open(_ file: URL) async throws -> PDFPluginDocument {
        let document = try #require(try await PDFPlugin.open(file, context: OpenContext(maxPixels: 0, allowsEditing: true)) as? PDFPluginDocument)
        document.undoManager.groupsByEvent = false
        document.setEditing(true)
        return document
    }

    private func shown(_ document: PDFPluginDocument) -> [String] { texts(document.pdfView.document!) }

    private func save(_ document: PDFPluginDocument) async throws {
        try await document.save(try #require(document.unsavedEdits()), accepting: nil)
    }

    @Test func pageEditsArePendingAndUndoable() async throws {
        let document = try await open(try TempFile.makePDF(pages: 3))
        #expect(document.change(.rotatePages(pages: [1], by: 90)))
        #expect(document.change(.reorderPages(order: [2, 0, 1])))
        #expect(document.change(.deletePages(pages: [0], token: "t")))
        #expect(shown(document) == ["Page 1", "Page 2"])
        #expect(document.pendingEdits.count == 3 && document.unsavedEdits() != nil)
        document.undoManager.undo()
        #expect(shown(document) == ["Page 3", "Page 1", "Page 2"])
        document.undoManager.undo()
        #expect(shown(document) == ["Page 1", "Page 2", "Page 3"])
        document.undoManager.undo()
        #expect(document.pdfView.document?.page(at: 1)?.rotation == 0)
        document.undoManager.redo()
        document.undoManager.redo()
        #expect(shown(document) == ["Page 3", "Page 1", "Page 2"])
        #expect(document.pdfView.document?.page(at: 2)?.rotation == 90)
    }

    @Test func aMarkMovesWithItsPageAndSavesThere() async throws {
        let file = try TempFile.makePDF(pages: 3)
        let document = try await open(file)
        let mark = PDFMark(id: PDFEdit.newID(), page: 2, rect: CGRect(x: 72, y: 400, width: 120, height: 30), kind: .textBox(text: "Moved", fontSize: 12))
        #expect(document.change(.add(mark)))
        #expect(document.change(.reorderPages(order: [2, 0, 1])))
        #expect(document.change(.rotatePages(pages: [0], by: 90)))
        try await save(document)
        let saved = try #require(PDFDocument(url: file))
        #expect(texts(saved) == ["Page 3", "Page 1", "Page 2"])
        #expect(saved.page(at: 0)?.rotation == 90)
        #expect(saved.page(at: 0)?.annotations.contains { PDFMarks.id(of: $0) == mark.id } == true)
    }

    /// PDFKit drops `/NM` and `/DS` from annotations on pages that moved; the save puts them back.
    @Test func savedMarksOnShiftedPagesKeepTheirNameAndSize() async throws {
        let file = try TempFile.makePDF(pages: 3)
        let first = try await open(file)
        let mark = PDFMark(id: PDFEdit.newID(), page: 2, rect: CGRect(x: 72, y: 400, width: 120, height: 30), kind: .textBox(text: "Big", fontSize: 24))
        #expect(first.change(.add(mark)))
        try await save(first)
        let second = try await open(file)
        #expect(second.change(.deletePages(pages: [0], token: "t")))
        try await save(second)
        let saved = try #require(PDFDocument(url: file))
        let annotation = try #require(saved.page(at: 1).flatMap { PDFMarks.find(mark.id, on: $0) })
        #expect(PDFMarks.fontSize(of: annotation) == 24)
    }

    @Test func undoBringsBackAPageDeletedAndSaved() async throws {
        let file = try TempFile.makePDF(pages: 3)
        let document = try await open(file)
        #expect(document.change(.deletePages(pages: [1], token: "t")))
        try await save(document)
        #expect(texts(try #require(PDFDocument(url: file))) == ["Page 1", "Page 3"])
        document.undoManager.undo()
        #expect(shown(document) == ["Page 1", "Page 2", "Page 3"])
        try await save(document)
        #expect(texts(try #require(PDFDocument(url: file))) == ["Page 1", "Page 2", "Page 3"])
    }

    /// The copy kept for undoing a saved deletion keeps the names of Peeker's marks, so they can still be changed.
    @Test func aMarkOnARestoredPageKeepsItsName() async throws {
        let file = try TempFile.makePDF(pages: 3)
        let first = try await open(file)
        let mark = PDFMark(id: PDFEdit.newID(), page: 1, rect: CGRect(x: 72, y: 400, width: 120, height: 30), kind: .textBox(text: "Keep", fontSize: 20))
        #expect(first.change(.add(mark)))
        try await save(first)
        let second = try await open(file)
        #expect(second.change(.deletePages(pages: [1], token: "t")))
        try await save(second)
        second.undoManager.undo()
        #expect(second.change(.setBounds(id: mark.id, type: .textBox, page: 1, rect: CGRect(x: 100, y: 300, width: 120, height: 30))))
        try await save(second)
        let saved = try #require(PDFDocument(url: file))
        let annotation = try #require(saved.page(at: 1).flatMap { PDFMarks.find(mark.id, on: $0) })
        #expect(annotation.bounds.origin == CGPoint(x: 100, y: 300))
        #expect(PDFMarks.fontSize(of: annotation) == 20)
    }

    @Test func recoveryStopsAfterASkippedPageMove() async throws {
        let document = try await open(try TempFile.makePDF(pages: 3))
        let record = try JSONEncoder().encode(PDFEdits.operations([.reorderPages(order: [1, 0]), .deletePages(pages: [0], token: "t")]))
        #expect(!document.restore(encoded: record))
        #expect(shown(document) == ["Page 1", "Page 2", "Page 3"])
    }

    @Test func recoveryReappliesPageEdits() async throws {
        let file = try TempFile.makePDF(pages: 3)
        let first = try await open(file)
        #expect(first.change(.rotatePages(pages: [0], by: -90)))
        #expect(first.change(.reorderPages(order: [1, 2, 0])))
        #expect(first.change(.deletePages(pages: [0], token: "t")))
        let record = try #require(first.unsavedEdits()).encoded()
        let second = try await open(file)
        #expect(second.restore(encoded: record))
        #expect(shown(second) == ["Page 3", "Page 1"])
        #expect(second.pdfView.document?.page(at: 1)?.rotation == 270)
    }

    @Test func anOpenSearchRunsAgainAfterAPageChange() async throws {
        let document = try await open(try TempFile.makePDF(pages: 3))
        let finder = try #require(document.contentView as? PDFFindContainer).finder
        finder.search("Page")
        try await waitUntil(seconds: 5) { !finder.isSearching }
        #expect(finder.matches.count == 3)
        #expect(document.change(.deletePages(pages: [2], token: "t")))
        try await waitUntil(seconds: 5) { !finder.isSearching && finder.matches.count == 2 }
    }
}
