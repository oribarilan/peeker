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

    /// The pictures in a print job's text view, with the width each is laid out at.
    private func pictures(in job: (NSPrintInfo) -> NSPrintOperation?) throws -> (pictures: [(MarkdownImageAttachment, CGFloat)], view: NSTextView) {
        let info = NSPrintInfo()
        info.paperSize = NSSize(width: 612, height: 792)
        let view = try #require(job(info)?.view as? NSTextView)
        let storage = try #require(view.textStorage), layout = try #require(view.layoutManager)
        var found: [(MarkdownImageAttachment, CGFloat)] = []
        storage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: storage.length)) { value, range, _ in
            guard let attachment = value as? MarkdownImageAttachment else { return }
            found.append((attachment, layout.attachmentSize(forGlyphAt: layout.glyphIndexForCharacter(at: range.location)).width))
        }
        return (found, view)
    }

    private func editor(_ markdown: String, pictures: [String] = []) async throws -> MarkdownEditor {
        let file = try markdownFolder(markdown, pictures: pictures, size: CGSize(width: 3000, height: 1500))
        return try await openDocument(file, with: MarkdownPlugin.self, as: MarkdownEditor.self)
    }

    @Test func aLocalPicturePrintsDecodedAndFittedToThePage() async throws {
        let editor = try await editor("# Chart\n\n![chart](img/chart.png)\n", pictures: ["img/chart.png"])
        let (found, view) = try pictures(in: try #require(editor.printJob))
        let (attachment, width) = try #require(found.first)
        #expect(attachment.isDecoded)
        #expect(width > 0 && width <= view.frame.width)
        let pixels = try #require(attachment.image?.cgImage(forProposedRect: nil, context: nil, hints: nil)?.width)
        #expect(pixels < 3000 && pixels <= Int(view.frame.width * 2))
        #expect(!view.string.contains("[chart]"))
    }

    @Test func aWebImagePrintsItsAltText() async throws {
        let editor = try await editor("![build](https://example.com/badge.svg)\n")
        let (found, view) = try pictures(in: try #require(editor.printJob))
        #expect(found.isEmpty)
        #expect(view.string.contains("[build]"))
    }

    @Test func anUnsavedImageLinePrintsThePicture() async throws {
        let editor = try await editor("# Notes\n", pictures: ["new.png"])
        let view = try #require(editor.focusView as? NSTextView)
        view.insertText("\n![new](new.png)\n", replacementRange: NSRange(location: (view.string as NSString).length, length: 0))
        let (found, _) = try pictures(in: try #require(editor.printJob))
        #expect(found.count == 1 && found.first?.0.isDecoded == true)
    }

    @Test func thePeekPanelPrintsItsPicturesToo() async throws {
        let file = try markdownFolder("![chart](chart.png)\n", pictures: ["chart.png"])
        let document = try await openDocument(file, with: MarkdownPlugin.self, as: MarkdownDocument.self, editing: false)
        let (found, _) = try pictures(in: try #require(document.printJob))
        #expect(found.count == 1 && found.first?.0.isDecoded == true)
    }
}

@Suite struct PDFPrinting {
    @Test func anUnsavedTextBoxPrints() async throws {
        let file = try TempFile.makePDF(pages: 2)
        let document = try await openDocument(file, with: PDFPlugin.self, as: PDFPluginDocument.self)
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

/// A plugin whose documents print a fixed view, or don't print when `prints` is false.
private enum PrintingPlugin: Plugin {
    static let id = "printing"
    static let name = "Printing"
    static let defaultExtensions: [String] = []
    static let tools: [ToolSpec] = []
    static var prints = true
    static var openDelay = Duration.zero

    static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument {
        try? await Task.sleep(for: openDelay)
        return PrintingDocument(prints: prints)
    }
}

private final class PrintingDocument: PluginDocument {
    let contentView = NSView()
    let prints: Bool
    init(prints: Bool) { self.prints = prints }

    var printJob: ((NSPrintInfo) -> NSPrintOperation?)? {
        prints ? { NSPrintOperation(view: NSView(frame: NSRect(x: 0, y: 0, width: 10, height: 10)), printInfo: $0) } : nil
    }
}

/// The Print menu item in an Editor window.
@Suite(.serialized) struct PrintTool {
    private func window(prints: Bool, wait: Bool = true) async throws -> DocumentWindowController {
        PrintingPlugin.prints = prints
        PrintingPlugin.openDelay = wait ? .zero : .seconds(5)
        return try await documentWindow(for: PrintingPlugin.self, waiting: wait)
    }

    private var printItem: NSMenuItem {
        NSMenuItem(title: "Print…", action: #selector(DocumentWindowController.printDocument(_:)), keyEquivalent: "p")
    }

    @Test func printIsEnabledOnlyForAnOpenedDocumentThatPrints() async throws {
        let printing = try await window(prints: true)
        let silent = try await window(prints: false)
        defer { printing.close(); silent.close() }
        #expect(printing.validateMenuItem(printItem))
        #expect(!silent.validateMenuItem(printItem))
    }

    @Test func printIsDisabledWhileOpening() async throws {
        let opening = try await window(prints: true, wait: false)
        defer { opening.close() }
        #expect(opening.current?.pluginDocument == nil)
        #expect(!opening.validateMenuItem(printItem))
    }
}
