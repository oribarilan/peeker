import Foundation

/// A cell as the table shows it: a shown row (after any sort) and a file column.
nonisolated struct CellPosition: Hashable, Sendable {
    var row: Int
    var column: Int
}

/// What's selected in a table, as spreadsheets do it: the current cell, which edits and moves, inside a block of
/// cells, whole rows, whole columns or everything. A block runs from the current cell to `edge`, the corner that
/// Shift-click and Shift-arrow move. Positions are in shown rows, so a sort collapses the selection.
nonisolated struct TableSelection: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case block
        case rows(IndexSet)
        case columns(IndexSet)
        case all
    }

    private(set) var current = CellPosition(row: 0, column: 0)
    private(set) var edge = CellPosition(row: 0, column: 0)
    private(set) var kind = Kind.block
    /// The table's size, which keeps every position in it.
    private(set) var rowCount: Int
    private(set) var columnCount: Int

    init(rows: Int = 0, columns: Int = 0) {
        rowCount = rows
        columnCount = columns
    }

    /// The shown rows the selection covers.
    var rows: IndexSet {
        guard rowCount > 0, columnCount > 0 else { return [] }
        switch kind {
        case .block: return IndexSet(integersIn: min(current.row, edge.row)...max(current.row, edge.row))
        case .rows(let rows): return rows
        case .columns, .all: return IndexSet(integersIn: 0..<rowCount)
        }
    }

    /// The columns the selection covers.
    var columns: IndexSet {
        guard rowCount > 0, columnCount > 0 else { return [] }
        switch kind {
        case .block: return IndexSet(integersIn: min(current.column, edge.column)...max(current.column, edge.column))
        case .columns(let columns): return columns
        case .rows, .all: return IndexSet(integersIn: 0..<columnCount)
        }
    }

    /// Just the current cell.
    var isSingleCell: Bool { kind == .block && current == edge }

    func contains(row: Int, column: Int) -> Bool {
        guard (0..<rowCount).contains(row), (0..<columnCount).contains(column) else { return false }
        switch kind {
        case .block:
            return (min(current.row, edge.row)...max(current.row, edge.row)).contains(row)
                && (min(current.column, edge.column)...max(current.column, edge.column)).contains(column)
        case .rows(let rows): return rows.contains(row)
        case .columns(let columns): return columns.contains(column)
        case .all: return true
        }
    }

    // MARK: Changing it

    /// A click on a cell makes it current; with Shift, the block grows from the current cell to it.
    mutating func click(_ cell: CellPosition, extending: Bool = false) {
        let cell = clamped(cell)
        if extending, kind == .block {
            edge = cell
        } else if extending {
            kind = .block
            edge = cell
        } else {
            collapse(to: cell)
        }
    }

    /// A click on a row number: that row; with Shift, the rows from the current cell's to it; with Command, that row
    /// added to or taken from the rows selected.
    mutating func clickRow(_ row: Int, extending: Bool = false, toggling: Bool = false) {
        guard rowCount > 0 else { return }
        let row = min(max(row, 0), rowCount - 1)
        if extending {
            kind = .rows(IndexSet(integersIn: min(current.row, row)...max(current.row, row)))
            edge = CellPosition(row: row, column: columnCount - 1)
        } else if toggling, case .rows(var rows) = kind {
            if rows.contains(row) { rows.remove(row) } else { rows.insert(row) }
            guard let first = rows.first else { return collapse(to: current) }
            kind = .rows(rows)
            if !rows.contains(current.row) { current = CellPosition(row: rows.contains(row) ? row : first, column: 0) }
        } else {
            current = CellPosition(row: row, column: 0)
            edge = CellPosition(row: row, column: columnCount - 1)
            kind = .rows([row])
        }
    }

    /// A click on a column title, as `clickRow` for rows.
    mutating func clickColumn(_ column: Int, extending: Bool = false, toggling: Bool = false) {
        guard columnCount > 0 else { return }
        let column = min(max(column, 0), columnCount - 1)
        if extending {
            kind = .columns(IndexSet(integersIn: min(current.column, column)...max(current.column, column)))
            edge = CellPosition(row: rowCount - 1, column: column)
        } else if toggling, case .columns(var columns) = kind {
            if columns.contains(column) { columns.remove(column) } else { columns.insert(column) }
            guard let first = columns.first else { return collapse(to: current) }
            kind = .columns(columns)
            if !columns.contains(current.column) { current = CellPosition(row: 0, column: columns.contains(column) ? column : first) }
        } else {
            current = CellPosition(row: 0, column: column)
            edge = CellPosition(row: max(rowCount - 1, 0), column: column)
            kind = .columns([column])
        }
    }

    /// An arrow or Tab: the current cell moves and the selection collapses to it; with Shift, the block's far corner
    /// moves instead. Whole rows grow up and down, whole columns left and right.
    mutating func move(rows: Int, columns: Int, extending: Bool = false) {
        guard extending else { return collapse(to: clamped(CellPosition(row: current.row + rows, column: current.column + columns))) }
        let next = clamped(CellPosition(row: edge.row + rows, column: edge.column + columns))
        switch kind {
        case .rows where columns == 0:
            edge = next
            kind = .rows(IndexSet(integersIn: min(current.row, next.row)...max(current.row, next.row)))
        case .columns where rows == 0:
            edge = next
            kind = .columns(IndexSet(integersIn: min(current.column, next.column)...max(current.column, next.column)))
        case .rows, .columns, .all:
            break
        case .block:
            edge = next
        }
    }

    mutating func selectAll() {
        guard rowCount > 0, columnCount > 0 else { return }
        kind = .all
    }

    /// Just `cell`, current.
    mutating func collapse(to cell: CellPosition) {
        current = clamped(cell)
        edge = current
        kind = .block
    }

    /// After the table changed size: positions stay inside it, and rows or columns past its end are dropped.
    mutating func resize(rows: Int, columns: Int) {
        rowCount = max(rows, 0)
        columnCount = max(columns, 0)
        current = clamped(current)
        edge = clamped(edge)
        switch kind {
        case .rows(let set):
            let kept = set.filteredIndexSet { $0 < rowCount }
            if kept.isEmpty { collapse(to: current) } else { kind = .rows(kept) }
        case .columns(let set):
            let kept = set.filteredIndexSet { $0 < columnCount }
            if kept.isEmpty { collapse(to: current) } else { kind = .columns(kept) }
        case .block, .all:
            break
        }
    }

    private func clamped(_ cell: CellPosition) -> CellPosition {
        CellPosition(row: min(max(cell.row, 0), max(rowCount - 1, 0)), column: min(max(cell.column, 0), max(columnCount - 1, 0)))
    }
}
