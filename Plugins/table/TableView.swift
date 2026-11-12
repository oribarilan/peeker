import AppKit
import PeekerKit

/// The table on screen: a row-number column, then one column per CSV column. It shows the document's `CSVTable`
/// through `order`, which is file order or a sort, keeps a spreadsheet's selection (`TableSelection`), and turns
/// clicks, typing and drags into the document's edits. Columns open fitted to the document's column samples.
final class TableView: NSView, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate, NSMenuDelegate {
    /// Weak: AppKit can still ask the table for rows while its window closes, after the document has gone.
    private(set) weak var document: TableDocument?
    /// The document's table, or none once the document has gone.
    var table: CSVTable { document?.table ?? CSVTable(text: "", delimiter: .comma) }
    private var isEditable: Bool { document?.isEditable == true }
    var canEdit: Bool { isEditable }
    let tableView = GridView()
    let header = TableHeaderView()
    let scrollView = NSScrollView()
    /// Find, from the first Cmd+F (TableFind.swift): the bar, its finder, the matches tinted and the current one.
    var findBar: FindBar?
    var finder: TableFinder?
    var marks: Set<CellRef> = []
    var currentMark: CellRef?
    /// The table at the top, or under the find bar while that shows.
    var scrollAtTop: NSLayoutConstraint!
    var scrollBelowBar: NSLayoutConstraint?
    /// No find in the Peek panel.
    var allowsFind: Bool { document?.allowsFind == true }
    /// File rows in the order shown while sorted; nil in file order.
    /// Set by sorting (TableView+Sorting.swift).
    var order: [Int]?
    var sort: (column: Int, ascending: Bool)?
    /// The current cell and what's selected, in shown rows.
    var selection = TableSelection()
    /// In the Peek panel the selection shows from the first click; in the Editor from the start.
    var showsSelection: Bool
    /// The cell being typed in: the row shown, and the file row, fixed when editing starts.
    private(set) var editing: (row: Int, fileRow: Int, column: Int)?
    private static let rowPasteboardType = NSPasteboard.PasteboardType("dev.peeker.table-rows")
    /// The last row's fields, while AppKit asks for its cells.
    private var rowCache: (row: Int, fields: [CSVField])?
    /// The document's `columnsVersion` the widths were last fitted for.
    private var fittedVersion = -1
    /// The cells' text size, from the document's zoom. Rows, the header and columns follow it.
    var fontSize = TableDocument.defaultFontSize {
        didSet {
            guard fontSize != oldValue else { return }
            for column in tableView.tableColumns { column.width *= fontSize / oldValue }
            applyScale()
        }
    }
    private var scale: CGFloat { fontSize / TableDocument.defaultFontSize }
    private var cellFont = CellView.font, numberFont = CellView.numberFont
    /// Number columns use digits of one width, so their decimals line up.
    private var digitsFont = NSFont.monospacedDigitSystemFont(ofSize: TableDocument.defaultFontSize, weight: .regular)
    private var headerFont: NSFont { NSFont(descriptor: baseHeaderFont.fontDescriptor, size: baseHeaderFont.pointSize * scale) ?? baseHeaderFont }
    /// The table's own row height and header at the default size.
    private var baseRowHeight: CGFloat = 0, baseHeaderHeight: CGFloat = 0
    private var baseHeaderFont = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
    /// The widest a column opens, at the default size; a dimmed arrow for the title under the pointer.
    private static let widestFitted: CGFloat = 320
    static let hoverArrow: NSImage? = NSImage(named: "NSAscendingSortIndicator").map { arrow in
        NSImage(size: arrow.size, flipped: false) { rect in
            arrow.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 0.35)
            return true
        }
    }
    /// The text field shown over the cell being edited.
    private(set) lazy var editor: NSTextField = {
        let field = NSTextField(string: "")
        field.delegate = self
        field.focusRingType = .none
        field.cell?.usesSingleLineMode = true
        field.lineBreakMode = .byClipping
        return field
    }()

    init(document: TableDocument) {
        self.document = document
        showsSelection = document.allowsFind
        super.init(frame: .zero)
        tableView.owner = self
        header.owner = self
        header.frame.size.height = tableView.headerView?.frame.height ?? 28
        tableView.headerView = header
        tableView.dataSource = self
        tableView.delegate = self
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = true
        tableView.allowsColumnSelection = false
        tableView.selectionHighlightStyle = .none
        tableView.columnAutoresizingStyle = .noColumnAutoresizing
        tableView.gridStyleMask = [.solidVerticalGridLineMask]
        tableView.style = .plain
        baseRowHeight = tableView.rowHeight
        baseHeaderHeight = header.frame.height
        baseHeaderFont = NSTableColumn().headerCell.font ?? baseHeaderFont
        fontSize = document.fontSize
        tableView.registerForDraggedTypes([Self.rowPasteboardType])
        let rowMenu = NSMenu(), columnMenu = NSMenu()
        let menus = [
            (rowMenu, ["add-row-above", "add-row-below", "delete-rows"]),
            (columnMenu, ["add-column-before", "add-column-after", "delete-columns", "", "sort-ascending", "sort-descending", "sort-none"]),
        ]
        for (menu, ids) in menus {
            menu.delegate = self
            menu.autoenablesItems = false  // enabled by `menuNeedsUpdate`
            for id in ids {
                guard !id.isEmpty else { menu.addItem(.separator()); continue }
                let item = NSMenuItem(title: TablePlugin.tools.first { $0.id == id }?.title ?? id, action: #selector(runTool(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = id
                menu.addItem(item)
            }
        }
        tableView.menu = rowMenu
        header.menu = columnMenu
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)
        scrollAtTop = scrollView.topAnchor.constraint(equalTo: topAnchor)
        NSLayoutConstraint.activate([
            scrollAtTop, scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor), scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        applyScale()
        reloadAll()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self)
        guard let window else { return }
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification] {
            NotificationCenter.default.addObserver(self, selector: #selector(keyWindowChanged), name: name, object: window)
        }
    }

    @objc private func keyWindowChanged() { selectionChanged(scrolling: false) }

    var headerOffset: Int { document?.hasHeader == true && table.rowCount > 0 ? 1 : 0 }
    /// Whether file row 0 shows as the column titles.
    var headerIsShown: Bool { headerOffset == 1 }

    /// The file row shown at `row`.
    func fileRow(_ row: Int) -> Int { order?[row] ?? row + headerOffset }

    /// The rows the selection covers, as file rows.
    var selectedFileRows: IndexSet {
        var rows = selection.rows
        guard order == nil else { return IndexSet(rows.map(fileRow)) }
        rows.shift(startingAt: 0, by: headerOffset)
        return rows
    }

    // MARK: Reloading

    /// Titles, sort and rows again, after any change to the table's shape. Columns are made again only when their
    /// number changes, keeping the widths of those that stay, and fitted again when the document's samples change.
    func reloadAll() {
        if let sort { order = sorted(by: sort.column, ascending: sort.ascending) }
        tableView.allowsColumnReordering = isEditable && order == nil
        let wanted = table.columnCount + 1
        if tableView.numberOfColumns == 0 {
            let number = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("row"))
            number.title = ""
            number.width = 44 * scale
            number.isEditable = false
            tableView.addTableColumn(number)
        }
        while tableView.numberOfColumns > wanted { tableView.removeTableColumn(tableView.tableColumns[tableView.numberOfColumns - 1]) }
        while tableView.numberOfColumns < wanted {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("\(tableView.numberOfColumns - 1)"))
            column.headerCell = TableHeaderCell(textCell: "")
            column.width = 120 * scale
            column.minWidth = 30
            tableView.addTableColumn(column)
        }
        if let document, fittedVersion != document.columnsVersion { fitColumns() }
        selection.resize(rows: numberOfRows(in: tableView), columns: table.columnCount)
        reloadCells()
        syncRowSelection()
        tableDidChange()
    }

    /// Titles, sort arrows, alignment and cells for the columns there are, numbered by position: a column the user
    /// dragged has already moved in the table, so only the numbers and titles change.
    func reloadCells() {
        rowCache = nil
        for (index, column) in tableView.tableColumns.dropFirst().enumerated() {
            column.identifier = NSUserInterfaceItemIdentifier("\(index)")
            column.title = title(of: index)
            column.headerCell.font = headerFont
            column.headerCell.alignment = isNumeric(index) ? .right : .natural
        }
        updateArrows()
        if !marks.isEmpty { markTitles() }
        tableView.reloadData()
        updateTitleTints()
    }

    /// Fonts, row height and header height for the font size; a cell being typed in keeps going at the new size.
    private func applyScale() {
        cellFont = .systemFont(ofSize: fontSize)
        digitsFont = .monospacedDigitSystemFont(ofSize: fontSize, weight: .regular)
        numberFont = .monospacedDigitSystemFont(ofSize: CellView.numberFont.pointSize * scale, weight: .regular)
        tableView.rowHeight = ceil(baseRowHeight * scale)
        if baseHeaderHeight > 0 {
            header.frame.size.height = ceil(baseHeaderHeight * scale)
            scrollView.tile()
        }
        if let editing {
            editor.font = font(forColumn: editing.column)
            editor.frame = tableView.frameOfCell(atColumn: editing.column + 1, row: editing.row)
        }
        reloadCells()
    }

    /// Ends typing in a cell, keeping what was typed, before the rows or columns change under it.
    func commitEditing() {
        if editing != nil { window?.makeFirstResponder(tableView) }
    }

    /// Redraws file rows whose cells changed.
    func reloadRows(_ fileRows: IndexSet) {
        rowCache = nil
        let shown = IndexSet((0..<numberOfRows(in: tableView)).filter { fileRows.contains(fileRow($0)) })
        tableView.reloadData(forRowIndexes: shown, columnIndexes: IndexSet(0..<tableView.numberOfColumns))
        tableDidChange()
    }

    private func title(of column: Int) -> String {
        if headerOffset == 1 {
            let header = table.cell(row: 0, column: column)
            if !header.isEmpty { return header }
        }
        return Self.letters(column)
    }

    /// A, B, …, Z, AA, AB, …
    static func letters(_ index: Int) -> String {
        var index = index, name = ""
        repeat {
            name = String(UnicodeScalar(UInt8(65 + index % 26))) + name
            index = index / 26 - 1
        } while index >= 0
        return name
    }

    // MARK: Widths and alignment

    func isNumeric(_ column: Int) -> Bool {
        guard let columns = document?.columns, column < columns.count else { return false }
        return columns[column].isNumeric
    }

    private func font(forColumn column: Int) -> NSFont { isNumeric(column) ? digitsFont : cellFont }

    /// Every column as wide as its title and its sampled cells, within the limits.
    private func fitColumns() {
        guard let document else { return }
        fittedVersion = document.columnsVersion
        for (index, column) in tableView.tableColumns.dropFirst().enumerated() where index < document.columns.count {
            column.width = fittedWidth(index, sample: document.columns[index], widest: Self.widestFitted * scale)
        }
    }

    /// The width for the sample's cells and the column's title with room for its sort arrow, at least a few
    /// characters and at most `widest`.
    func fittedWidth(_ column: Int, sample: ColumnSample, widest: CGFloat) -> CGFloat {
        let cells = sample.cellsWidth(font: font(forColumn: column)) + 10 * scale
        let title = (title(of: column) as NSString).size(withAttributes: [.font: headerFont]).width + 26 * scale
        let narrowest = ("0000" as NSString).size(withAttributes: [.font: cellFont]).width + 10 * scale
        return min(max(cells, title, narrowest), max(widest, narrowest)).rounded(.up)
    }

    /// Double-clicking a divider: the column fits its sample and the rows on screen, at most the visible width.
    func tableView(_ tableView: NSTableView, sizeToFitWidthOfColumn column: Int) -> CGFloat {
        guard column > 0, let columns = document?.columns, column - 1 < columns.count else { return tableView.tableColumns[column].width }
        var sample = columns[column - 1]
        let visible = tableView.rows(in: tableView.visibleRect)
        for row in visible.location..<visible.location + visible.length {
            sample.keep(String(table.cell(row: fileRow(row), column: column - 1).prefix(200)))
        }
        return fittedWidth(column - 1, sample: sample, widest: scrollView.contentView.bounds.width)
    }

    // MARK: Data

    func numberOfRows(in tableView: NSTableView) -> Int { order?.count ?? max(table.rowCount - headerOffset, 0) }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let identifier = tableColumn?.identifier else { return nil }
        let isRowNumber = identifier.rawValue == "row"
        let reuse = NSUserInterfaceItemIdentifier(isRowNumber ? "number" : "cell")
        let cell = tableView.makeView(withIdentifier: reuse, owner: self) as? CellView ?? CellView(identifier: reuse, isRowNumber: isRowNumber)
        let file = fileRow(row)
        if isRowNumber {
            cell.font = numberFont
            cell.mark = .none
            cell.text = "\(file - headerOffset + 1)"
        } else if let column = Int(identifier.rawValue) {
            // AppKit asks for a row's cells one after another, so the row is parsed once for all of them.
            if rowCache?.row != file { rowCache = (file, table.fields(ofRow: file)) }
            let fields = rowCache?.fields ?? []
            cell.font = font(forColumn: column)
            cell.alignsRight = isNumeric(column)
            cell.text = column < fields.count ? fields[column].text : ""
            cell.mark = marks.isEmpty ? .none : mark(row: file, column: column)
        }
        showSelection(in: cell, row: row, column: isRowNumber ? nil : Int(identifier.rawValue))
        return cell
    }

    /// Rows draw their cells into one layer each: a layer per cell made handing the first frame to the screen several
    /// milliseconds slower than a text view's single layer.
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = tableView.makeView(withIdentifier: Self.rowViewIdentifier, owner: self) as? NSTableRowView ?? NSTableRowView()
        rowView.identifier = Self.rowViewIdentifier
        rowView.canDrawSubviewsIntoLayer = true
        return rowView
    }

    private static let rowViewIdentifier = NSUserInterfaceItemIdentifier("tableRow")

    // MARK: Editing

    /// Return on the table edits the current cell.
    func editCurrent() {
        edit(row: selection.current.row, column: selection.current.column)
    }

    /// A typed key replaces the current cell: editing starts empty, and the field editor gets the key, so input
    /// methods and dead keys work as in any text field.
    func typeOver(_ event: NSEvent) {
        edit(row: selection.current.row, column: selection.current.column, text: "")
        guard editing != nil else { return }
        (window?.firstResponder as? NSTextView)?.keyDown(with: event)
    }

    func edit(row: Int, column: Int, text: String? = nil) {
        guard isEditable, row < numberOfRows(in: tableView), column < table.columnCount else { return }
        showsSelection = true
        select(CellPosition(row: row, column: column))
        // A text field over the cell while it's edited; cells only draw their text, which keeps the table fast.
        let frame = tableView.frameOfCell(atColumn: column + 1, row: row)
        guard !frame.isEmpty else { return }
        editing = (row, fileRow(row), column)
        editor.frame = frame
        editor.font = font(forColumn: column)
        editor.alignment = isNumeric(column) ? .right : .natural
        editor.stringValue = text ?? table.cell(row: fileRow(row), column: column)
        tableView.addSubview(editor)
        window?.makeFirstResponder(editor)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        guard selector == #selector(cancelOperation(_:)), editing != nil else { return false }
        editing = nil
        editor.abortEditing()
        editor.removeFromSuperview()
        window?.makeFirstResponder(tableView)
        return true
    }

    /// Saves the text; Return then makes the cell below current and Tab the one to the right, without editing it.
    func controlTextDidEndEditing(_ notification: Notification) {
        guard let editing, notification.object as? NSTextField === editor else { return }
        self.editing = nil
        let value = editor.stringValue
        editor.removeFromSuperview()
        document?.setCell(value, row: editing.fileRow, column: editing.column)
        let next: CellPosition? =
            switch notification.userInfo?["NSTextMovement"] as? Int {
            case NSTextMovement.return.rawValue: CellPosition(row: editing.row + 1, column: editing.column)
            case NSTextMovement.tab.rawValue: CellPosition(row: editing.row, column: editing.column + 1)
            case NSTextMovement.backtab.rawValue: CellPosition(row: editing.row, column: editing.column - 1)
            default: nil
            }
        // A click elsewhere keeps the focus it moved; after Return or Tab the next key goes to the table.
        guard let next else { return selectionChanged(scrolling: false) }
        window?.makeFirstResponder(tableView)
        select(next)
    }

    /// Delete: the selected cells emptied, as one edit.
    func clearSelection() {
        guard isEditable else { return }
        document?.clearCells(rows: selectedFileRows, columns: selection.columns)
    }

    @objc private func runTool(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String, document?.perform(id) == true else { return NSSound.beep() }
    }

    /// A right-click on a row or title outside the selection selects it first.
    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu === header.menu, tableView.clickedColumn > 0, !selection.columns.contains(tableView.clickedColumn - 1) {
            clickColumn(tableView.clickedColumn - 1, extending: false, toggling: false)
        }
        if menu === tableView.menu, tableView.clickedRow >= 0, !selection.rows.contains(tableView.clickedRow) {
            clickRow(tableView.clickedRow, extending: false, toggling: false)
        }
        for item in menu.items {
            guard let id = item.representedObject as? String else { continue }
            let isSort = id.hasPrefix("sort-")
            item.isEnabled = (isSort || isEditable) && document?.unavailableReason(for: id) == nil
        }
    }

    // MARK: Moving

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> (any NSPasteboardWriting)? {
        guard isEditable, order == nil else { return nil }
        let item = NSPasteboardItem()
        item.setString("\(row)", forType: Self.rowPasteboardType)
        return item
    }

    func tableView(
        _ tableView: NSTableView, validateDrop info: any NSDraggingInfo, proposedRow row: Int,
        proposedDropOperation operation: NSTableView.DropOperation
    ) -> NSDragOperation {
        guard info.draggingSource as? NSTableView === tableView else { return [] }
        tableView.setDropRow(row, dropOperation: .above)
        return .move
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: any NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        let dragged = info.draggingPasteboard.pasteboardItems?.compactMap { $0.string(forType: Self.rowPasteboardType).flatMap(Int.init) } ?? []
        let rows = IndexSet(dragged.map(fileRow))
        guard !rows.isEmpty else { return false }
        document?.moveRows(rows, to: row + headerOffset)
        return true
    }

    func tableView(_ tableView: NSTableView, shouldReorderColumn column: Int, toColumn newColumn: Int) -> Bool {
        column > 0 && newColumn > 0
    }

    func tableViewColumnDidMove(_ notification: Notification) {
        guard let old = notification.userInfo?["NSOldColumn"] as? Int, let new = notification.userInfo?["NSNewColumn"] as? Int, old != new else {
            return
        }
        document?.moveColumn(from: old - 1, to: new - 1)
    }

}
