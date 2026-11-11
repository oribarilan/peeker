import AppKit

/// The selection on screen: what clicks and keys do to it, and drawing it in the visible cells and the titles.
extension TableView {
    /// A cell's tint and ring; a row number is tinted when the selection covers its row. `column` is nil for row numbers.
    func showSelection(in cell: CellView, row: Int, column: Int?) {
        cell.isActive = isActive
        guard showsSelection else {
            cell.isSelected = false
            cell.isCurrent = false
            return
        }
        if let column {
            cell.isCurrent = selection.current == CellPosition(row: row, column: column)
            cell.isSelected = !selection.isSingleCell && selection.contains(row: row, column: column)
        } else {
            cell.isCurrent = false
            cell.isSelected = selection.rows.contains(row)
        }
    }

    /// Keys go to the table now, so the selection shows in color rather than grey.
    var isActive: Bool {
        guard let window, window.isKeyWindow else { return false }
        return window.firstResponder === tableView || editing != nil
    }

    func click(_ cell: CellPosition, extending: Bool) {
        showsSelection = true
        selection.click(cell, extending: extending)
        selectionChanged(scrolling: false)
    }

    func clickRow(_ row: Int, extending: Bool, toggling: Bool) {
        showsSelection = true
        selection.clickRow(row, extending: extending, toggling: toggling)
        selectionChanged(scrolling: false)
    }

    func clickColumn(_ column: Int, extending: Bool, toggling: Bool) {
        showsSelection = true
        selection.clickColumn(column, extending: extending, toggling: toggling)
        selectionChanged(scrolling: false)
    }

    func move(rows: Int, columns: Int, extending: Bool = false) {
        showsSelection = true
        selection.move(rows: rows, columns: columns, extending: extending)
        selectionChanged()
    }

    func selectAll() {
        showsSelection = true
        selection.selectAll()
        selectionChanged(scrolling: false)
    }

    /// Makes `cell` current alone and scrolls to it.
    func select(_ cell: CellPosition) {
        selection.collapse(to: cell)
        selectionChanged()
    }

    /// Redraws the visible cells' selection and the titles' tints, and scrolls the cell that moved into view: the
    /// current cell, or the far corner while a block grows.
    func selectionChanged(scrolling: Bool = true) {
        syncRowSelection()
        let visible = tableView.rows(in: tableView.visibleRect)
        for row in visible.location..<visible.location + visible.length {
            for index in 0..<tableView.numberOfColumns {
                guard let cell = tableView.view(atColumn: index, row: row, makeIfNecessary: false) as? CellView else { continue }
                showSelection(in: cell, row: row, column: index == 0 ? nil : index - 1)
            }
        }
        updateTitleTints()
        guard scrolling, numberOfRows(in: tableView) > 0 else { return }
        let target = selection.isSingleCell || selection.kind != .block ? selection.current : selection.edge
        tableView.scrollRowToVisible(target.row)
        tableView.scrollColumnToVisible(target.column + 1)
    }

    /// AppKit's row selection follows whole rows selected, so dragging a row number moves the rows it should.
    func syncRowSelection() {
        let rows: IndexSet = if case .rows(let rows) = selection.kind { rows } else { [] }
        if tableView.selectedRowIndexes != rows { tableView.selectRowIndexes(rows, byExtendingSelection: false) }
    }

    func updateTitleTints() {
        let columns = showsSelection ? selection.columns : []
        for (index, column) in tableView.tableColumns.dropFirst().enumerated() {
            (column.headerCell as? TableHeaderCell)?.isTinted = columns.contains(index)
        }
        header.needsDisplay = true
    }

}
