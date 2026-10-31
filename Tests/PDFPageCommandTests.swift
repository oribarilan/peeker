import AppKit
import PDFKit
import PeekerKit
@testable import PeekerPDF
import Testing

private func texts(_ document: PDFDocument) -> [String] {
    (0..<document.pageCount).map { document.page(at: $0)?.string ?? "" }
}

/// A document in a window with its thumbnails beside the pages, as the host shows it.
@MainActor private final class Shown {
    let document: PDFPluginDocument
    let window: NSWindow
    let thumbnails: PageThumbnails

    init(_ file: URL, editing: Bool = true) async throws {
        document = try #require(try await PDFPlugin.open(file, context: OpenContext(maxPixels: 0, allowsEditing: true)) as? PDFPluginDocument)
        document.undoManager.groupsByEvent = false
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 900), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        thumbnails = try #require(document.sidebar.first?.view as? PageThumbnails)
        thumbnails.frame = NSRect(x: 0, y: 0, width: 150, height: 900)
        document.contentView.frame = NSRect(x: 150, y: 0, width: 750, height: 900)
        window.contentView!.addSubview(thumbnails)
        window.contentView!.addSubview(document.contentView)
        thumbnails.layoutSubtreeIfNeeded()
        if editing { document.setEditing(true) }
    }

    /// Selects thumbnails through the collection view inside PDFKit's thumbnail view (tests only: there's no public setter).
    func select(_ pages: [Int]) throws {
        func find(_ view: NSView) -> NSCollectionView? {
            (view as? NSCollectionView) ?? view.subviews.lazy.compactMap(find).first
        }
        let collection = try #require(find(thumbnails))
        collection.selectionIndexPaths = Set(pages.map { IndexPath(item: $0, section: 0) })
    }

    var shown: [String] { texts(document.pdfView.document!) }
    func rotation(_ page: Int) -> Int { document.pdfView.document!.page(at: page)!.rotation }
}

@Suite(.serialized) struct PDFPageCommands {
    @Test func theCommandsAreEditToolsWithTheirShortcuts() {
        let byID = Dictionary(uniqueKeysWithValues: PDFPlugin.commands.map { ($0.id, $0) })
        #expect(byID["rotate-left"]?.shortcut == "cmd+l" && byID["rotate-left"]?.isEditTool == true)
        #expect(byID["rotate-right"]?.shortcut == "cmd+r" && byID["rotate-right"]?.isEditTool == true)
        #expect(byID["delete-page"]?.isEditTool == true)
    }

    @Test func rotateActsOnTheSelectionOrTheCurrentPage() async throws {
        let shown = try await Shown(try TempFile.makePDF(pages: 4))
        defer { shown.window.close() }
        try shown.select([1, 2])
        #expect(shown.thumbnails.selectedPages?.count == 2)
        #expect(shown.document.perform("rotate-right"))
        #expect((0..<4).map(shown.rotation) == [0, 90, 90, 0])
        try shown.select([])
        shown.document.pdfView.go(to: shown.document.pdfView.document!.page(at: 3)!)
        #expect(shown.document.perform("rotate-left"))
        #expect(shown.rotation(3) == 270)
        shown.document.undoManager.undo()
        #expect(shown.rotation(3) == 0)
    }

    /// A search left from earlier runs again after a page change without moving the view.
    @Test func aSearchRunningAgainDoesNotMoveTheCurrentPage() async throws {
        let shown = try await Shown(try TempFile.makePDF(pages: 5))
        defer { shown.window.close() }
        let finder = try #require(shown.document.contentView as? PDFFindContainer).finder
        finder.search("Page 1")
        try await waitUntil(seconds: 5) { !finder.isSearching }
        try shown.select([])
        shown.document.pdfView.go(to: shown.document.pdfView.document!.page(at: 4)!)
        #expect(shown.document.perform("rotate-right"))
        try await waitUntil(seconds: 5) { !finder.isSearching }
        #expect(shown.document.perform("rotate-right"))
        #expect(shown.rotation(4) == 180 && shown.rotation(0) == 0)
    }

    /// Typing in a text box ends before a page command, so undoing it after a save brings back the box too.
    @Test func aTextBoxBeingTypedIsKeptWithItsDeletedPage() async throws {
        let file = try TempFile.makePDF(pages: 2)
        let shown = try await Shown(file)
        defer { shown.window.close() }
        let page = try #require(shown.document.pdfView.document?.page(at: 0))
        shown.document.pdfView.go(to: page)
        try #require(shown.document.tools).commitTextBox(id: nil, page: 0, topLeft: CGPoint(x: 72, y: 700), text: "Typed", fontSize: 12)
        try shown.select([0])
        #expect(shown.document.perform("delete-page"))
        try await shown.document.save(try #require(shown.document.unsavedEdits()), accepting: nil)
        shown.document.undoManager.undo()
        try await shown.document.save(try #require(shown.document.unsavedEdits()), accepting: nil)
        #expect(texts(try #require(PDFDocument(url: file))).count == 2)
    }

    @Test func deleteRemovesTheSelectionButNotEveryPage() async throws {
        let shown = try await Shown(try TempFile.makePDF(pages: 3))
        defer { shown.window.close() }
        try shown.select([0, 1, 2])
        #expect(shown.document.unavailableReason(for: "delete-page") == "A PDF needs at least one page.")
        #expect(!shown.document.perform("delete-page"))
        try shown.select([0, 2])
        #expect(shown.document.unavailableReason(for: "delete-page") == nil)
        #expect(shown.document.perform("delete-page"))
        #expect(shown.shown == ["Page 2"])
    }

    @Test func aPDFThatForbidsPageChangesStillEditsButGreysOutPageCommands() async throws {
        let source = try #require(PDFDocument(url: try TempFile.makePDF(pages: 2)))
        let file = try TempFile.make(Data(), name: "restricted.pdf")
        let commentingAndForms: UInt = 1 << 6 | 1 << 7  // PDFAllowsCommenting, PDFAllowsFormFieldEntry; not assembly
        #expect(source.write(to: file, withOptions: [.ownerPasswordOption: "owner", .accessPermissionsOption: NSNumber(value: commentingAndForms)]))
        let shown = try await Shown(file)
        defer { shown.window.close() }
        #expect(shown.document.editMode == .available && shown.document.isEditing)
        let reason = "This PDF's permissions don't allow page changes."
        for id in ["rotate-left", "rotate-right", "delete-page"] { #expect(shown.document.unavailableReason(for: id) == reason) }
        #expect(!shown.document.perform("rotate-left"))
        #expect(!shown.thumbnails.allowsDragging)
    }

    @Test func thumbnailsDragAndDeleteOnlyInEditMode() async throws {
        let shown = try await Shown(try TempFile.makePDF(pages: 3), editing: false)
        defer { shown.window.close() }
        #expect(shown.thumbnails.allowsMultipleSelection)
        #expect(!shown.thumbnails.allowsDragging && shown.thumbnails.menu == nil)
        try shown.select([1])
        shown.thumbnails.deleteBackward(nil)
        #expect(shown.shown == ["Page 1", "Page 2", "Page 3"])
        shown.document.setEditing(true)
        #expect(shown.thumbnails.allowsDragging && shown.thumbnails.menu != nil)
        #expect(shown.thumbnails.menu?.items.map(\.title) == ["Rotate Left", "Rotate Right", "Delete Page"])
        try shown.select([1])
        shown.thumbnails.deleteBackward(nil)
        #expect(shown.shown == ["Page 1", "Page 3"])
    }
}

@Suite(.serialized) struct PDFThumbnailDrags {
    /// What PDFKit's thumbnail view does on a drop: insert a copy of the dragged page where it's dropped, then remove
    /// the original (seen in a probe on macOS 27).
    private func drag(_ page: Int, to index: Int, in document: PDFDocument) {
        let original = document.page(at: page)!
        document.insert(original.copy() as! PDFPage, at: index)
        document.removePage(at: document.index(for: original))
    }

    @Test func aDragBecomesOneUndoableReorderOfTheOriginalPages() async throws {
        let shown = try await Shown(try TempFile.makePDF(pages: 4))
        defer { shown.window.close() }
        let live = try #require(shown.document.pdfView.document)
        let last = live.page(at: 3)
        drag(3, to: 0, in: live)
        try await waitUntil(seconds: 2) { !shown.document.pendingEdits.isEmpty }
        #expect(shown.shown == ["Page 4", "Page 1", "Page 2", "Page 3"])
        #expect(live.page(at: 0) === last, "the original page object, not PDFKit's copy")
        #expect(shown.document.pendingEdits == [.reorderPages(order: [3, 0, 1, 2])])
        shown.document.undoManager.undo()
        #expect(shown.shown == ["Page 1", "Page 2", "Page 3", "Page 4"])
        #expect(shown.document.pendingEdits.count == 2, "the reorder and its undo")
    }

    /// Copies may come in selection order rather than page order; each is matched with its own original.
    @Test func copiesAreMatchedWithTheirOwnOriginals() async throws {
        let shown = try await Shown(try TempFile.makePDF(pages: 4))
        defer { shown.window.close() }
        let live = try #require(shown.document.pdfView.document)
        let second = live.page(at: 1)!, fourth = live.page(at: 3)!
        live.insert(fourth.copy() as! PDFPage, at: 0)
        live.insert(second.copy() as! PDFPage, at: 1)
        live.removePage(at: live.index(for: second))
        live.removePage(at: live.index(for: fourth))
        try await waitUntil(seconds: 2) { !shown.document.pendingEdits.isEmpty }
        #expect(shown.shown == ["Page 4", "Page 2", "Page 1", "Page 3"])
        #expect(live.page(at: 0) === fourth && live.page(at: 1) === second)
    }

    @Test func aPageDroppedInFromElsewhereIsPutBack() async throws {
        let shown = try await Shown(try TempFile.makePDF(pages: 2))
        defer { shown.window.close() }
        let live = try #require(shown.document.pdfView.document)
        let stranger = try #require(PDFDocument(url: try TempFile.makePDF(texts: ["Stranger"]))?.page(at: 0))
        live.insert(stranger, at: 1)
        try await waitUntil(seconds: 2) { live.pageCount == 2 }
        #expect(shown.shown == ["Page 1", "Page 2"])
        #expect(shown.document.pendingEdits.isEmpty)
    }

    @Test func pageEditsByPeekerAreNotTakenForDrags() async throws {
        let shown = try await Shown(try TempFile.makePDF(pages: 3))
        defer { shown.window.close() }
        #expect(shown.document.change(.reorderPages(order: [2, 1, 0])))
        #expect(shown.document.change(.deletePages(pages: [0], token: "t")))
        try await Task.sleep(for: .milliseconds(100))
        #expect(shown.document.pendingEdits.count == 2)
        #expect(shown.shown == ["Page 2", "Page 1"])
    }
}
