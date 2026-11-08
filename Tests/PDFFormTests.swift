import AppKit
import PDFKit
import PeekerKit
@testable import PeekerPDF
import Testing

/// A form open in an off-screen window, so the view lays out its pages. In the Editor the view has seen the start of a
/// click on the Name field, which sets up form editing the way a real first click does.
@MainActor private final class OpenForm {
    let document: PDFPluginDocument
    let window: NSWindow

    init(acroForm: String = "", editing: Bool = true) async throws {
        let file = try FormPDF.make(acroForm: acroForm)
        document = try await openDocument(file, with: PDFPlugin.self, as: PDFPluginDocument.self, editing: editing)
        window = offscreenWindow(holding: document.pdfView)
        document.pdfView.autoScales = false
        document.pdfView.scaleFactor = 1
        document.pdfView.layoutDocumentView()
        document.undoManager.groupsByEvent = false  // no event loop here to close each step's group
        if editing { document.pdfView.prepareForClick(at: point(in: FormPDF.nameField)) }
    }

    var page: PDFPage { document.pdfView.document!.page(at: 0)! }

    func widget(_ name: String, on: String? = nil) -> PDFAnnotation {
        page.annotations.first { $0.fieldName == name && (on == nil || $0.buttonWidgetStateString == on) }!
    }

    /// `rect`'s center on page 0, in the view's coordinates.
    func point(in rect: CGRect) -> NSPoint {
        document.pdfView.convert(CGPoint(x: rect.midX, y: rect.midY), from: page)
    }

    /// What the view reports when a click in the Editor ends: the field it hit, if any.
    func clickEnded(on widget: PDFAnnotation? = nil) {
        document.pdfView.onInteraction?(widget)
    }
}

@Suite(.serialized) struct PDFFormFields {
    @Test func eachKindOfFieldChangeIsRecorded() async throws {
        let form = try await OpenForm()
        var count = 0
        form.document.onEdit = { count += 1 }
        form.widget("Name").widgetStringValue = "Ori"
        form.widget("Agree").buttonWidgetState = .onState
        form.widget("Pick", on: "B").widgetStringValue = "B"
        form.widget("Color").widgetStringValue = "Green"
        form.clickEnded()
        let expected: [PDFEdit] = [
            .field(name: "Name", value: "Ori"), .field(name: "Agree", value: "Yes"),
            .field(name: "Pick", value: "B"), .field(name: "Color", value: "Green"),
        ]
        #expect(form.document.pendingEdits.count == 4 && expected.allSatisfy(form.document.pendingEdits.contains))
        #expect(count == 4)
        form.clickEnded()
        #expect(count == 4, "an unchanged field isn't recorded again")
    }

    @Test func typingIntoATextFieldRightAfterOpeningIsRecordedAsYouType() async throws {
        let form = try await OpenForm()
        var edits = 0
        form.document.onEdit = { edits += 1 }
        form.clickEnded(on: form.widget("Name"))
        let editor = NSTextView()
        form.document.pdfView.addSubview(editor)
        editor.string = "Or"
        NotificationCenter.default.post(name: NSText.didChangeNotification, object: editor)
        editor.string = "Ori"
        NotificationCenter.default.post(name: NSText.didChangeNotification, object: editor)
        #expect(form.document.pendingEdits == [.field(name: "Name", value: "Ori")])
        #expect(edits == 2 && form.document.unsavedEdits() != nil)
    }

    @Test func textEditingOutsideTheViewIsIgnored() async throws {
        let form = try await OpenForm()
        form.clickEnded(on: form.widget("Name"))
        let elsewhere = NSTextView()
        elsewhere.string = "nope"
        NotificationCenter.default.post(name: NSText.didChangeNotification, object: elsewhere)
        #expect(form.document.pendingEdits.isEmpty)
    }

    /// A text box's editor sits in the view too; its typing belongs to the box, not the last clicked field.
    @Test func typingInATextBoxIsNotAFieldChange() async throws {
        let form = try await OpenForm()
        form.clickEnded(on: form.widget("Name"))
        let editor = TextBoxEditor(view: form.document.pdfView, page: form.page, topLeft: CGPoint(x: 300, y: 400), text: "", fontSize: 12, style: .standard, hiding: nil) { _, _, _ in }
        let box = try #require(form.window.firstResponder as? NSTextView)
        box.string = "31 Oct"
        NotificationCenter.default.post(name: NSText.didChangeNotification, object: box)
        #expect(form.document.pendingEdits.isEmpty)
        withExtendedLifetime(editor) {}
    }

    @Test func fieldChangesAreNotRecordedInThePeekPanel() async throws {
        let form = try await OpenForm(editing: false)
        form.widget("Name").widgetStringValue = "Ori"
        let point = form.document.pdfView.convert(form.point(in: CGRect(x: 400, y: 400, width: 1, height: 1)), to: nil)
        let release = try #require(NSEvent.mouseEvent(with: .leftMouseUp, location: point, modifierFlags: [], timestamp: 0,
                                                      windowNumber: form.window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
        form.document.pdfView.mouseUp(with: release)
        #expect(form.document.pendingEdits.isEmpty)
    }

    @Test func undoPutsTheOldValueBack() async throws {
        let form = try await OpenForm()
        form.widget("Name").widgetStringValue = "Ori"
        form.clickEnded()
        form.document.undoManager.undo()
        #expect(form.widget("Name").widgetStringValue == "")
        #expect(form.document.pendingEdits == [.field(name: "Name", value: "")])
        form.clickEnded()
        #expect(form.document.pendingEdits == [.field(name: "Name", value: "")], "the undone value is known, not a new change")
    }

    /// The field is still there, so the message must not say it's gone.
    @Test func aTooLongValueSaysSo() throws {
        let document = try #require(PDFDocument(url: try FormPDF.make()))
        let long = String(repeating: "x", count: 10_001)
        #expect {
            try PDFEditing.apply(.field(name: "Name", value: long), to: document, fileName: "f.pdf")
        } throws: { error in
            (error as? PluginError)?.message.contains("too long") == true
        }
    }
}

@Suite(.serialized) struct PDFPeekPanelForm {
    @Test func aClickOnAFieldIsSwallowedOnlyInThePeekPanel() async throws {
        let peek = try await OpenForm(editing: false)
        #expect(peek.document.pdfView.swallowsClick(at: peek.point(in: FormPDF.nameField)))
        let editor = try await OpenForm()
        #expect(!editor.document.pdfView.swallowsClick(at: editor.point(in: FormPDF.nameField)))
    }

    @Test func aClickOnALinkStillReachesTheView() async throws {
        let form = try await OpenForm(editing: false)
        #expect(!form.document.pdfView.swallowsClick(at: form.point(in: FormPDF.link)))
        #expect(!form.document.pdfView.swallowsClick(at: form.point(in: CGRect(x: 400, y: 400, width: 1, height: 1))))
    }

    @Test func aSwallowedClickChangesNothing() async throws {
        let form = try await OpenForm(editing: false)
        let point = form.document.pdfView.convert(form.point(in: FormPDF.nameField), to: nil)
        let click = try #require(NSEvent.mouseEvent(with: .leftMouseDown, location: point, modifierFlags: [], timestamp: 0,
                                                    windowNumber: form.window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
        form.document.pdfView.mouseDown(with: click)
        #expect(form.widget("Name").widgetStringValue == "")
        #expect(form.window.firstResponder === form.window, "no field editor took focus")
        #expect(form.document.unsavedEdits() == nil)
    }
}
