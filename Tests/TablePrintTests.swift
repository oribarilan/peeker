import AppKit
@testable import PeekerTable
import Testing

private func content(_ text: String, hasHeader: Bool = true, rows: [Int]? = nil) -> TablePrintContent {
    let table = CSVTable(text: text, delimiter: .comma)
    let offset = hasHeader ? 1 : 0
    return TablePrintContent(table: table, hasHeader: hasHeader, rows: rows ?? Array(offset..<table.rowCount))
}

private func letterInfo() -> NSPrintInfo {
    let info = NSPrintInfo()
    info.paperSize = NSSize(width: 612, height: 792)
    info.leftMargin = 36; info.rightMargin = 36; info.topMargin = 36; info.bottomMargin = 36
    return info
}

@MainActor private func printView(_ content: TablePrintContent, _ choices: TablePrintChoices = .init()) -> TablePrintView {
    TablePrintView(content: content, choices: choices, info: letterInfo())
}

@Suite struct TablePrintLayoutTests {
    @Test func aTableTwiceThePageWidthPrintsAtHalfSize() {
        let layout = TablePrintLayout(widths: [300, 300, 300, 300], page: CGSize(width: 600, height: 800), rowCount: 10, repeatsHeader: true)
        #expect(abs(layout.scale - 0.5) < 0.001)
    }

    @Test func aNarrowTableIsntEnlarged() {
        let layout = TablePrintLayout(widths: [50, 80], page: CGSize(width: 600, height: 800), rowCount: 10, repeatsHeader: true)
        #expect(layout.scale == 1)
    }

    @Test func pagesHoldWholeRowsUnderTheHeader() {
        let layout = TablePrintLayout(widths: [100], page: CGSize(width: 600, height: 800), rowCount: 500, repeatsHeader: true)
        #expect(layout.rowsPerPage == 49)  // 800 / 16 lines, one of them the header
        #expect(layout.pageCount == 11)
        #expect(layout.rows(onPage: 0) == 0..<49 && layout.rows(onPage: 10) == 490..<500)
    }

    @Test func shrinkingFitsMoreRowsOnAPage() {
        let layout = TablePrintLayout(widths: [1200], page: CGSize(width: 600, height: 800), rowCount: 500, repeatsHeader: false)
        #expect(layout.rowsPerPage == 100)
    }
}

@Suite(.serialized) @MainActor struct TablePrintViewTests {
    @Test func aLongTableRepeatsItsHeaderOnEveryPageAndKeepsTheOrder() {
        let text = "name,n\n" + (1...500).map { "row\($0),\($0)" }.joined(separator: "\n")
        let view = printView(content(text))
        let layout = view.layout
        #expect(layout.pageCount == (500 + layout.rowsPerPage - 1) / layout.rowsPerPage && layout.pageCount > 1)
        var printed: [String] = []
        for page in 0..<layout.pageCount {
            let lines = view.lines(onPage: page)
            #expect(lines.first == TablePrintView.Line(texts: ["name", "n"], isHeader: true))
            printed += lines.dropFirst().map { $0.texts[0] }
        }
        #expect(printed == (1...500).map { "row\($0)" })
        #expect(view.frame.height == layout.page.height * CGFloat(layout.pageCount))
    }

    @Test func withoutAHeaderRowNothingRepeats() {
        let view = printView(content("a,b\nc,d\n", hasHeader: false))
        #expect(view.lines(onPage: 0) == [.init(texts: ["a", "b"], isHeader: false), .init(texts: ["c", "d"], isHeader: false)])
    }

    @Test func aWideTableShrinksToThePageWidth() {
        let wide = String(repeating: "w", count: 120)
        let view = printView(content((0..<6).map { _ in wide }.joined(separator: ",") + "\n1,2,3,4,5,6\n"))
        #expect(view.layout.widths == [300, 300, 300, 300, 300, 300])
        #expect(abs(view.layout.scale - 540.0 / 1800) < 0.001)
    }

    @Test func hiddenColumnsAreLeftOut() {
        let view = printView(content("a,b,c\n1,2,3\n"), TablePrintChoices(hiddenColumns: [1, 9]))
        #expect(view.lines(onPage: 0).map(\.texts) == [["a", "c"], ["1", "3"]])
        #expect(view.layout.widths.count == 2)
        view.choices = TablePrintChoices()
        #expect(view.lines(onPage: 0).map(\.texts) == [["a", "b", "c"], ["1", "2", "3"]])
    }

    @Test func rowNumbersPrintFirstOnlyWhenOn() {
        let sorted = content("h\nz\nx\ny\n", rows: [2, 3, 1])
        #expect(printView(sorted).lines(onPage: 0).map(\.texts) == [["h"], ["x"], ["y"], ["z"]])
        let numbered = printView(sorted, TablePrintChoices(showsRowNumbers: true))
        #expect(numbered.lines(onPage: 0).map(\.texts) == [["", "h"], ["2", "x"], ["3", "y"], ["1", "z"]])
        #expect(numbered.layout.widths.count == 2)
    }

    @Test func theJobHasTheTableSectionAndTheSystemHeader() throws {
        var changes: [TablePrintChoices] = []
        let info = letterInfo()
        let job = TablePrinting.job(content("a,b\n1,2\n"), choices: TablePrintChoices(), info: info) { changes.append($0) }
        let options = try #require(job.printPanel.accessoryControllers.first as? TablePrintOptions)
        #expect(info.dictionary()[NSPrintInfo.AttributeKey.headerAndFooter] as? Bool == true)
        options.rowNumbers.performClick(nil)
        #expect(changes == [TablePrintChoices(showsRowNumbers: true)])
        #expect((job.view as? TablePrintView)?.choices.showsRowNumbers == true)
    }
}

@Suite(.serialized) @MainActor struct TablePrintOptionsTests {
    @Test func columnsAreNamedByTheHeaderRowOrNumbered() {
        let named = content("name,,price\n1,2,3\n")
        #expect((0..<3).map(named.title(ofColumn:)) == ["name", "Column 2", "price"])
        let plain = content("a,b\n", hasHeader: false)
        #expect((0..<2).map(plain.title(ofColumn:)) == ["Column 1", "Column 2"])
    }

    @Test func theChoicesPassedInShow() {
        let options = TablePrintOptions(titles: ["a", "b", "c"], choices: TablePrintChoices(showsRowNumbers: true, hiddenColumns: [2, 7]))
        #expect(options.rowNumbers.state == .on)
        #expect(options.columnBoxes.map(\.state) == [.on, .on, .off])
        #expect(options.choices.hiddenColumns == [2])
        #expect(options.columnBoxes.map(\.title) == ["a", "b", "c"])
    }

    @Test func theLastCheckedColumnCantBeUnchecked() {
        let options = TablePrintOptions(titles: ["a", "b", "c"], choices: TablePrintChoices())
        var changes: [TablePrintChoices] = []
        options.onChange = { changes.append($0) }
        options.columnBoxes[0].performClick(nil)
        options.columnBoxes[1].performClick(nil)
        #expect(options.choices.hiddenColumns == [0, 1] && changes.count == 2 && options.choicesVersion == 2)
        #expect(!options.columnBoxes[2].isEnabled && options.columnBoxes[0].isEnabled)
        options.columnBoxes[2].performClick(nil)
        #expect(options.choices.hiddenColumns == [0, 1] && options.columnBoxes[2].state == .on)
        options.columnBoxes[0].performClick(nil)
        #expect(options.choices.hiddenColumns == [1] && options.columnBoxes[2].isEnabled)
    }

    @Test func everyColumnHiddenShowsThemAll() {
        let options = TablePrintOptions(titles: ["a", "b"], choices: TablePrintChoices(hiddenColumns: [0, 1]))
        #expect(options.choices.hiddenColumns.isEmpty)
        #expect(content("a,b\n").printedColumns(TablePrintChoices(hiddenColumns: [0, 1])) == [0, 1])
    }

    @Test func thePreviewFollowsTheVersion() {
        let options = TablePrintOptions(titles: ["a"], choices: TablePrintChoices())
        #expect(options.keyPathsForValuesAffectingPreview() == ["choicesVersion"])
        #expect(options.localizedSummaryItems().last?[.itemDescription] == "1 of 1")
        options.loadView()
        #expect(options.view.frame.width > 0 && options.view.frame.height > 0)
    }
}
