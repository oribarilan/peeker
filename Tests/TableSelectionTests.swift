import Foundation
@testable import PeekerTable
import Testing

private func cell(_ row: Int, _ column: Int) -> CellPosition { CellPosition(row: row, column: column) }

@Suite struct TableSelections {
    @Test func startsAtTheFirstCellAlone() {
        let s = TableSelection(rows: 5, columns: 3)
        #expect(s.current == cell(0, 0) && s.isSingleCell)
        #expect(s.rows == [0] && s.columns == [0])
    }

    @Test func aClickMakesACellCurrentAndShiftClickMakesABlock() {
        var s = TableSelection(rows: 5, columns: 3)
        s.click(cell(1, 0))
        s.click(cell(3, 2), extending: true)
        #expect(s.current == cell(1, 0))
        #expect(s.rows == IndexSet(1...3) && s.columns == IndexSet(0...2))
        #expect(s.contains(row: 2, column: 1) && !s.contains(row: 4, column: 1))
    }

    @Test func aRowClickSelectsTheRowAndShiftExtends() {
        var s = TableSelection(rows: 5, columns: 3)
        s.clickRow(1)
        #expect(s.current == cell(1, 0) && s.rows == [1] && s.columns == IndexSet(0..<3))
        s.clickRow(3, extending: true)
        #expect(s.rows == IndexSet(1...3) && s.current == cell(1, 0))
    }

    @Test func commandClickAddsAndRemovesRows() {
        var s = TableSelection(rows: 5, columns: 3)
        s.clickRow(1)
        s.clickRow(3, toggling: true)
        #expect(s.rows == [1, 3])
        s.clickRow(1, toggling: true)
        #expect(s.rows == [3] && s.current.row == 3)
    }

    @Test func aColumnClickSelectsTheColumnWithItsFirstCellCurrent() {
        var s = TableSelection(rows: 5, columns: 3)
        s.clickColumn(2)
        #expect(s.current == cell(0, 2) && s.columns == [2] && s.rows == IndexSet(0..<5))
        s.clickColumn(0, extending: true)
        #expect(s.columns == IndexSet(0...2))
        s.clickColumn(1, toggling: true)
        #expect(s.columns == [0, 2])
    }

    @Test func arrowsMoveAndStopAtTheEdges() {
        var s = TableSelection(rows: 3, columns: 2)
        s.move(rows: 0, columns: 1)
        s.move(rows: 1, columns: 0)
        #expect(s.current == cell(1, 1))
        s.move(rows: 0, columns: 1)
        #expect(s.current == cell(1, 1))
        s.move(rows: -5, columns: 0)
        #expect(s.current == cell(0, 1))
    }

    @Test func shiftArrowsGrowAndShrinkTheBlock() {
        var s = TableSelection(rows: 5, columns: 3)
        s.move(rows: 1, columns: 0, extending: true)
        s.move(rows: 1, columns: 0, extending: true)
        #expect(s.rows == IndexSet(0...2) && s.current == cell(0, 0))
        s.move(rows: -1, columns: 0, extending: true)
        #expect(s.rows == IndexSet(0...1))
        s.move(rows: 0, columns: 0)
        #expect(s.isSingleCell)
    }

    @Test func shiftArrowsGrowWholeRows() {
        var s = TableSelection(rows: 5, columns: 3)
        s.clickRow(1)
        s.move(rows: 1, columns: 0, extending: true)
        #expect(s.rows == IndexSet(1...2) && s.columns == IndexSet(0..<3))
    }

    @Test func selectAllCoversEveryCell() {
        var s = TableSelection(rows: 4, columns: 3)
        s.selectAll()
        #expect(s.rows == IndexSet(0..<4) && s.columns == IndexSet(0..<3) && s.contains(row: 3, column: 2))
    }

    @Test func shrinkingTheTableKeepsPositionsInside() {
        var s = TableSelection(rows: 5, columns: 3)
        s.clickRow(4)
        s.clickRow(2, toggling: true)
        s.resize(rows: 3, columns: 3)
        #expect(s.rows == [2] && s.current.row <= 2)
        s.click(cell(2, 2))
        s.resize(rows: 1, columns: 1)
        #expect(s.current == cell(0, 0))
    }

    @Test func anEmptyTableSelectsNothing() {
        var s = TableSelection(rows: 0, columns: 0)
        s.selectAll()
        #expect(s.rows.isEmpty && s.columns.isEmpty && !s.contains(row: 0, column: 0))
    }
}
