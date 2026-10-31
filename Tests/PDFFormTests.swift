import AppKit
import PDFKit
import PeekerKit
@testable import PeekerPDF
import Testing

/// A form open in an off-screen window, so the view lays out its pages.
@MainActor private final class OpenForm {
    let document: PDFPluginDocument
    let window: NSWindow

    init(acroForm: String = "") async throws {
        let file = try FormPDF.make(acroForm: acroForm)
        document = try #require(try await PDFPlugin.open(file, context: OpenContext(maxPixels: 0, allowsEditing: true)) as? PDFPluginDocument)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 900), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        document.pdfView.frame = window.contentView!.bounds
        window.contentView!.addSubview(document.pdfView)
        document.pdfView.autoScales = false
        document.pdfView.scaleFactor = 1
        document.pdfView.layoutDocumentView()
        document.undoManager.groupsByEvent = false  // no event loop here to close each step's group
    }

    var page: PDFPage { document.pdfView.document!.page(at: 0)! }

    func widget(_ name: String, on: String? = nil) -> PDFAnnotation {
        page.annotations.first { $0.fieldName == name && (on == nil || $0.buttonWidgetStateString == on) }!
    }

    /// `rect`'s center on page 0, in the view's coordinates.
    func point(in rect: CGRect) -> NSPoint {
        document.pdfView.convert(CGPoint(x: rect.midX, y: rect.midY), from: page)
    }
}

@Suite(.serialized) struct PDFFormFields {
    @Test func eachKindOfFieldChangeIsRecorded() async throws {
        let form = try await OpenForm()
        form.document.setEditing(true)
        var count = 0
        form.document.onEdit = { count += 1 }
        form.widget("Name").widgetStringValue = "Ori"
        form.widget("Agree").buttonWidgetState = .onState
        form.widget("Pick", on: "B").widgetStringValue = "B"
        form.widget("Color").widgetStringValue = "Green"
        form.document.checkFields()
        let expected: [PDFEdit] = [
            .field(name: "Name", value: "Ori"), .field(name: "Agree", value: "Yes"),
            .field(name: "Pick", value: "B"), .field(name: "Color", value: "Green"),
        ]
        #expect(form.document.pendingEdits.count == 4 && expected.allSatisfy(form.document.pendingEdits.contains))
        #expect(count == 4)
        form.document.checkFields()
        #expect(count == 4, "an unchanged field isn't recorded again")
    }

    @Test func typingIntoATextFieldIsRecordedAsYouType() async throws {
        let form = try await OpenForm()
        form.document.setEditing(true)
        form.document.widgetClicked(form.widget("Name"))
        let editor = NSTextView()
        form.document.pdfView.addSubview(editor)
        editor.string = "Or"
        NotificationCenter.default.post(name: NSText.didChangeNotification, object: editor)
        editor.string = "Ori"
        NotificationCenter.default.post(name: NSText.didChangeNotification, object: editor)
        #expect(form.document.pendingEdits == [.field(name: "Name", value: "Ori")])
    }

    @Test func textEditingOutsideTheViewIsIgnored() async throws {
        let form = try await OpenForm()
        form.document.setEditing(true)
        form.document.widgetClicked(form.widget("Name"))
        let elsewhere = NSTextView()
        elsewhere.string = "nope"
        NotificationCenter.default.post(name: NSText.didChangeNotification, object: elsewhere)
        #expect(form.document.pendingEdits.isEmpty)
    }

    /// A text box's editor sits in the view too; its typing belongs to the box, not the last clicked field.
    @Test func typingInATextBoxIsNotAFieldChange() async throws {
        let form = try await OpenForm()
        form.document.setEditing(true)
        form.document.widgetClicked(form.widget("Name"))
        let editor = TextBoxEditor(view: form.document.pdfView, page: form.page, topLeft: CGPoint(x: 300, y: 400), text: "", fontSize: 12, hiding: nil) { _, _ in }
        let box = try #require(form.window.firstResponder as? NSTextView)
        box.string = "31 Oct"
        NotificationCenter.default.post(name: NSText.didChangeNotification, object: box)
        #expect(form.document.pendingEdits.isEmpty)
        withExtendedLifetime(editor) {}
    }

    @Test func fieldChangesAreNotRecordedInTheReadView() async throws {
        let form = try await OpenForm()
        form.widget("Name").widgetStringValue = "Ori"
        form.document.checkFields()
        #expect(form.document.pendingEdits.isEmpty)
    }

    @Test func undoPutsTheOldValueBack() async throws {
        let form = try await OpenForm()
        form.document.setEditing(true)
        form.widget("Name").widgetStringValue = "Ori"
        form.document.checkFields()
        form.document.undoManager.undo()
        #expect(form.widget("Name").widgetStringValue == "")
        #expect(form.document.pendingEdits == [.field(name: "Name", value: "")])
        form.document.checkFields()
        #expect(form.document.pendingEdits == [.field(name: "Name", value: "")], "the undone value is known, not a new change")
    }
}

@Suite(.serialized) struct PDFReadView {
    @Test func aClickOnAFieldIsSwallowedOnlyInTheReadView() async throws {
        let form = try await OpenForm()
        let view = try #require(form.document.pdfView as PeekerPDFView?)
        #expect(view.swallowsClick(at: form.point(in: FormPDF.nameField)))
        form.document.setEditing(true)
        #expect(!view.swallowsClick(at: form.point(in: FormPDF.nameField)))
    }

    @Test func aClickOnALinkStillReachesTheView() async throws {
        let form = try await OpenForm()
        #expect(!form.document.pdfView.swallowsClick(at: form.point(in: FormPDF.link)))
        #expect(!form.document.pdfView.swallowsClick(at: form.point(in: CGRect(x: 400, y: 400, width: 1, height: 1))))
    }

    @Test func aSwallowedClickChangesNothing() async throws {
        let form = try await OpenForm()
        let point = form.document.pdfView.convert(form.point(in: FormPDF.nameField), to: nil)
        let click = try #require(NSEvent.mouseEvent(with: .leftMouseDown, location: point, modifierFlags: [], timestamp: 0,
                                                    windowNumber: form.window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
        form.document.pdfView.mouseDown(with: click)
        #expect(form.widget("Name").widgetStringValue == "")
        #expect(form.window.firstResponder === form.window, "no field editor took focus")
        #expect(form.document.unsavedEdits() == nil)
    }
}
