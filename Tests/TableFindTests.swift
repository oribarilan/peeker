import AppKit
import PeekerKit
@testable import PeekerTable
import Testing

@Suite struct TableSearchMatching {
    private let table = CSVTable(text: "city,country\nZürich,CH\nBerlin,DE\nbern,CH\n", delimiter: .comma)

    @Test func containsIgnoringCaseAndAccents() {
        #expect(TableSearch.matches(of: "zurich", in: table) == [CellRef(row: 1, column: 0)])
        #expect(TableSearch.matches(of: "BER", in: table) == [CellRef(row: 2, column: 0), CellRef(row: 3, column: 0)])
    }

    @Test func theHeaderRowCounts() {
        #expect(TableSearch.matches(of: "count", in: table) == [CellRef(row: 0, column: 1)])
    }

    @Test func anEmptySearchMatchesNothing() {
        #expect(TableSearch.matches(of: "", in: table).isEmpty)
    }

    @Test func orderFollowsTheRowsShownWithTheHeaderFirst() {
        let found = [CellRef(row: 0, column: 1), CellRef(row: 1, column: 1), CellRef(row: 3, column: 0), CellRef(row: 3, column: 1)]
        let shown = [3, 1, 2]
        #expect(TableSearch.ordered(found, hasHeader: true, shownRows: shown)
            == [CellRef(row: 0, column: 1), CellRef(row: 3, column: 0), CellRef(row: 3, column: 1), CellRef(row: 1, column: 1)])
        #expect(TableSearch.ordered(found, hasHeader: true, shownRows: nil) == found)
    }
}

@MainActor private func shown(_ text: String) async throws -> (TableDocument, TableView, NSWindow) {
    let url = try TempFile.make(Data(text.utf8), name: "f.csv")
    let document = try await openDocument(url, with: TablePlugin.self, as: TableDocument.self)
    let view = try #require(document.contentView as? TableView)
    let window = offscreenWindow(holding: view)
    view.layoutSubtreeIfNeeded()
    return (document, view, window)
}

private func findItem(_ action: NSFindPanelAction) -> NSMenuItem {
    let item = NSMenuItem(title: "", action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: "")
    item.tag = Int(action.rawValue)
    return item
}

/// Waits for a search running in the background to finish.
@MainActor private func settle(_ view: TableView) async {
    for _ in 0..<200 where view.finder?.isSearching != false { try? await Task.sleep(for: .milliseconds(10)) }
}

@Suite(.serialized) struct TableFindBehavior {
    private let csv = "city,note\nBerlin,big\nParis,berlin trip\nRome,old\nberlin,again\n"

    @Test func cmdFShowsTheBarWithTheCursorInIt() async throws {
        let (document, view, window) = try await shown(csv)
        defer { window.close() }
        view.performFindPanelAction(findItem(.showFindPanel))
        let bar = try #require(view.findBar)
        #expect(!bar.isHidden)
        #expect(window.firstResponder is FindFieldEditor)
        withExtendedLifetime(document) {}
    }

    @Test func searchingTintsMatchesAndSelectsTheFirst() async throws {
        let (document, view, window) = try await shown(csv)
        defer { window.close() }
        view.performFindPanelAction(findItem(.showFindPanel))
        view.finder?.search("BERLIN")
        await settle(view)
        #expect(view.findBar?.status == "1 of 3")
        #expect(view.marks == [CellRef(row: 1, column: 0), CellRef(row: 2, column: 1), CellRef(row: 4, column: 0)])
        #expect(view.currentMark == CellRef(row: 1, column: 0))
        #expect(view.fileRow(view.tableView.selectedRow) == 1)
        view.performFindPanelAction(findItem(.next))
        #expect(view.findBar?.status == "2 of 3" && view.fileRow(view.tableView.selectedRow) == 2)
        view.performFindPanelAction(findItem(.previous))
        view.performFindPanelAction(findItem(.previous))
        #expect(view.findBar?.status == "3 of 3", "previous wraps around")
        withExtendedLifetime(document) {}
    }

    @Test func nothingFound() async throws {
        let (document, view, window) = try await shown(csv)
        defer { window.close() }
        view.performFindPanelAction(findItem(.showFindPanel))
        view.finder?.search("madrid")
        await settle(view)
        #expect(view.findBar?.status == "Not found" && view.marks.isEmpty)
        #expect(!view.validateMenuItem(findItem(.next)))
        withExtendedLifetime(document) {}
    }

    @Test func matchesFollowTheSort() async throws {
        let (document, view, window) = try await shown(csv)
        defer { window.close() }
        view.sortBy(column: 0, ascending: false)  // Rome, Paris, berlin, Berlin
        view.performFindPanelAction(findItem(.showFindPanel))
        view.finder?.search("berlin")
        await settle(view)
        #expect(view.finder?.matches == [CellRef(row: 2, column: 1), CellRef(row: 1, column: 0), CellRef(row: 4, column: 0)]
            || view.finder?.matches == [CellRef(row: 2, column: 1), CellRef(row: 4, column: 0), CellRef(row: 1, column: 0)])
        #expect(view.finder?.matches.first == CellRef(row: 2, column: 1), "Paris's row shows before both Berlins")
        withExtendedLifetime(document) {}
    }

    @Test func anEditSearchesAgainWithoutJumping() async throws {
        let (document, view, window) = try await shown(csv)
        defer { window.close() }
        view.performFindPanelAction(findItem(.showFindPanel))
        view.finder?.search("berlin")
        await settle(view)
        view.performFindPanelAction(findItem(.next))
        document.setCell("Paris", row: 1, column: 0)
        await settle(view)
        #expect(view.marks == [CellRef(row: 2, column: 1), CellRef(row: 4, column: 0)])
        #expect(view.findBar?.status.hasSuffix("of 2") == true)
        #expect(document.isEdited)
        withExtendedLifetime(document) {}
    }

    @Test func doneClosesTheBarAndClearsTheTints() async throws {
        let (document, view, window) = try await shown(csv)
        defer { window.close() }
        view.performFindPanelAction(findItem(.showFindPanel))
        view.finder?.search("berlin")
        await settle(view)
        view.findBar?.onAction?(.close)
        #expect(view.findBar?.isHidden == true && view.marks.isEmpty)
        #expect(window.firstResponder === view.tableView)
        #expect(!document.isEdited)
    }

    @Test func thePeekPanelHasNoFind() async throws {
        let url = try TempFile.make(Data(csv.utf8), name: "p.csv")
        let document = try await openDocument(url, with: TablePlugin.self, as: TableDocument.self, editing: false)
        let view = try #require(document.contentView as? TableView)
        let window = offscreenWindow(holding: view)
        defer { window.close() }
        #expect(!view.validateMenuItem(findItem(.showFindPanel)))
        view.performFindPanelAction(findItem(.showFindPanel))
        #expect(view.findBar == nil)
    }
}

@Suite(.serialized) struct TableHeaderFind {
    @Test func aMatchingTitleIsTinted() async throws {
        let (document, view, window) = try await shown("name,price\nTea,3\nCoffee,4\n")
        defer { window.close() }
        #expect(view.headerIsShown)
        view.performFindPanelAction(findItem(.showFindPanel))
        view.finder?.search("price")
        await settle(view)
        #expect(view.marks == [CellRef(row: 0, column: 1)] && view.findBar?.status == "1 of 1")
        let title = view.tableView.tableColumns[2].headerCell.attributedStringValue
        #expect(title.attribute(.backgroundColor, at: 0, effectiveRange: nil) != nil)
        view.findBar?.onAction?(.close)
        #expect(view.tableView.tableColumns[2].headerCell.attributedStringValue.attribute(.backgroundColor, at: 0, effectiveRange: nil) == nil)
        withExtendedLifetime(document) {}
    }
}

@Suite(.serialized) struct TablePrintJob {
    @Test func printsTheRowsShownWithUnsavedEditsAndKeepsChoices() async throws {
        let (document, view, window) = try await shown("name,price\nTea,3\nCoffee,4\nCocoa,5\n")
        defer { window.close() }
        document.setCell("Green tea", row: 1, column: 0)
        view.sortBy(column: 1, ascending: false)
        let job = try #require(document.printJob)
        let operation = try #require(job(NSPrintInfo()))
        let printed = try #require(operation.view as? TablePrintView)
        #expect(printed.content.rows == [3, 2, 1])
        #expect(printed.content.table.cell(row: 1, column: 0) == "Green tea")
        let options = try #require(operation.printPanel.accessoryControllers.first as? TablePrintOptions)
        options.onChange?(TablePrintChoices(showsRowNumbers: true, hiddenColumns: [1]))
        #expect(document.printChoices == TablePrintChoices(showsRowNumbers: true, hiddenColumns: [1]))
        let again = try #require(job(NSPrintInfo())?.view as? TablePrintView)
        #expect(again.choices == TablePrintChoices(showsRowNumbers: true, hiddenColumns: [1]))
    }
}
