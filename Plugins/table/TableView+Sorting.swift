import AppKit

/// Sorting through the titles' arrows and the sort tools, and selecting a column by its title.
extension TableView {
    /// A click on a title away from its arrow selects the column; Shift extends and Command adds or removes.
    func tableView(_ tableView: NSTableView, didClick tableColumn: NSTableColumn) {
        guard let column = Int(tableColumn.identifier.rawValue) else { return }
        let flags = NSApp.currentEvent?.modifierFlags ?? []
        window?.makeFirstResponder(tableView)
        clickColumn(column, extending: flags.contains(.shift), toggling: flags.contains(.command))
    }

    /// The title's arrow: ascending, descending, then file order again.
    func cycleSort(_ column: Int) {
        switch sort {
        case (column, true)?: sortBy(column: column, ascending: false)
        case (column, false)?: sortBy(column: nil)
        default: sortBy(column: column, ascending: true)
        }
    }

    /// Sorts by `column`, or back to file order with nil. The current cell stays on its file row.
    func sortBy(column: Int?, ascending: Bool = true) {
        commitEditing()
        let current = numberOfRows(in: tableView) > 0 ? fileRow(selection.current.row) : nil
        sort = column.map { ($0, ascending) }
        if column == nil { order = nil }
        reloadAll()
        if let current {
            let row = order?.firstIndex(of: current) ?? current - headerOffset
            select(CellPosition(row: row, column: selection.current.column))
        }
    }

    func hoveredTitleChanged() { updateArrows() }

    /// The sorted column's arrow, and a dimmed one on the title under the pointer.
    func updateArrows() {
        for (index, column) in tableView.tableColumns.dropFirst().enumerated() {
            let arrow: NSImage? = if let sort, sort.column == index {
                NSImage(named: sort.ascending ? "NSAscendingSortIndicator" : "NSDescendingSortIndicator")
            } else if header.hovered == index {
                Self.hoverArrow
            } else {
                nil
            }
            if tableView.indicatorImage(in: column) !== arrow { tableView.setIndicatorImage(arrow, in: column) }
        }
    }

    /// File rows sorted by a column: numbers by value before text, text as Finder sorts names; ties keep file order.
    func sorted(by column: Int, ascending: Bool) -> [Int] {
        let table = table, locale = Locale.current, formatter = CSVTable.numberFormatter(locale)
        let keys = (headerOffset..<table.rowCount).map { row in
            let text = table.cell(row: row, column: column)
            return (row: row, text: text, number: CSVTable.number(text, locale: locale, formatter: formatter))
        }
        return keys.sorted { a, b in
            let result: ComparisonResult = switch (a.number, b.number) {
            case let (x?, y?): x < y ? .orderedAscending : x > y ? .orderedDescending : .orderedSame
            case (_?, nil): .orderedAscending
            case (nil, _?): .orderedDescending
            default: a.text.localizedStandardCompare(b.text)
            }
            if result == .orderedSame { return a.row < b.row }
            return (result == .orderedAscending) == ascending
        }.map(\.row)
    }
}
