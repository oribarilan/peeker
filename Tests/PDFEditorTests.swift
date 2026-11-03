import AppKit
import PDFKit
import PeekerKit
@testable import PeekerPDF
import Testing

/// A PDF open in the Editor and laid out in an off-screen window, with its thumbnails.
@MainActor private final class Editor {
    let document: PDFPluginDocument
    let window: NSWindow
    let thumbnails: PageThumbnails

    init(_ file: URL) async throws {
        document = try await openDocument(file, with: PDFPlugin.self, as: PDFPluginDocument.self)
        document.undoManager.groupsByEvent = false  // no event loop here to close each step's group
        window = offscreenWindow(holding: document.pdfView)
        document.pdfView.autoScales = false
        document.pdfView.scaleFactor = 1
        document.pdfView.layoutDocumentView()
        thumbnails = try #require(document.makeSidebar().first?.view as? PageThumbnails)
    }

    /// `rect`'s center on page 0, in the view's coordinates.
    func point(in rect: CGRect) -> NSPoint {
        let page = document.pdfView.document!.page(at: 0)!
        return document.pdfView.convert(CGPoint(x: rect.midX, y: rect.midY), from: page)
    }
}

@Suite(.serialized) struct PDFEditor {
    @Test func theEditPartsWaitForTheFirstToolOrField() async throws {
        let editor = try await Editor(try FormPDF.make())
        #expect(editor.document.editController == nil)
        editor.document.pdfView.prepareForClick(at: editor.point(in: CGRect(x: 400, y: 400, width: 1, height: 1)))
        #expect(editor.document.editController == nil, "a click on the page itself")
        editor.document.pdfView.prepareForClick(at: editor.point(in: FormPDF.nameField))
        #expect(editor.document.editController != nil, "a click on a field")
        let other = try await Editor(try TempFile.makePDF(pages: 1))
        #expect(other.document.perform("text-box"))
        #expect(other.document.editController != nil && other.document.activeTool == "text-box")
    }

    @Test func toolsWorkRightAfterOpening() async throws {
        let editor = try await Editor(try TempFile.makePDF(pages: 3))
        #expect(editor.document.perform("highlight") && editor.document.activeTool == "highlight")
        #expect(editor.document.perform("rotate-left"))
        #expect(editor.document.perform("delete-page"))
        #expect(editor.document.pendingEdits.count == 2)
        #expect(editor.thumbnails.allowsDragging == PageThumbnails.dragsReorderPages)
        #expect(editor.document.pdfView.undoManager === editor.document.undoManager)
    }

    @Test func aReadOnlyPDFRefusesFieldsAndDrags() async throws {
        let editor = try await Editor(try FormPDF.make(acroForm: "/SigFlags 3"))
        #expect(editor.document.editability == .readOnly("This PDF is digitally signed; changing it would break the signature."))
        #expect(editor.document.pdfView.swallowsClick(at: editor.point(in: FormPDF.nameField)))
        #expect(!editor.thumbnails.allowsDragging && editor.thumbnails.menu == nil)
        #expect(!editor.document.perform("text-box"))
    }

    /// Cmd+F leaves the keyboard in the search field; Undo after a tool must still reach the document's history.
    @Test func anEditToolTakesTheKeyboardBackForUndo() async throws {
        let editor = try await Editor(try TempFile.makePDF(pages: 1))
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 80, height: 20))
        editor.window.contentView?.addSubview(field)
        editor.window.makeFirstResponder(field)
        #expect(editor.document.perform("text-box"))
        #expect(editor.window.firstResponder === editor.document.pdfView)
    }

    /// A page tool run with the thumbnails focused leaves them the keyboard, and Undo from there undoes it.
    @Test func undoFromTheThumbnailsReachesTheDocument() async throws {
        let editor = try await Editor(try TempFile.makePDF(pages: 2))
        editor.thumbnails.frame = NSRect(x: 0, y: 0, width: 150, height: 600)
        editor.window.contentView?.addSubview(editor.thumbnails)
        editor.window.makeFirstResponder(editor.thumbnails)
        #expect(editor.document.perform("rotate-left"))
        #expect(editor.window.firstResponder === editor.thumbnails)
        #expect(editor.thumbnails.validateMenuItem(NSMenuItem(title: "Undo", action: #selector(PageThumbnails.undo(_:)), keyEquivalent: "")))
        editor.thumbnails.undo(nil)
        #expect(editor.document.undoManager.canRedo && !editor.document.undoManager.canUndo)
    }

    /// The tools select a mark from 2 points outside it, so the first click there must set them up too.
    @Test func aClickJustOutsideAMarkSetsUpTheTools() async throws {
        let editor = try await Editor(try TempFile.makePDF(pages: 1))
        let rect = CGRect(x: 100, y: 300, width: 180, height: 60)
        #expect(editor.document.change(.add(PDFMark(id: PDFEdit.newID(), page: 0, rect: rect, kind: .textBox(text: "x", fontSize: 12)))))
        #expect(editor.document.editController == nil)
        let page = try #require(editor.document.pdfView.document?.page(at: 0))
        editor.document.pdfView.prepareForClick(at: editor.document.pdfView.convert(CGPoint(x: rect.maxX + 1, y: rect.midY), from: page))
        #expect(editor.document.editController != nil)
    }
}
