import AppKit
import PeekerKit

/// A cell by its file row and column.
nonisolated struct CellRef: Hashable, Sendable {
    let row: Int
    let column: Int
}

nonisolated enum TableSearch {
    /// The cells containing `query`, ignoring case and accents, in file order. Stops early, with nothing, once
    /// `isCancelled` says so.
    static func matches(of query: String, in table: CSVTable, isCancelled: () -> Bool = { false }) -> [CellRef] {
        guard !query.isEmpty else { return [] }
        var found: [CellRef] = []
        for row in 0..<table.rowCount {
            if row % 1024 == 0, isCancelled() { return [] }
            for (column, field) in table.fields(ofRow: row).enumerated()
            where field.text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil {
                found.append(CellRef(row: row, column: column))
            }
        }
        return found
    }

    /// `matches` in the order shown: the header row first, then the rows as `shownRows` lists them (nil: file
    /// order), left to right.
    static func ordered(_ matches: [CellRef], hasHeader: Bool, shownRows: [Int]?) -> [CellRef] {
        guard let shownRows else { return matches }
        var position: [Int: Int] = [:]
        for (index, row) in shownRows.enumerated() { position[row] = index }
        if hasHeader { position[0] = -1 }
        return matches.filter { position[$0.row] != nil }.sorted { a, b in
            let (first, second) = (position[a.row]!, position[b.row]!)
            return first != second ? first < second : a.column < b.column
        }
    }
}

/// Searches a table in the background as the user types. One match is current.
final class TableFinder {
    private(set) var matches: [CellRef] = []
    private(set) var current: Int?
    private(set) var isSearching = false
    private var query = ""
    private var task: Task<Void, Never>?
    /// Tells a search's result from that of the search that replaced it.
    private var generation = 0
    /// The table to search, whether row 0 is the header, and the file rows in the order shown (nil: file order).
    private let source: () -> (table: CSVTable, hasHeader: Bool, shownRows: [Int]?)
    /// Called when matches or the current one change; true when the current match should come into view.
    var onChange: ((Bool) -> Void)?

    init(source: @escaping () -> (table: CSVTable, hasHeader: Bool, shownRows: [Int]?)) {
        self.source = source
    }

    isolated deinit {
        task?.cancel()
    }

    var currentMatch: CellRef? { current.map { matches[$0] } }

    /// "2 of 5", "5 matches", "Not found", or empty while searching or with nothing to search for.
    var status: String {
        if let current { return "\(current + 1) of \(matches.count)" }
        if !matches.isEmpty { return matches.count == 1 ? "1 match" : "\(matches.count) matches" }
        return query.isEmpty || isSearching ? "" : "Not found"
    }

    /// Searches for `text`. The first match becomes current, unless `selectingFirst` is false: then the current cell
    /// stays current if it still matches.
    func search(_ text: String, selectingFirst: Bool = true) {
        query = text
        generation += 1
        task?.cancel()
        let previous = currentMatch, ticket = generation
        guard !text.isEmpty else {
            (matches, current, isSearching) = ([], nil, false)
            onChange?(false)
            return
        }
        let (table, hasHeader, shownRows) = source()
        isSearching = true
        onChange?(false)
        task = Task { [weak self] in
            let found = await Self.find(text, in: table, hasHeader: hasHeader, shownRows: shownRows)
            guard let self, ticket == generation else { return }
            isSearching = false
            matches = found
            current = selectingFirst ? (found.isEmpty ? nil : 0) : previous.flatMap { found.firstIndex(of: $0) }
            onChange?(selectingFirst && current != nil)
        }
    }

    @concurrent private static func find(_ text: String, in table: CSVTable, hasHeader: Bool, shownRows: [Int]?) async -> [CellRef] {
        TableSearch.ordered(TableSearch.matches(of: text, in: table) { Task.isCancelled }, hasHeader: hasHeader, shownRows: shownRows)
    }

    /// The next or previous match, wrapping around.
    func step(forward: Bool) {
        guard !matches.isEmpty else { return }
        let start = current ?? (forward ? -1 : matches.count)
        current = (start + (forward ? 1 : -1) + matches.count) % matches.count
        onChange?(true)
    }

    /// Searches again after the table changed, keeping the current match where it still matches.
    func refresh() {
        if !query.isEmpty { search(query, selectingFirst: false) }
    }
}

/// Find in the table: the bar above it from the first Cmd+F, the matches tinted. Not in the Peek panel.
extension TableView: NSMenuItemValidation {
    @objc func performFindPanelAction(_ sender: Any?) {
        guard allowsFind else { return }
        switch Self.findAction(of: sender) {
        case .showFindPanel: showFindBar()
        case .next: finder?.step(forward: true)
        case .previous: finder?.step(forward: false)
        default: NSSound.beep()
        }
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard menuItem.action == #selector(performFindPanelAction(_:)), allowsFind else { return false }
        switch Self.findAction(of: menuItem) {
        case .showFindPanel: return true
        case .next, .previous: return findBar?.isHidden == false && finder?.matches.isEmpty == false
        default: return false
        }
    }

    private static func findAction(of sender: Any?) -> NSFindPanelAction? {
        let tag = (sender as? NSMenuItem)?.tag ?? (sender as? NSControl)?.tag
        return tag.flatMap { NSFindPanelAction(rawValue: UInt($0)) }
    }

    func showFindBar() {
        commitEditing()
        let bar = findBar ?? makeFindBar()
        bar.isHidden = false
        scrollAtTop.isActive = false
        scrollBelowBar?.isActive = true
        layoutSubtreeIfNeeded()
        window?.makeFirstResponder(bar.field)
        bar.field.selectText(nil)
        finder?.refresh()
    }

    func closeFindBar() {
        guard let findBar, !findBar.isHidden else { return }
        findBar.isHidden = true
        scrollBelowBar?.isActive = false
        scrollAtTop.isActive = true
        showMarks(nil)
        window?.makeFirstResponder(tableView)
    }

    private func makeFindBar() -> FindBar {
        let finder = TableFinder { [weak self] in
            guard let self, let document else { return (CSVTable(text: "", delimiter: .comma), false, nil) }
            return (document.table, document.hasHeader && document.table.rowCount > 0, order)
        }
        let bar = FindBar(label: "Find in table", target: self)
        bar.onSearch = { [weak finder] in finder?.search($0) }
        bar.onAction = { [weak self] action in
            switch action {
            case .next: self?.finder?.step(forward: true)
            case .previous: self?.finder?.step(forward: false)
            case .close: self?.closeFindBar()
            }
        }
        finder.onChange = { [weak self, weak finder, weak bar] reveal in
            guard let self, let finder else { return }
            bar?.status = finder.status
            showMarks(finder)
            if reveal, let match = finder.currentMatch { self.reveal(match) }
        }
        bar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bar)
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            bar.leadingAnchor.constraint(equalTo: leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        scrollBelowBar = scrollView.topAnchor.constraint(equalTo: bar.bottomAnchor)
        findBar = bar
        self.finder = finder
        return bar
    }

    /// The finder's matches tinted, or none.
    private func showMarks(_ finder: TableFinder?) {
        let marks = Set(finder?.matches ?? []), current = finder?.currentMatch
        guard marks != self.marks || current != currentMark else { return }
        self.marks = marks
        currentMark = current
        markTitles()
        let visible = tableView.rows(in: tableView.visibleRect)
        guard visible.length > 0 else { return }
        tableView.reloadData(forRowIndexes: IndexSet(integersIn: visible.location..<visible.location + visible.length),
                             columnIndexes: IndexSet(integersIn: 0..<tableView.numberOfColumns))
    }

    /// Tints the column titles that match, when the header row is on.
    func markTitles() {
        for (index, column) in tableView.tableColumns.dropFirst().enumerated() {
            let ref = CellRef(row: 0, column: index)
            guard headerIsShown, marks.contains(ref) else {
                column.title = column.title  // drops a tint left from an earlier search
                continue
            }
            let tint = NSColor.findHighlightColor.withAlphaComponent(ref == currentMark ? 1 : 0.4)
            column.headerCell.attributedStringValue = NSAttributedString(string: column.title, attributes: [
                .backgroundColor: tint, .font: column.headerCell.font ?? NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            ])
        }
        tableView.headerView?.needsDisplay = true
    }

    /// The mark for the cell at file row `row`.
    func mark(row: Int, column: Int) -> CellView.Mark {
        let ref = CellRef(row: row, column: column)
        return ref == currentMark ? .current : marks.contains(ref) ? .match : .none
    }

    /// Selects the match's row and scrolls its cell into view; a header match scrolls its column into view.
    private func reveal(_ match: CellRef) {
        tableView.scrollColumnToVisible(match.column + 1)
        currentColumn = match.column
        guard !(headerIsShown && match.row == 0) else { return }
        let row = order?.firstIndex(of: match.row) ?? match.row - (headerIsShown ? 1 : 0)
        guard row >= 0, row < tableView.numberOfRows else { return }
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        tableView.scrollRowToVisible(row)
    }

    /// After the table's cells, rows or order changed: searches again while the bar shows.
    func tableDidChange() {
        if findBar?.isHidden == false { finder?.refresh() }
    }
}
