import AppKit
import PeekerKit
@testable import PeekerTable
import Testing

@Suite struct TableCopyText {
    private let rows = [["Tea", "Green, loose leaf"], ["Cake", "says \"hi\""]]

    @Test func tabsAndCommasWithAndWithoutTheHeader() {
        #expect(TableCopy.text(rows: [["Tea", "3.50"]], header: nil, format: .tabs) == "Tea\t3.50")
        #expect(TableCopy.text(rows: [["Tea", "3.50"]], header: ["name", "price"], format: .tabs) == "name\tprice\nTea\t3.50")
        #expect(TableCopy.text(rows: rows, header: nil, format: .commas) == "Tea,\"Green, loose leaf\"\nCake,\"says \"\"hi\"\"\"")
    }

    @Test func semicolonsQuoteOnlyWhatNeedsIt() {
        #expect(TableCopy.text(rows: rows, header: nil, format: .semicolons) == "Tea;Green, loose leaf\nCake;\"says \"\"hi\"\"\"")
    }

    @Test func aLineBreakOrTabIsQuotedInTheSeparatedFormats() {
        #expect(TableCopy.text(rows: [["a\nb", "c\td"]], header: nil, format: .tabs) == "\"a\nb\"\t\"c\td\"")
    }

    @Test func aMarkdownTableEscapesPipesAndFlattensLineBreaks() {
        #expect(TableCopy.text(rows: [["a|b"]], header: ["note"], format: .markdown) == "| note |\n| --- |\n| a\\|b |")
        #expect(TableCopy.text(rows: [["one\ntwo", "x"]], header: nil, format: .markdown) == "|  |  |\n| --- | --- |\n| one two | x |")
    }

    @Test func formatsHaveStableNamesForThePreferences() {
        #expect(TableCopy.Format.allCases.map(\.rawValue) == ["tabs", "commas", "semicolons", "markdown"])
        #expect(TableCopy.Format.allCases.map(\.title) == ["Tabs", "Commas", "Semicolons", "Markdown table"])
    }
}

private let prices = "name,price\nTea,3.50\nCake,4.20\nBread,2.80\n"

@MainActor private func shownTable(
    editing: Bool = true, preferences: PluginPreferences? = nil
) async throws -> (TableDocument, TableView, NSWindow, NSPasteboard) {
    let url = try TempFile.make(Data(prices.utf8), name: "p.csv")
    let document = try await openDocument(url, with: TablePlugin.self, as: TableDocument.self, editing: editing, preferences: preferences)
    let view = try #require(document.contentView as? TableView)
    let window = offscreenWindow(holding: view)
    view.layoutSubtreeIfNeeded()
    window.makeFirstResponder(view.tableView)
    let pasteboard = NSPasteboard(name: NSPasteboard.Name("peeker-test-\(UUID().uuidString)"))
    view.pasteboard = pasteboard
    return (document, view, window, pasteboard)
}

@MainActor private func copyItem() -> NSMenuItem { NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c") }

@Suite(.serialized) struct TableCopyInTheEditor {
    @Test func oneCellCopiesAtOnce() async throws {
        let (document, view, window, pasteboard) = try await shownTable()
        defer { window.close() }
        view.click(CellPosition(row: 1, column: 1), extending: false)  // Cake's price
        view.tableView.copy(nil)
        #expect(pasteboard.string(forType: .string) == "4.20" && window.attachedSheet == nil)
        withExtendedLifetime(document) {}
    }

    @Test func aSortedBlockIsGatheredInShownOrder() async throws {
        let (document, view, window, _) = try await shownTable()
        defer { window.close() }
        view.click(CellPosition(row: 0, column: 1), extending: false)
        view.cycleSort(1)  // by price: Bread, Tea, Cake
        view.click(CellPosition(row: 0, column: 0), extending: false)
        view.click(CellPosition(row: 1, column: 1), extending: true)
        let cells = view.selectedCells()
        #expect(cells.rows == [["Bread", "2.80"], ["Tea", "3.50"]] && cells.header == ["name", "price"])
        withExtendedLifetime(document) {}
    }

    @Test func aReadOnlyTableCopiesOnceACellIsSelected() async throws {
        let (document, view, window, pasteboard) = try await shownTable(editing: false)
        defer { window.close() }
        let grid = view.tableView
        #expect(!grid.validateUserInterfaceItem(copyItem()), "nothing is selected before a click")
        view.click(CellPosition(row: 0, column: 0), extending: false)
        #expect(grid.validateUserInterfaceItem(copyItem()))
        grid.copy(nil)
        #expect(pasteboard.string(forType: .string) == "Tea")
        withExtendedLifetime(document) {}
    }

    @Test func theRightClickMenusStartWithCopy() async throws {
        let (document, view, window, _) = try await shownTable()
        defer { window.close() }
        for menu in [view.tableView.menu, view.tableView.headerView?.menu] {
            let first = try #require(menu?.items.first)
            #expect(first.title == "Copy" && first.action == #selector(NSText.copy(_:)))
            #expect(menu?.items[1].isSeparatorItem == true)
        }
        withExtendedLifetime(document) {}
    }
}

@Suite(.serialized) struct TableCopySheetChoices {
    private let rows = [["Tea", "Green, loose leaf"], ["Cake", "Lemon"]]

    @Test func theFirstTimeItsTabsWithTheHeader() {
        let scratch = ScratchDefaults()
        defer { scratch.close() }
        let sheet = TableCopySheet(rows: rows, header: ["name", "note"], preferences: scratch.preferences("table"))
        #expect(sheet.format == .tabs && sheet.includesHeader)
        #expect(sheet.formatPopUp.titleOfSelectedItem == "Tabs" && sheet.headerBox?.state == .on)
        #expect(sheet.preview == "name\tnote\nTea\tGreen, loose leaf\nCake\tLemon")
    }

    @Test func copyingRemembersTheChoicesForNextTime() {
        let scratch = ScratchDefaults()
        defer { scratch.close() }
        let first = TableCopySheet(rows: rows, header: ["name", "note"], preferences: scratch.preferences("table"))
        first.choose(.commas)
        first.setIncludesHeader(false)
        #expect(first.preview == "Tea,\"Green, loose leaf\"\nCake,Lemon", "the preview follows the choices")
        #expect(first.copy() == "Tea,\"Green, loose leaf\"\nCake,Lemon")
        let next = TableCopySheet(rows: rows, header: ["name", "note"], preferences: scratch.preferences("table"))
        #expect(next.format == .commas && !next.includesHeader && next.formatPopUp.titleOfSelectedItem == "Commas")
    }

    @Test func thePreviewsTabsLineUpAsColumns() {
        let sheet = TableCopySheet(rows: rows, header: ["name", "note"], preferences: nil)
        let style = sheet.previewText.textStorage?.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        #expect(style?.defaultTabInterval == 88 && style?.tabStops.isEmpty == true)
        sheet.choose(.commas)
        let after = sheet.previewText.textStorage?.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        #expect(after?.defaultTabInterval == 88, "a new format keeps the stops")
    }

    @Test func withoutAHeaderRowThereIsNoCheckbox() {
        let sheet = TableCopySheet(rows: rows, header: nil, preferences: nil)
        #expect(sheet.headerBox == nil && sheet.copy() == "Tea\tGreen, loose leaf\nCake\tLemon")
    }

    @Test func thePreviewShowsTheFirstRowsOfALongCopy() {
        let many = (0..<100).map { ["\($0)"] }
        let sheet = TableCopySheet(rows: many, header: nil, preferences: nil)
        #expect(sheet.preview.split(separator: "\n").count == TableCopySheet.previewRows + 1)
        #expect(sheet.preview.hasSuffix("\n…") && sheet.copy().split(separator: "\n").count == 100)
    }

    @Test func severalCellsAskThroughTheSheetAndCancelCopiesNothing() async throws {
        let (document, view, window, pasteboard) = try await shownTable()
        defer { window.close() }
        pasteboard.clearContents()
        view.click(CellPosition(row: 0, column: 0), extending: false)
        view.click(CellPosition(row: 1, column: 1), extending: true)
        view.tableView.copy(nil)
        let sheet = try #require(window.attachedSheet)
        window.endSheet(sheet, returnCode: .alertSecondButtonReturn)
        try await waitUntil(seconds: 2) { window.attachedSheet == nil }
        #expect(pasteboard.string(forType: .string) == nil)
        withExtendedLifetime(document) {}
    }

    @Test func copyInTheSheetFillsThePasteboard() async throws {
        let scratch = ScratchDefaults()
        defer { scratch.close() }
        let (document, view, window, pasteboard) = try await shownTable(preferences: scratch.preferences("table"))
        defer { window.close() }
        view.click(CellPosition(row: 0, column: 0), extending: false)
        view.click(CellPosition(row: 1, column: 1), extending: true)
        view.tableView.copy(nil)
        let sheet = try #require(window.attachedSheet)
        window.endSheet(sheet, returnCode: .alertFirstButtonReturn)
        try await waitUntil(seconds: 2) { pasteboard.string(forType: .string) != nil }
        #expect(pasteboard.string(forType: .string) == "name\tprice\nTea\t3.50\nCake\t4.20")
        withExtendedLifetime(document) {}
    }
}
