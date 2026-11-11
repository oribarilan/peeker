import PDFKit
import PeekerKit
@testable import PeekerPDF
import Testing

private let stroke = [CGPoint(x: 0, y: 0), CGPoint(x: 0.5, y: 1), CGPoint(x: 1, y: 0)]

private func signature() -> PDFMark {
    PDFMark(id: PDFEdit.newID(), page: 0, rect: CGRect(x: 100, y: 300, width: 180, height: 60), kind: .signature(strokes: [stroke]))
}

/// The edits a crash-recovery record would hold now.
private func recorded(_ document: PDFPluginDocument) throws -> [PDFEdit] {
    try JSONDecoder().decode([PDFEdit].self, from: try #require(document.unsavedEdits()).encoded())
}

/// A signature goes only into the PDF it's placed in, so the crash-recovery copy of the unsaved edits leaves out one
/// placed since the last save.
@Suite(.serialized) struct PDFSignatureRecovery {
    @Test func theRecoveryCopyLeavesOutAnUnsavedSignatureButSavingWritesIt() async throws {
        let file = try TempFile.makePDF(pages: 1)
        let document = try await openDocument(file, with: PDFPlugin.self, as: PDFPluginDocument.self)
        _ = document.prepareEditing()
        let box = PDFMark(
            id: PDFEdit.newID(), page: 0, rect: CGRect(x: 100, y: 500, width: 80, height: 20), kind: .textBox(text: "Seen", fontSize: 14))
        let placed = signature()
        #expect(document.change(.add(placed)) && document.change(.add(box)))
        #expect(document.change(.setBounds(id: placed.id, type: .signature, page: 0, rect: placed.rect.offsetBy(dx: 20, dy: 0))))
        #expect(try recorded(document) == [.add(box)])
        try await document.save(try #require(document.unsavedEdits()), accepting: nil)
        let saved = try #require(PDFDocument(url: file)?.page(at: 0)?.annotations)
        #expect(saved.contains { PDFMarks.id(of: $0) == placed.id }, "the PDF itself gets the signature")
    }

    @Test func aMoveOfASavedSignatureIsStillRecovered() async throws {
        let file = try TempFile.makePDF(pages: 1)
        let placed = signature()
        try await PDFPlugin.write([.add(placed)], to: file.path)
        let document = try await openDocument(file, with: PDFPlugin.self, as: PDFPluginDocument.self)
        _ = document.prepareEditing()
        let moved = PDFEdit.setBounds(id: placed.id, type: .signature, page: 0, rect: placed.rect.offsetBy(dx: 0, dy: 40))
        #expect(document.change(moved))
        #expect(try recorded(document) == [moved], "a move carries no strokes")
    }

    /// Found in review: the record of a signature alone was empty, refused on relaunch and never removed.
    @Test func aRecordOfOnlyASignatureIsTakenAsNothingToRestore() async throws {
        let document = try await openDocument(try TempFile.makePDF(pages: 1), with: PDFPlugin.self, as: PDFPluginDocument.self)
        _ = document.prepareEditing()
        #expect(document.change(.add(signature())))
        let record = try #require(document.unsavedEdits()).encoded()
        let relaunched = try await openDocument(try TempFile.makePDF(pages: 1), with: PDFPlugin.self, as: PDFPluginDocument.self)
        #expect(relaunched.restore(encoded: record), "accepted, so the host removes the record")
        #expect(relaunched.unsavedEdits() == nil)
    }

    @Test func otherEditsComeBackAfterACrashWithoutTheSignature() async throws {
        let file = try TempFile.makePDF(pages: 1)
        let document = try await openDocument(file, with: PDFPlugin.self, as: PDFPluginDocument.self)
        _ = document.prepareEditing()
        let box = PDFMark(
            id: PDFEdit.newID(), page: 0, rect: CGRect(x: 100, y: 500, width: 80, height: 20), kind: .textBox(text: "Seen", fontSize: 14))
        #expect(document.change(.add(signature())) && document.change(.add(box)))
        let record = try #require(document.unsavedEdits()).encoded()
        let relaunched = try await openDocument(file, with: PDFPlugin.self, as: PDFPluginDocument.self)
        #expect(relaunched.restore(encoded: record))
        #expect(relaunched.pendingEdits == [.add(box)])
    }

    /// Found in review: delete a saved signature, undo and move it folds to a removal and an add, which both went.
    @Test func aSavedSignatureRemovedPutBackAndMovedIsRecoveredAsAMove() async throws {
        let file = try TempFile.makePDF(pages: 1)
        let placed = signature()
        try await PDFPlugin.write([.add(placed)], to: file.path)
        let document = try await openDocument(file, with: PDFPlugin.self, as: PDFPluginDocument.self)
        document.undoManager.groupsByEvent = false
        _ = document.prepareEditing()
        #expect(document.change(.delete(id: placed.id, type: .signature, page: 0)))
        document.undoManager.undo()
        let moved = placed.rect.offsetBy(dx: 0, dy: 40)
        #expect(document.change(.setBounds(id: placed.id, type: .signature, page: 0, rect: moved)))
        #expect(try recorded(document) == [.setBounds(id: placed.id, type: .signature, page: 0, rect: moved)])
    }

    /// Found in review: after a saved deletion the restore's copy is the only one, and it held the strokes.
    @Test func aSavedDeletionPutBackKeepsNoCopyOfTheSignature() async throws {
        let file = try TempFile.makePDF(pages: 2)
        let placed = signature()
        let box = PDFMark(
            id: PDFEdit.newID(), page: 0, rect: CGRect(x: 100, y: 500, width: 80, height: 20), kind: .textBox(text: "Seen", fontSize: 14))
        try await PDFPlugin.write([.add(placed), .add(box)], to: file.path)
        let document = try await openDocument(file, with: PDFPlugin.self, as: PDFPluginDocument.self)
        document.undoManager.groupsByEvent = false
        _ = document.prepareEditing()
        #expect(document.change(.deletePages(pages: [0], token: "t")))
        try await document.save(try #require(document.unsavedEdits()), accepting: nil)
        document.undoManager.undo()
        let copies = try recorded(document).compactMap { if case .restorePages(_, _, let data) = $0 { PDFDocument(data: data) } else { nil } }
        let ids = copies.first?.page(at: 0)?.annotations.compactMap(PDFMarks.id(of:))
        #expect(ids == [box.id], "the signature is gone and the text box keeps its name")
        let relaunched = try await openDocument(file, with: PDFPlugin.self, as: PDFPluginDocument.self)
        #expect(relaunched.restore(encoded: try #require(document.unsavedEdits()).encoded()))
        #expect(relaunched.pdfView.document?.pageCount == 2)
        #expect(relaunched.pdfView.document?.page(at: 0)?.annotations.compactMap(PDFMarks.id(of:)) == [box.id])
    }

    @Test func aDeletedPagePutBackKeepsNoCopyOfAnUnsavedSignature() async throws {
        let document = try await openDocument(try TempFile.makePDF(pages: 2), with: PDFPlugin.self, as: PDFPluginDocument.self)
        document.undoManager.groupsByEvent = false
        _ = document.prepareEditing()
        let placed = signature()
        #expect(document.change(.add(placed)))
        #expect(document.change(.deletePages(pages: [0], token: "t")))
        document.undoManager.undo()
        let edits = try recorded(document)
        #expect(!edits.contains(.add(placed)))
        let restores = edits.compactMap { if case .restorePages(_, _, let data) = $0 { data } else { nil } }
        #expect(restores == [Data()], "the deletion is in the record too, so replaying it keeps the pages, and no copy is needed")
        let relaunched = try await openDocument(try TempFile.makePDF(pages: 2), with: PDFPlugin.self, as: PDFPluginDocument.self)
        #expect(relaunched.restore(encoded: try #require(document.unsavedEdits()).encoded()))
        #expect(relaunched.pdfView.document?.pageCount == 2)
        let replayed = relaunched.pendingEdits.compactMap { if case .restorePages(_, _, let data) = $0 { data } else { nil } }
        #expect(replayed.count == 1 && replayed.allSatisfy { !$0.isEmpty }, "the replay makes its copy again from the deleted pages")
    }
}
