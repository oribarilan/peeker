import AppKit
import CoreText
import PDFKit
import PeekerKit
@testable import PeekerPDF
import Testing

/// A one-page PDF saying "Secret page" that opens only with the password "secret".
private func lockedPDF() throws -> URL {
    let file = try TempFile.make(Data(), name: "locked.pdf")
    var box = CGRect(x: 0, y: 0, width: 612, height: 792)
    let info = [kCGPDFContextUserPassword: "secret", kCGPDFContextOwnerPassword: "owner", kCGPDFContextTitle: "Payslip"] as CFDictionary
    let context = try #require(CGContext(file as CFURL, mediaBox: &box, info))
    context.beginPDFPage(nil)
    let line = CTLineCreateWithAttributedString(
        NSAttributedString(string: "Secret page", attributes: [.font: CTFontCreateWithName("Helvetica" as CFString, 24, nil)]))
    context.textPosition = CGPoint(x: 72, y: 700)
    CTLineDraw(line, context)
    context.endPDFPage()
    context.closePDF()
    return file
}

@Suite struct PDFPasswords {
    private func open(_ file: URL, editable: Bool = true) async throws -> LockedPDFDocument {
        try await openDocument(file, with: PDFPlugin.self, as: LockedPDFDocument.self, editing: editable)
    }

    @Test func aLockedPDFOpensToItsLockScreen() async throws {
        let locked = try await open(try lockedPDF())
        #expect(locked.canUnlock)
        #expect(locked.makeSidebar().isEmpty && locked.tools.isEmpty && locked.editability == .notEditable)
    }

    @Test func aWrongPasswordSaysSoAndClearsTheField() async throws {
        let locked = try await open(try lockedPDF())
        var replaced: (any PluginDocument)?
        locked.onReplace = { replaced = $0 }
        #expect(!locked.unlock(with: "nope"))
        #expect(locked.message == "Wrong password.")
        #expect(locked.password == "")
        #expect(replaced == nil)
    }

    @Test func theRightPasswordHandsOverAnEditablePDF() async throws {
        let locked = try await open(try lockedPDF())
        var replaced: (any PluginDocument)?
        locked.onReplace = { replaced = $0 }
        #expect(locked.unlock(with: "secret"))
        let document = try #require(replaced as? PDFPluginDocument)
        #expect(document.pdfView.document?.page(at: 0)?.string?.contains("Secret page") == true)
        #expect(document.editability == .editable)
        #expect(document.lock?.password == "secret" && document.lock?.isPermissionsPassword == false)
        #expect(document.printJob != nil)
        #expect(!document.makeSidebar().isEmpty)
        #expect(locked.password == "", "the field is cleared")
    }

    @Test func thePermissionsPasswordUnlocksItToo() async throws {
        let locked = try await open(try lockedPDF())
        var replaced: (any PluginDocument)?
        locked.onReplace = { replaced = $0 }
        #expect(locked.unlock(with: "owner"))
        let document = try #require(replaced as? PDFPluginDocument)
        #expect(document.lock?.isPermissionsPassword == true && document.lock?.openPassword == nil)
    }

    @Test func theFilesPermissionsStillApply() async throws {
        let form = try #require(PDFDocument(url: try FormPDF.make()))
        // PDFKit's bits for everything but changes, commenting and form filling.
        let options: [PDFDocumentWriteOption: Any] = [
            .userPasswordOption: "secret", .ownerPasswordOption: "owner", .accessPermissionsOption: UInt(27),
        ]
        let file = try TempFile.make(try #require(form.dataRepresentation(options: options)), name: "limited.pdf")
        let locked = try await open(file)
        var replaced: (any PluginDocument)?
        locked.onReplace = { replaced = $0 }
        #expect(locked.unlock(with: "secret"))
        let document = try #require(replaced as? PDFPluginDocument)
        #expect(document.editability == .readOnly("This PDF's permissions don't allow changes."))
    }

    @Test func theSpacePanelPointsToOpen() async throws {
        let locked = try await open(try lockedPDF(), editable: false)
        #expect(!locked.canUnlock)
        #expect(locked.message.contains("Open"))
    }
}
