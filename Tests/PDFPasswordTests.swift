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
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: "Secret page", attributes: [.font: CTFontCreateWithName("Helvetica" as CFString, 24, nil)]))
    context.textPosition = CGPoint(x: 72, y: 700)
    CTLineDraw(line, context)
    context.endPDFPage()
    context.closePDF()
    return file
}

@Suite struct PDFPasswords {
    private func open(_ file: URL, editable: Bool = true) async throws -> LockedPDFDocument {
        try #require(try await PDFPlugin.open(file, context: OpenContext(maxPixels: 0, allowsEditing: editable)) as? LockedPDFDocument)
    }

    @Test func aLockedPDFOpensToItsLockScreen() async throws {
        let locked = try await open(try lockedPDF())
        #expect(locked.canUnlock)
        #expect(locked.sidebar.isEmpty && locked.commands.isEmpty && locked.editMode == .none)
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

    @Test func theRightPasswordHandsOverAViewOnlyPDF() async throws {
        let locked = try await open(try lockedPDF())
        var replaced: (any PluginDocument)?
        locked.onReplace = { replaced = $0 }
        #expect(locked.unlock(with: "secret"))
        let document = try #require(replaced as? PDFPluginDocument)
        #expect(document.pdfView.document?.page(at: 0)?.string?.contains("Secret page") == true)
        #expect(document.editMode == .unavailable(reason: "This PDF is password protected, so Peeker opens it view-only."))
        #expect(document.printJob != nil)
        #expect(!document.sidebar.isEmpty)
        #expect(locked.password == "", "nothing keeps the password")
    }

    @Test func theSpacePanelPointsToOpen() async throws {
        let locked = try await open(try lockedPDF(), editable: false)
        #expect(!locked.canUnlock)
        #expect(locked.message.contains("Open"))
    }
}
