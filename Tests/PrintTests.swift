import AppKit
import PDFKit
import PeekerKit
@testable import PeekerMarkdown
@testable import PeekerPDF
@testable import PeekerText
import Testing

@Suite struct TextPrintingHelper {
    @Test func printsTheTextWithTheTitleInTheHeader() throws {
        let text = NSAttributedString(string: "Hello from the printer", attributes: [.font: NSFont.systemFont(ofSize: 12)])
        let pdf = try printed({ TextPrinting.job(for: text, info: $0) }, title: "notes.txt")
        let string = pdf.string ?? ""
        #expect(string.contains("Hello from the printer"))
        #expect(string.contains("notes.txt"))
        #expect(pdf.pageCount == 1)
    }

    @Test func longTextRunsOverSeveralPages() throws {
        let lines = (1...300).map { "Line \($0)" }.joined(separator: "\n")
        let text = NSAttributedString(string: lines, attributes: [.font: NSFont.systemFont(ofSize: 12)])
        let pdf = try printed { TextPrinting.job(for: text, info: $0) }
        #expect(pdf.pageCount > 1)
        #expect(pdf.string?.contains("Line 300") == true)
    }

    @Test func theViewIsLightAndAsWideAsThePrintableArea() throws {
        let info = NSPrintInfo()
        info.paperSize = NSSize(width: 612, height: 792)
        let view = try #require(TextPrinting.job(for: NSAttributedString(string: "x"), info: info).view as? NSTextView)
        #expect(view.appearance?.name == .aqua)
        #expect(view.backgroundColor == .white)
        #expect(view.frame.width == 612 - info.leftMargin - info.rightMargin)
    }
}

@Suite struct TextFilePrinting {
    private func open(_ text: String) async throws -> TextDocument {
        let file = try TempFile.make(Data(text.utf8))
        return try await openDocument(file, with: TextPlugin.self, as: TextDocument.self)
    }

    @Test func unsavedTypingPrints() async throws {
        let document = try await open("saved")
        let view = try #require(document.focusView as? NSTextView)
        view.string = "typed but not saved"
        let job = try #require(document.printJob)
        #expect(try printed(job).string?.contains("typed but not saved") == true)
    }

    @Test func printsBlackOnWhiteInTheWindowsFont() async throws {
        let document = try await open("text")
        #expect(document.perform("zoom-in"))
        let job = try #require(document.printJob)
        let view = try #require(job(NSPrintInfo())?.view as? NSTextView)
        let attributes = view.textStorage?.attributes(at: 0, effectiveRange: nil) ?? [:]
        #expect(attributes[.foregroundColor] as? NSColor == .black)
        #expect((attributes[.font] as? NSFont)?.pointSize == 13)
        #expect(view.appearance?.name == .aqua)
    }

    @Test func longLinesWrapEvenWithWrappingOff() async throws {
        let line = (1...60).map { "word\($0)" }.joined(separator: " ")
        let document = try await open(line)
        #expect(document.perform("toggle-wrap"))
        let pdf = try printed(try #require(document.printJob))
        let page = try #require(pdf.page(at: 0))
        #expect(page.bounds(for: .mediaBox).width == 612)
        #expect(pdf.string?.contains("word60") == true)
        #expect(pdf.string?.contains("word1 ") == true)
    }
}

@Suite struct MarkdownPrinting {
    @Test func printsRenderedNotSource() async throws {
        let file = try TempFile.make(Data("# Title\n\nSome **bold** text.\n".utf8), name: "f.md")
        let document = try await MarkdownPlugin.open(file, context: OpenContext(maxPixels: 0, allowsEditing: true))
        let job = try #require(document.printJob)
        let string = try printed(job, title: "f.md").string ?? ""
        #expect(string.contains("Title") && string.contains("Some bold text."))
        #expect(!string.contains("#") && !string.contains("**"))
        #expect(job(NSPrintInfo())?.view?.appearance?.name == .aqua)
    }
}

@Suite struct PDFPrinting {
    @Test func anUnsavedTextBoxPrints() async throws {
        let file = try TempFile.makePDF(pages: 2)
        let document = try await openDocument(file, with: PDFPlugin.self, as: PDFPluginDocument.self)
        document.setEditing(true)
        let box = CGRect(x: 72, y: 400, width: 200, height: 30)
        #expect(document.change(.add(PDFMark(id: PDFEdit.newID(), page: 0, rect: box, kind: .textBox(text: "Approved", fontSize: 18)))))
        let job = try #require(document.printJob)
        let pdf = try printed(job, title: "f.pdf")
        #expect(pdf.pageCount == 2)
        #expect(pdf.string?.contains("Approved") == true)
        #expect(pdf.string?.contains("Page 2") == true)
    }
}

@Suite struct PDFPrintPermissions {
    @Test func aPDFThatForbidsPrintingHasNoPrintJob() async throws {
        let source = try #require(PDFDocument(url: try TempFile.makePDF(pages: 1)))
        let file = try TempFile.make(Data(), name: "restricted.pdf")
        #expect(source.write(to: file, withOptions: [.ownerPasswordOption: "owner", .accessPermissionsOption: 0 as UInt]))
        let document = try await openDocument(file, with: PDFPlugin.self, as: PDFPluginDocument.self)
        #expect(document.pdfView.document?.allowsPrinting == false)
        #expect(document.printJob == nil)
    }
}
