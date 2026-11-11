import AppKit
import PDFKit
import PeekerKit
@testable import PeekerPDF
import Testing

private func open(_ file: URL, preferences: PluginPreferences? = nil) async throws -> PDFPluginDocument {
    let document = try await openDocument(file, with: PDFPlugin.self, as: PDFPluginDocument.self, preferences: preferences)
    document.undoManager.groupsByEvent = false
    return document
}

private let red = PDFMarkupStrip.palette[1].color
private let redSerif = TextBoxStyle(font: .serif, bold: true, italic: true, color: red, boxed: false)

@Suite struct PDFTextBoxStyleWriting {
    @Test func aStyledBoxWritesItsBaseFontAndColors() throws {
        let document = PDFDocument()
        document.insert(PDFPage(), at: 0)
        let mark = PDFMark(
            id: "peeker-t", page: 0, rect: CGRect(x: 10, y: 10, width: 100, height: 20), kind: .textBox(text: "Hi", fontSize: 14, style: redSerif))
        let annotation = PDFMarks.annotation(for: mark)
        #expect(annotation.font?.fontName == "Times-BoldItalic" && annotation.font?.pointSize == 14)
        let ink = try #require(annotation.fontColor?.usingColorSpace(.sRGB))
        #expect(abs(ink.redComponent - red.red) < 0.01 && annotation.color.alphaComponent == 0)
        #expect(PDFMarks.style(of: annotation) == redSerif && PDFMarks.fontSize(of: annotation) == 14)
    }

    @Test func aBoxIsFilledWithItsColorAndTheTextReadsOnIt() throws {
        let boxed = TextBoxStyle(font: .mono, bold: false, italic: false, color: red, boxed: true)
        let annotation = PDFMarks.annotation(
            for: PDFMark(
                id: "peeker-b", page: 0, rect: CGRect(x: 10, y: 10, width: 100, height: 20),
                kind: .textBox(text: "Hi", fontSize: 12, style: boxed)))
        #expect(annotation.font?.fontName == "Courier")
        #expect(try #require(annotation.color.usingColorSpace(.sRGB)).alphaComponent == 1)
        #expect(try #require(annotation.fontColor?.usingColorSpace(.sRGB)).brightnessComponent == 1, "white on red")
        #expect(PDFMarks.style(of: annotation) == boxed)
    }

    @Test func eachFaceHasItsBaseFontName() {
        for font in TextBoxStyle.Font.allCases {
            for bold in [false, true] {
                for italic in [false, true] {
                    let style = TextBoxStyle(font: font, bold: bold, italic: italic, color: red, boxed: false)
                    #expect(
                        TextBoxStyle.face(of: style.fontName).map { [$0.font == font, $0.bold == bold, $0.italic == italic] } == [true, true, true])
                    #expect(NSFont(name: style.fontName, size: 12) != nil, "\(style.fontName) exists on the Mac")
                }
            }
        }
    }

    @Test func aRecordWithoutAStyleIsTheStandardOne() throws {
        let old = #"{"add":{"_0":{"id":"peeker-t","page":0,"rect":[[1,2],[30,10]],"kind":{"textBox":{"text":"Hi","fontSize":12}}}}}"#
        let edit = try JSONDecoder().decode(PDFEdit.self, from: Data(old.utf8))
        guard case .add(let mark) = edit, case .textBox(_, _, let style) = mark.kind else { Issue.record("\(edit)"); return }
        #expect(style == nil)
    }

    @Test func savedStyleSurvivesWritingTheFile() throws {
        let file = try TempFile.makePDF(pages: 1)
        let edits: [PDFEdit] = [
            .add(
                PDFMark(
                    id: "peeker-t", page: 0, rect: CGRect(x: 100, y: 300, width: 120, height: 30),
                    kind: .textBox(text: "Note", fontSize: 16, style: redSerif)))
        ]
        let data = try PDFPlugin.edited(edits, from: file.path)
        let annotation = try #require(PDFDocument(data: data)?.page(at: 0)?.annotations.first)
        #expect(PDFMarks.style(of: annotation) == redSerif && PDFMarks.fontSize(of: annotation) == 16)
    }
}

@Suite(.serialized) struct PDFTextBoxStrip {
    @Test func theStripShowsWhileMarkupIsOnOrABoxIsSelected() async throws {
        let document = try await open(try TempFile.makePDF(pages: 1))
        let window = offscreenWindow(holding: document.contentView)
        defer { window.close() }
        let tools = try #require(document.prepareEditing())
        #expect(document.markupStrip == nil)
        #expect(document.perform("text-box"))
        #expect(document.markupStrip != nil, "while Text Box waits for its click")
        tools.commitTextBox(id: nil, page: 0, topLeft: CGPoint(x: 100, y: 500), text: "Hi", fontSize: 12)
        #expect(document.markupStrip != nil, "the new box is selected")
        tools.end()
        #expect(document.markupStrip != nil, "Markup stays on")
        #expect(document.perform("markup"))
        #expect(document.markupStrip == nil, "until it's turned off")
    }

    @Test func restylingASelectedBoxIsOneUndoableEdit() async throws {
        let document = try await open(try TempFile.makePDF(pages: 1))
        let window = offscreenWindow(holding: document.contentView)
        defer { window.close() }
        let tools = try #require(document.prepareEditing())
        tools.commitTextBox(id: nil, page: 0, topLeft: CGPoint(x: 100, y: 500), text: "Hi", fontSize: 12)
        tools.applyTextBoxStyle(redSerif, size: 20)
        let annotation = try #require(document.pdfView.document?.page(at: 0)?.annotations.first)
        #expect(PDFMarks.style(of: annotation) == redSerif && PDFMarks.fontSize(of: annotation) == 20)
        document.undoManager.undo()
        let undone = try #require(document.pdfView.document?.page(at: 0)?.annotations.first)
        #expect(PDFMarks.style(of: undone) == .standard && PDFMarks.fontSize(of: undone) == 12)
    }

    @Test func aStylePickedWhileTypingLandsWithTheBoxAndIsRemembered() async throws {
        let scratch = ScratchDefaults()
        defer { scratch.close() }
        let document = try await open(try TempFile.makePDF(pages: 1), preferences: scratch.preferences("pdf"))
        let window = offscreenWindow(holding: document.contentView)
        defer { window.close() }
        let tools = try #require(document.prepareEditing())
        document.pdfView.autoScales = false
        document.pdfView.scaleFactor = 1
        document.pdfView.layoutDocumentView()
        #expect(document.perform("text-box"))
        let page = try #require(document.pdfView.document?.page(at: 0))
        let point = CGPoint(x: 100, y: 500)
        let location = document.pdfView.convert(document.pdfView.convert(point, from: page), to: nil)
        let click = NSEvent.mouseEvent(
            with: .leftMouseDown, location: location, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
            context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
        #expect(tools.mouseDown(with: click, at: document.pdfView.convert(point, from: page)))
        let textView = try #require(window.firstResponder as? NSTextView)
        textView.string = "Typed"
        let strip = try #require(document.markupStrip)
        strip.swatches[1].performClick(nil)
        let menu = try #require(strip.textMenu.menu)
        menu.performActionForItem(at: try #require(menu.items.firstIndex { $0.title == "Serif" }))
        #expect(textView.font?.fontName == "Times-Roman", "the box being typed changes at once")
        #expect(window.firstResponder === textView, "and keeps the keyboard")
        tools.end()
        let annotation = try #require(page.annotations.first)
        #expect(PDFMarks.style(of: annotation) == TextBoxStyle(font: .serif, bold: false, italic: false, color: red, boxed: false))
        let next = try await open(try TempFile.makePDF(pages: 1), preferences: scratch.preferences("pdf"))
        #expect(next.textBoxStyle.font == .serif && next.textBoxStyle.color == red, "remembered for the next box")
    }
}

/// Found in review: a crafted size, styles through delete and folding, edits that change nothing, readable box text.
@Suite(.serialized) struct PDFTextBoxStyleReviewFixes {
    @Test func aCraftedSizeIsKeptInRange() {
        let annotation = PDFAnnotation(bounds: CGRect(x: 0, y: 0, width: 50, height: 20), forType: .freeText, withProperties: nil)
        annotation.setValue("font: Helvetica 10000000000000000000pt; color: #000000", forAnnotationKey: PDFAnnotationKey(rawValue: "/DS"))
        #expect(PDFMarks.fontSize(of: annotation) == PDFMarks.fontSizes.upperBound)
    }

    @Test func undoingADeleteBringsTheStyleBack() async throws {
        let document = try await open(try TempFile.makePDF(pages: 1))
        let tools = try #require(document.prepareEditing())
        tools.commitTextBox(id: nil, page: 0, topLeft: CGPoint(x: 100, y: 500), text: "Hi", fontSize: 16, style: redSerif)
        #expect(tools.deleteSelection())
        document.undoManager.undo()
        let annotation = try #require(document.pdfView.document?.page(at: 0)?.annotations.first)
        #expect(PDFMarks.style(of: annotation) == redSerif && PDFMarks.fontSize(of: annotation) == 16)
    }

    @Test func aRestyleFoldsIntoItsBox() {
        let box = CGRect(x: 10, y: 10, width: 50, height: 20)
        let folded = PDFEdit.folded([
            .add(PDFMark(id: "peeker-1", page: 0, rect: box, kind: .textBox(text: "Hi", fontSize: 12))),
            .setText(id: "peeker-1", page: 0, text: "Hi", fontSize: 14, rect: box, style: redSerif),
        ])
        #expect(folded == [.add(PDFMark(id: "peeker-1", page: 0, rect: box, kind: .textBox(text: "Hi", fontSize: 14, style: redSerif)))])
    }

    @Test func pickingTheLookABoxHasChangesNothing() async throws {
        let document = try await open(try TempFile.makePDF(pages: 1))
        let tools = try #require(document.prepareEditing())
        tools.commitTextBox(id: nil, page: 0, topLeft: CGPoint(x: 100, y: 500), text: "Hi", fontSize: 12)
        let undoSteps = { document.undoManager.canUndo ? 1 : 0 }
        document.undoManager.removeAllActions()
        tools.applyTextBoxStyle(.standard, size: 12)
        #expect(undoSteps() == 0, "the same look is no edit")
        tools.applyTextBoxStyle(.standard, size: 14)
        #expect(undoSteps() == 1, "a new size is one")
    }

    @Test func boxTextIsWhicheverOfBlackAndWhiteReadsBetter() {
        let text = { (name: String) in
            TextBoxStyle(font: .sans, bold: false, italic: false, color: PDFMarkupStrip.palette.first { $0.name == name }!.color, boxed: true)
                .textColor
        }
        let black = RGBA(red: 0, green: 0, blue: 0, alpha: 1), white = RGBA(red: 1, green: 1, blue: 1, alpha: 1)
        #expect(text("Orange") == black && text("Green") == black && text("Yellow") == black)
        #expect(text("Red") == white && text("Blue") == white && text("Black") == white)
    }

    @Test func aSeeThroughColorIsRefused() {
        var style = redSerif
        style.color = RGBA(red: 1, green: 0, blue: 0, alpha: 0)
        #expect(!style.isValid)
    }
}
