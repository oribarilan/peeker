import AppKit
import PDFKit
import PeekerKit
@testable import PeekerPDF
import Testing

private func open(_ file: URL, editable: Bool = true, preferences: PluginPreferences? = nil) async throws -> PDFPluginDocument {
    try await openDocument(file, with: PDFPlugin.self, as: PDFPluginDocument.self, editing: editable, preferences: preferences)
}

private func selectAll(_ document: PDFPluginDocument) throws {
    let page = try #require(document.pdfView.document?.page(at: 0))
    document.pdfView.setCurrentSelection(page.selection(for: page.bounds(for: .mediaBox)), animate: false)
}

/// The color of each pending highlight, in order.
@MainActor private func colors(_ document: PDFPluginDocument) -> [RGBA] {
    document.pendingEdits.compactMap { edit in
        if case .add(let mark) = edit, case .highlight(let color) = mark.kind { color } else { nil }
    }
}

@MainActor private func color(_ id: String) throws -> RGBA {
    let spec = try #require(PDFPlugin.tools.first { $0.id == "highlight" })
    return try #require(spec.choices.first { $0.id == id }?.color)
}

@Suite struct PDFHighlightColors {
    @Test func highlightOffersPreviewsFiveColors() throws {
        let spec = try #require(PDFPlugin.tools.first { $0.id == "highlight" })
        #expect(spec.choices.map(\.title) == ["Yellow", "Green", "Blue", "Pink", "Purple"])
        #expect(spec.choices.map(\.id) == ["highlight-yellow", "highlight-green", "highlight-blue", "highlight-pink", "highlight-purple"])
        #expect(spec.choices.allSatisfy { $0.color != nil })
        #expect(spec.choicesTitle == "Highlight Color")
        #expect(try color("highlight-yellow") == RGBA(red: 1, green: 0.8, blue: 0, alpha: 1), "today's yellow")
    }

    @Test func yellowIsOnAtFirst() async throws {
        let document = try await open(try TempFile.makePDF(pages: 1))
        #expect(document.isOn("highlight-yellow") == true && document.isOn("highlight-green") == false)
        #expect(document.isOn("highlight") == nil, "Highlight itself isn't a switch")
    }

    @Test func pickingAColorHighlightsTheSelectionAndArms() async throws {
        let document = try await open(try TempFile.makePDF(pages: 1))
        try selectAll(document)
        #expect(document.perform("highlight-green"))
        #expect(colors(document) == [try color("highlight-green")])
        #expect(document.activeTool == "highlight", "armed for one more drag")
        #expect(document.isOn("highlight-green") == true && document.isOn("highlight-yellow") == false)
    }

    @Test func earlierHighlightsKeepTheirColorAndSavingWritesEach() async throws {
        let file = try TempFile.makePDF(pages: 1)
        let document = try await open(file)
        try selectAll(document)
        #expect(document.perform("highlight"))
        try selectAll(document)
        #expect(document.perform("highlight-blue"))
        #expect(colors(document) == [try color("highlight-yellow"), try color("highlight-blue")])
        try await document.save(try #require(document.unsavedEdits()), accepting: nil)
        let saved = try #require(PDFDocument(url: file)?.page(at: 0)).annotations.filter { $0.type == "Highlight" }
        let rgb = saved.compactMap { $0.color.usingColorSpace(.sRGB) }.map { [$0.redComponent, $0.greenComponent, $0.blueComponent] }
        let blue = try color("highlight-blue")
        #expect(rgb.count == 2)
        #expect(rgb.contains { abs($0[0] - 1) < 0.02 && abs($0[1] - 0.8) < 0.02 && $0[2] < 0.02 }, "yellow")
        #expect(rgb.contains { abs($0[0] - blue.red) < 0.02 && abs($0[1] - blue.green) < 0.02 && abs($0[2] - blue.blue) < 0.02 }, "blue")
    }

    @Test func thePeekPanelTakesNoColor() async throws {
        let document = try await open(try TempFile.makePDF(pages: 1), editable: false)
        #expect(!document.perform("highlight-green"))
        #expect(document.isOn("highlight-yellow") == true)
    }

    @Test func theColorIsRememberedForTheNextPDF() async throws {
        let scratch = ScratchDefaults()
        defer { scratch.close() }
        let first = try await open(try TempFile.makePDF(pages: 1), preferences: scratch.preferences("pdf"))
        #expect(first.perform("highlight-purple"))
        #expect(scratch.preferences("pdf").string("highlightColor") == "purple")
        let next = try await open(try TempFile.makePDF(pages: 1), preferences: scratch.preferences("pdf"))
        #expect(next.isOn("highlight-purple") == true)
        try selectAll(next)
        #expect(next.perform("highlight"))
        #expect(colors(next) == [try color("highlight-purple")])
    }

    @Test func anUnknownRememberedColorIsYellow() async throws {
        let scratch = ScratchDefaults()
        defer { scratch.close() }
        scratch.preferences("pdf").set("orange", for: "highlightColor")
        let document = try await open(try TempFile.makePDF(pages: 1), preferences: scratch.preferences("pdf"))
        #expect(document.isOn("highlight-yellow") == true)
    }
}
