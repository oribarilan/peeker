import AppKit
import PeekerKit
@testable import PeekerTable
import Testing

private let long = String(repeating: "a long note that goes on ", count: 12)
private let prices = "name,price,notes\nTea,2.50,short\nCake,3.50,\(long)\nBread,12,x\n"

@MainActor private func shown(_ text: String = prices) async throws -> (TableDocument, TableView, NSWindow) {
    let url = try TempFile.make(Data(text.utf8), name: "c.csv")
    let document = try await openDocument(url, with: TablePlugin.self, as: TableDocument.self)
    let view = try #require(document.contentView as? TableView)
    let window = offscreenWindow(holding: view)
    view.layoutSubtreeIfNeeded()
    window.makeFirstResponder(view.tableView)
    return (document, view, window)
}

@MainActor private func width(_ view: TableView, _ column: Int) -> CGFloat { view.tableView.tableColumns[column + 1].width }

@MainActor private func cell(_ view: TableView, row: Int, column: Int) -> CellView? {
    view.tableView.view(atColumn: column + 1, row: row, makeIfNecessary: true) as? CellView
}

/// A click in the middle of a cell (or a row number, with column -1), with its mouse-up already queued.
@MainActor private func click(_ view: TableView, row: Int, column: Int, count: Int = 1, modifiers: NSEvent.ModifierFlags = [], in window: NSWindow) {
    let frame = view.tableView.frameOfCell(atColumn: column + 1, row: row)
    let point = view.tableView.convert(NSPoint(x: frame.midX, y: frame.midY), to: nil)
    func event(_ type: NSEvent.EventType) -> NSEvent {
        NSEvent.mouseEvent(
            with: type, location: point, modifierFlags: modifiers, timestamp: 0, windowNumber: window.windowNumber,
            context: nil, eventNumber: 0, clickCount: count, pressure: 1)!
    }
    window.postEvent(event(.leftMouseUp), atStart: false)
    view.tableView.mouseDown(with: event(.leftMouseDown))
}

@MainActor private func press(_ view: TableView, _ character: String, code: UInt16, modifiers: NSEvent.ModifierFlags = [], in window: NSWindow) {
    let event = key(character, code: code, in: window, modifiers: modifiers)
    if let editor = window.firstResponder as? NSTextView { editor.keyDown(with: event) } else { view.tableView.keyDown(with: event) }
}

private let right = (character: String(UnicodeScalar(NSRightArrowFunctionKey)!), code: UInt16(124))
private let down = (character: String(UnicodeScalar(NSDownArrowFunctionKey)!), code: UInt16(125))

@Suite(.serialized) struct TableFitting {
    @Test func columnsFitTheirContentUpToTheCap() async throws {
        let (document, view, window) = try await shown()
        defer { window.close() }
        #expect(width(view, 0) < 120 && width(view, 1) < 120)
        #expect(width(view, 2) == 320)
        withExtendedLifetime(document) {}
    }

    @Test func zoomScalesTheWidths() async throws {
        let (document, view, window) = try await shown()
        defer { window.close() }
        let before = width(view, 2)
        document.setZoom(200, around: nil)
        #expect(abs(width(view, 2) - before * 2) < 1)
    }

    @Test func numberColumnsAlignRight() async throws {
        let (document, view, window) = try await shown()
        defer { window.close() }
        #expect(cell(view, row: 0, column: 1)?.alignsRight == true && cell(view, row: 0, column: 0)?.alignsRight == false)
        #expect(view.tableView.tableColumns[2].headerCell.alignment == .right)
        withExtendedLifetime(document) {}
    }

    @Test func turningTheHeaderOffChangesWhatsNumeric() async throws {
        let (document, view, window) = try await shown("price\n2\n3\n")
        defer { window.close() }
        #expect(view.isNumeric(0))
        #expect(document.perform("header-row"))
        #expect(!view.isNumeric(0))
    }

    @Test func doubleClickingADividerFitsAgain() async throws {
        let (document, view, window) = try await shown()
        defer { window.close() }
        let fitted = width(view, 0)
        view.tableView.tableColumns[1].width = 30
        #expect(view.tableView(view.tableView, sizeToFitWidthOfColumn: 1) == fitted)
        withExtendedLifetime(document) {}
    }
}

@Suite(.serialized) struct TableCellSelection {
    @Test func theFirstCellStartsCurrentWithItsRing() async throws {
        let (document, view, window) = try await shown()
        defer { window.close() }
        #expect(view.selection.current == CellPosition(row: 0, column: 0))
        #expect(cell(view, row: 0, column: 0)?.isCurrent == true && cell(view, row: 0, column: 1)?.isCurrent == false)
        withExtendedLifetime(document) {}
    }

    @Test func aClickAndAShiftClickSelectABlockThatTheCellsShow() async throws {
        let (document, view, window) = try await shown()
        defer { window.close() }
        click(view, row: 0, column: 0, in: window)
        click(view, row: 2, column: 1, modifiers: .shift, in: window)
        #expect(view.selection.rows == IndexSet(0...2) && view.selection.columns == IndexSet(0...1))
        #expect(cell(view, row: 1, column: 1)?.isSelected == true && cell(view, row: 1, column: 2)?.isSelected == false)
        withExtendedLifetime(document) {}
    }

    @Test func aRowNumberClickSelectsTheRow() async throws {
        let (document, view, window) = try await shown()
        defer { window.close() }
        click(view, row: 1, column: -1, in: window)
        #expect(view.selection.kind == .rows([1]) && view.selectedFileRows == [2])
        withExtendedLifetime(document) {}
    }

    @Test func aTitleClickSelectsTheColumnWithoutSorting() async throws {
        let (document, view, window) = try await shown()
        defer { window.close() }
        view.tableView(view.tableView, didClick: view.tableView.tableColumns[2])
        #expect(view.selection.kind == .columns([1]) && view.order == nil)
        withExtendedLifetime(document) {}
    }

    @Test func arrowsTabAndShiftArrowsMove() async throws {
        let (document, view, window) = try await shown()
        defer { window.close() }
        press(view, right.character, code: right.code, in: window)
        press(view, down.character, code: down.code, in: window)
        #expect(view.selection.current == CellPosition(row: 1, column: 1))
        press(view, "\t", code: 48, in: window)
        press(view, "\t", code: 48, in: window)
        #expect(view.selection.current == CellPosition(row: 1, column: 2))
        press(view, down.character, code: down.code, modifiers: .shift, in: window)
        #expect(view.selection.rows == IndexSet(1...2) && view.selection.current == CellPosition(row: 1, column: 2))
        withExtendedLifetime(document) {}
    }

    @Test func selectAllCoversTheTable() async throws {
        let (document, view, window) = try await shown()
        defer { window.close() }
        view.tableView.selectAll(nil)
        #expect(view.selection.kind == .all && view.selectedFileRows == IndexSet(1...3))
        withExtendedLifetime(document) {}
    }
}

@Suite(.serialized) struct TableCellKeys {
    @Test func typingReplacesTheCellAndReturnMovesDownWithoutEditing() async throws {
        let (document, view, window) = try await shown()
        defer { window.close() }
        for (character, code) in [("C", UInt16(8)), ("a", 0), ("k", 40), ("e", 14)] { press(view, character, code: code, in: window) }
        press(view, "\r", code: 36, in: window)
        #expect(document.table.cell(row: 1, column: 0) == "Cake")
        #expect(view.selection.current == CellPosition(row: 1, column: 0) && view.editor.superview == nil)
        #expect(document.isEdited)
    }

    @Test func escapeKeepsTheOldText() async throws {
        let (document, view, window) = try await shown()
        defer { window.close() }
        press(view, "X", code: 7, in: window)
        press(view, "\u{1b}", code: 53, in: window)
        #expect(document.table.cell(row: 1, column: 0) == "Tea" && !document.isEdited && view.editor.superview == nil)
    }

    @Test func doubleClickEditsWithTheCellsText() async throws {
        let (document, view, window) = try await shown()
        defer { window.close() }
        click(view, row: 1, column: 0, count: 2, in: window)
        #expect(view.editor.superview === view.tableView && view.editor.stringValue == "Cake")
        withExtendedLifetime(document) {}
    }

    @Test func deleteClearsTheBlockAsOneUndo() async throws {
        let (document, view, window) = try await shown()
        defer { window.close() }
        click(view, row: 0, column: 0, in: window)
        click(view, row: 1, column: 1, modifiers: .shift, in: window)
        press(view, "\u{7f}", code: 51, in: window)
        #expect((1...2).allSatisfy { row in (0...1).allSatisfy { document.table.cell(row: row, column: $0).isEmpty } })
        #expect(document.table.cell(row: 1, column: 2) == "short")
        document.undoManager.undo()
        #expect(document.table.cell(row: 1, column: 0) == "Tea" && document.table.cell(row: 2, column: 1) == "3.50")
    }

    @Test func deletingEmptyCellsIsNoEdit() async throws {
        let (document, view, window) = try await shown("a,b\n,\n1,2\n")
        defer { window.close() }
        press(view, "\u{7f}", code: 51, in: window)
        #expect(!document.isEdited)
    }

    @Test func aReadOnlyTableIgnoresDeleteAndTyping() async throws {
        let url = try TempFile.make(Data(prices.utf8), name: "r.csv")
        let document = try await openDocument(url, with: TablePlugin.self, as: TableDocument.self, editing: false)
        let view = try #require(document.contentView as? TableView)
        let window = offscreenWindow(holding: view)
        defer { window.close() }
        press(view, "\u{7f}", code: 51, in: window)
        press(view, "X", code: 7, in: window)
        #expect(document.table.cell(row: 1, column: 0) == "Tea" && view.editor.superview == nil)
    }
}

@Suite(.serialized) struct TableSelectionEdits {
    @Test func deleteColumnsRemovesTheSelectedColumnsInOneUndo() async throws {
        let (document, view, window) = try await shown()
        defer { window.close() }
        view.clickColumn(0, extending: false, toggling: false)
        view.clickColumn(2, extending: false, toggling: true)
        #expect(document.perform("delete-columns"))
        #expect(document.table.serialized(lineEnding: "\n").hasPrefix("price\n2.50\n"))
        document.undoManager.undo()
        #expect(document.table.columnCount == 3 && document.table.cell(row: 0, column: 2) == "notes")
    }

    @Test func deleteRowsRemovesTheRowsABlockCovers() async throws {
        let (document, view, window) = try await shown()
        defer { window.close() }
        view.click(CellPosition(row: 0, column: 1), extending: false)
        view.click(CellPosition(row: 1, column: 2), extending: true)
        #expect(document.perform("delete-rows"))
        #expect(document.table.rowCount == 2 && document.table.cell(row: 1, column: 0) == "Bread")
    }

    @Test func theSortToolsSortByTheCurrentColumnWithoutEditing() async throws {
        let (document, view, window) = try await shown()
        defer { window.close() }
        view.click(CellPosition(row: 0, column: 0), extending: false)
        #expect(document.perform("sort-descending"))
        #expect((0..<3).map(view.fileRow) == [1, 2, 3])  // Tea, Cake, Bread by name, Z to A
        #expect(document.perform("sort-ascending"))
        #expect((0..<3).map(view.fileRow) == [3, 2, 1])
        #expect(document.perform("sort-none"))
        #expect(view.order == nil && !document.isEdited)
    }

    @Test func sortingKeepsTheCurrentCellOnItsRow() async throws {
        let (document, view, window) = try await shown()
        defer { window.close() }
        view.click(CellPosition(row: 0, column: 1), extending: false)  // Tea's price
        view.cycleSort(1)
        #expect(view.fileRow(view.selection.current.row) == 1 && view.selection.isSingleCell)
        withExtendedLifetime(document) {}
    }

    @Test func aClickOnTheArrowSortsAndElsewhereDoesNot() async throws {
        let (document, view, window) = try await shown()
        defer { window.close() }
        let header = view.header
        let rect = header.headerRect(ofColumn: 2)
        view.tableView.setIndicatorImage(TableView.hoverArrow, in: view.tableView.tableColumns[2])
        let arrow = view.tableView.tableColumns[2].headerCell.sortIndicatorRect(forBounds: rect)
        #expect(header.isOnArrow(NSPoint(x: arrow.midX, y: arrow.midY), column: 2))
        #expect(!header.isOnArrow(NSPoint(x: rect.minX + 4, y: rect.midY), column: 2))
        withExtendedLifetime(document) {}
    }
}
