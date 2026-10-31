import AppKit
import PDFKit
import PeekerKit
@testable import PeekerPDF
import Testing

private func open(_ texts: [String], allowsEditing: Bool = true) async throws -> PDFPluginDocument {
    let file = try TempFile.makePDF(texts: texts)
    return try await openDocument(file, with: PDFPlugin.self, as: PDFPluginDocument.self, editing: allowsEditing)
}

/// Puts the document's content view in a window, as the host does.
private func inWindow(_ document: PDFPluginDocument) -> NSWindow {
    document.contentView.autoresizingMask = [.width, .height]
    return offscreenWindow(holding: document.contentView)
}

private func container(_ document: PDFPluginDocument) throws -> PDFFindContainer {
    try #require(document.contentView as? PDFFindContainer)
}

private func menuItem(_ action: NSFindPanelAction) -> NSMenuItem {
    let item = NSMenuItem(title: "", action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: "")
    item.tag = Int(action.rawValue)
    return item
}

@MainActor private func search(_ finder: PDFFinder, _ text: String) async throws {
    finder.search(text)
    try await waitUntil(seconds: 5) { !finder.isSearching }
}

@Suite(.serialized) struct PDFFinding {
    @Test func findsEveryMatchAcrossPagesAndSelectsTheFirst() async throws {
        let document = try await open(["invoice one", "nothing here", "invoice two and invoice three"])
        let finder = try container(document).finder
        try await search(finder, "invoice")
        #expect(finder.matches.count == 3)
        #expect(finder.status == "1 of 3")
        #expect(document.pdfView.currentSelection?.string == "invoice")
        #expect(document.pdfView.currentSelection?.pages.first == document.pdfView.document?.page(at: 0))
        #expect(document.pdfView.highlightedSelections?.count == 3)
    }

    @Test func ignoresCaseAndAccents() async throws {
        let document = try await open(["Café au lait"])
        let finder = try container(document).finder
        try await search(finder, "cafe")
        #expect(finder.matches.count == 1)
        try await search(finder, "CAFÉ")
        #expect(finder.matches.count == 1)
    }

    @Test func saysNotFoundWithoutMatchesOrText() async throws {
        let blank = try await open([""])
        let blankFinder = try container(blank).finder
        try await search(blankFinder, "anything")
        #expect(blankFinder.status == "Not found")
        let document = try await open(["invoice"])
        let finder = try container(document).finder
        try await search(finder, "zzz")
        #expect(finder.status == "Not found")
        try await search(finder, "")
        #expect(finder.status == "" && finder.matches.isEmpty)
    }

    @Test func nextAndPreviousWrapAround() async throws {
        let document = try await open(["invoice one", "invoice two", "invoice three"])
        let finder = try container(document).finder
        try await search(finder, "invoice")
        finder.next()
        finder.next()
        #expect(finder.status == "3 of 3")
        #expect(document.pdfView.currentSelection?.pages.first == document.pdfView.document?.page(at: 2))
        finder.next()
        #expect(finder.status == "1 of 3")
        finder.previous()
        #expect(finder.status == "3 of 3")
    }

    @Test func searchingInEditModeAddsNoEdits() async throws {
        let document = try await open(["invoice one", "invoice two"])
        document.setEditing(true)
        let finder = try container(document).finder
        try await search(finder, "invoice")
        finder.next()
        #expect(finder.matches.count == 2)
        #expect(document.pendingEdits.isEmpty && document.unsavedEdits() == nil)
        #expect(document.undoManager.canUndo == false)
    }
}

@Suite(.serialized) struct PDFFindBarTests {
    @Test func cmdFShowsTheBarWithTheCursorInItsField() async throws {
        let document = try await open(["invoice"])
        let window = inWindow(document)
        defer { window.close() }
        let box = try container(document)
        #expect(box.validateMenuItem(menuItem(.showFindPanel)))
        box.performFindPanelAction(menuItem(.showFindPanel))
        let bar = try #require(box.bar)
        #expect(!bar.isHidden)
        #expect(bar.frame.minY >= document.pdfView.frame.maxY, "above the pages")
        #expect(window.firstResponder is FindFieldEditor)
    }

    @Test func findNextWorksFromTheFocusedField() async throws {
        let document = try await open(["invoice one", "invoice two"])
        let window = inWindow(document)
        defer { window.close() }
        let box = try container(document)
        box.performFindPanelAction(menuItem(.showFindPanel))
        try await search(box.finder, "invoice")
        let editor = try #require(window.firstResponder as? FindFieldEditor)
        #expect(editor.validateMenuItem(menuItem(.next)))
        #expect(editor.tryToPerform(#selector(NSTextView.performFindPanelAction(_:)), with: menuItem(.next)))
        #expect(box.finder.status == "2 of 2")
        #expect(editor.tryToPerform(#selector(NSTextView.performFindPanelAction(_:)), with: menuItem(.previous)))
        #expect(box.finder.status == "1 of 2")
    }

    @Test func fieldKeysStepAndClose() {
        #expect(PDFFindBar.action(for: #selector(NSResponder.insertNewline(_:)), shift: false) == .next)
        #expect(PDFFindBar.action(for: #selector(NSResponder.insertNewline(_:)), shift: true) == .previous)
        #expect(PDFFindBar.action(for: #selector(NSResponder.cancelOperation(_:)), shift: false) == .close)
        #expect(PDFFindBar.action(for: #selector(NSResponder.moveLeft(_:)), shift: false) == nil)
    }

    @Test func closingClearsHighlightsKeepsTheSelectionAndCmdGStillWorks() async throws {
        let document = try await open(["invoice one", "invoice two"])
        let window = inWindow(document)
        defer { window.close() }
        let box = try container(document)
        box.performFindPanelAction(menuItem(.showFindPanel))
        try await search(box.finder, "invoice")
        box.closeBar()
        #expect(box.bar?.isHidden != false)
        #expect(document.pdfView.highlightedSelections?.isEmpty != false)
        #expect(document.pdfView.currentSelection?.string == "invoice")
        #expect(window.firstResponder === document.pdfView)
        #expect(box.validateMenuItem(menuItem(.next)))
        box.performFindPanelAction(menuItem(.next))
        #expect(box.finder.status == "2 of 2")
        #expect(document.pdfView.currentSelection?.pages.first == document.pdfView.document?.page(at: 1))
    }

    @Test func findNextIsGreyedOutBeforeAnySearch() async throws {
        let document = try await open(["invoice"])
        #expect(try !container(document).validateMenuItem(menuItem(.next)))
    }

    @Test func theSpacePanelHasNoFind() async throws {
        let document = try await open(["invoice"], allowsEditing: false)
        #expect(try !container(document).validateMenuItem(menuItem(.showFindPanel)))
    }
}
