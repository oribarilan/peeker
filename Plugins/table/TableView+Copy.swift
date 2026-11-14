import AppKit

/// Copying the selected cells: one at once, more through the copy sheet.
extension TableView {
    /// Whether Copy has something to copy: a selection the table shows, in the panel only after a click.
    var canCopy: Bool { showsSelection && numberOfRows(in: tableView) > 0 && table.columnCount > 0 }

    /// The selected cells as the table shows them: rows in shown order, the selected columns in order, and the
    /// columns' titles when the header row is shown.
    func selectedCells() -> (rows: [[String]], header: [String]?) {
        let columns = Array(selection.columns)
        let rows = selection.rows.map { row in
            let fields = table.fields(ofRow: fileRow(row))
            return columns.map { $0 < fields.count ? fields[$0].text : "" }
        }
        return (rows, headerIsShown ? columns.map { table.cell(row: 0, column: $0) } : nil)
    }

    func copySelection() {
        guard canCopy else { return }
        if selection.isSingleCell {
            let current = selection.current
            return write(table.cell(row: fileRow(current.row), column: current.column))
        }
        guard let window, window.attachedSheet == nil else { return }
        let cells = selectedCells()
        let sheet = TableCopySheet(rows: cells.rows, header: cells.header, preferences: document?.preferences)
        sheet.begin(on: window) { [weak self] text in self?.write(text) }
    }

    private func write(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
