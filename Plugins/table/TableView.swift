import AppKit

/// The table on screen: a row-number column, then one column per CSV column. It shows the document's `CSVTable`
/// through `order`, which is file order or a sort, and turns clicks, typing and drags into the document's edits.
final class TableView: NSView, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate, NSMenuDelegate {
    /// Weak: AppKit can still ask the table for rows while its window closes, after the document has gone.
    private weak var document: TableDocument?
    /// The document's table, or none once the document has gone.
    private var table: CSVTable { document?.table ?? CSVTable(text: "", delimiter: .comma) }
    private var isEditable: Bool { document?.isEditable == true }
    var canEdit: Bool { isEditable }
    let tableView = GridView()
    private let scrollView = NSScrollView()
    /// File rows in the order shown while sorted; nil in file order.
    private(set) var order: [Int]?
    private var sort: (column: Int, ascending: Bool)?
    /// The column of the cell last clicked or edited, in the file's columns.
    private(set) var currentColumn: Int?
    /// The cell being typed in: the row shown, and the file row, fixed when editing starts.
    private var editing: (row: Int, fileRow: Int, column: Int)?
    private static let rowPasteboardType = NSPasteboard.PasteboardType("dev.peeker.table-rows")
    /// The last row's fields, while AppKit asks for its cells.
    private var rowCache: (row: Int, fields: [CSVField])?
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
    /// The table's own row height and header at the default size.
    private var baseRowHeight: CGFloat = 0, baseHeaderHeight: CGFloat = 0
    private var baseHeaderFont = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
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
        super.init(frame: .zero)
        tableView.owner = self
        tableView.dataSource = self
        tableView.delegate = self
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = true
        tableView.columnAutoresizingStyle = .noColumnAutoresizing
        tableView.gridStyleMask = [.solidVerticalGridLineMask]
        tableView.style = .plain
        baseRowHeight = tableView.rowHeight
        baseHeaderHeight = tableView.headerView?.frame.height ?? 0
        baseHeaderFont = NSTableColumn().headerCell.font ?? baseHeaderFont
        fontSize = document.fontSize
        tableView.target = self
        tableView.action = #selector(clicked)
        tableView.doubleAction = #selector(doubleClicked)
        tableView.registerForDraggedTypes([Self.rowPasteboardType])
        let rowMenu = NSMenu(), columnMenu = NSMenu()
        for (menu, ids) in [(rowMenu, ["add-row-above", "add-row-below", "delete-rows"]), (columnMenu, ["add-column-before", "add-column-after", "delete-columns"])] {
            menu.delegate = self
            menu.autoenablesItems = false  // enabled by `menuNeedsUpdate`
            for id in ids {
                let item = NSMenuItem(title: TablePlugin.tools.first { $0.id == id }?.title ?? id, action: #selector(runTool(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = id
                menu.addItem(item)
            }
        }
        tableView.menu = rowMenu
        tableView.headerView?.menu = columnMenu
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor), scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor), scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        applyScale()
        reloadAll()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private var headerOffset: Int { document?.hasHeader == true && table.rowCount > 0 ? 1 : 0 }

    /// The file row shown at `row`.
    func fileRow(_ row: Int) -> Int { order?[row] ?? row + headerOffset }

    /// The selected rows, as file rows.
    var selectedFileRows: IndexSet { IndexSet(tableView.selectedRowIndexes.map(fileRow)) }

    // MARK: Reloading

    /// Titles, sort and rows again, after any change to the table's shape. Columns are made again only when their
    /// number changes, keeping the widths of those that stay.
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
            column.width = 120 * scale
            column.minWidth = 30
            tableView.addTableColumn(column)
        }
        reloadCells()
    }

    /// Titles, sort arrows and cells for the columns there are, numbered by position: a column the user dragged has
    /// already moved in the table, so only the numbers and titles change.
    func reloadCells() {
        rowCache = nil
        for (index, column) in tableView.tableColumns.dropFirst().enumerated() {
            column.identifier = NSUserInterfaceItemIdentifier("\(index)")
            column.title = title(of: index)
            column.headerCell.font = NSFont(descriptor: baseHeaderFont.fontDescriptor, size: baseHeaderFont.pointSize * scale)
            let arrow = sort?.column == index ? NSImage(named: sort!.ascending ? "NSAscendingSortIndicator" : "NSDescendingSortIndicator") : nil
            tableView.setIndicatorImage(arrow, in: column)
        }
        tableView.reloadData()
    }

    /// Fonts, row height and header height for the font size; a cell being typed in keeps going at the new size.
    private func applyScale() {
        cellFont = .systemFont(ofSize: fontSize)
        numberFont = .monospacedDigitSystemFont(ofSize: CellView.numberFont.pointSize * scale, weight: .regular)
        tableView.rowHeight = ceil(baseRowHeight * scale)
        if let header = tableView.headerView, baseHeaderHeight > 0 {
            header.frame.size.height = ceil(baseHeaderHeight * scale)
            scrollView.tile()
        }
        if let editing {
            editor.font = cellFont
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

    // MARK: Data

    func numberOfRows(in tableView: NSTableView) -> Int { order?.count ?? max(table.rowCount - headerOffset, 0) }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let identifier = tableColumn?.identifier else { return nil }
        let isNumber = identifier.rawValue == "row"
        let reuse = NSUserInterfaceItemIdentifier(isNumber ? "number" : "cell")
        let cell = tableView.makeView(withIdentifier: reuse, owner: self) as? CellView ?? CellView(identifier: reuse, isNumber: isNumber)
        cell.font = isNumber ? numberFont : cellFont
        let file = fileRow(row)
        if isNumber {
            cell.text = "\(file - headerOffset + 1)"
        } else if let column = Int(identifier.rawValue) {
            // AppKit asks for a row's cells one after another, so the row is parsed once for all of them.
            if rowCache?.row != file { rowCache = (file, table.fields(ofRow: file)) }
            let fields = rowCache?.fields ?? []
            cell.text = column < fields.count ? fields[column].text : ""
        }
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

    @objc private func clicked() {
        if tableView.clickedColumn > 0 { currentColumn = tableView.clickedColumn - 1 }
    }

    @objc private func doubleClicked() {
        guard tableView.clickedRow >= 0, tableView.clickedColumn > 0 else { return }
        edit(row: tableView.clickedRow, column: tableView.clickedColumn - 1)
    }

    /// Return on the table edits the selected row's current cell.
    func editSelection() {
        guard tableView.selectedRow >= 0 else { return }
        edit(row: tableView.selectedRow, column: currentColumn ?? 0)
    }

    func edit(row: Int, column: Int) {
        guard isEditable, row < numberOfRows(in: tableView), column < table.columnCount else { return }
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        tableView.scrollRowToVisible(row)
        tableView.scrollColumnToVisible(column + 1)
        // A text field over the cell while it's edited; cells only draw their text, which keeps the table fast.
        let frame = tableView.frameOfCell(atColumn: column + 1, row: row)
        guard !frame.isEmpty else { return }
        currentColumn = column
        editing = (row, fileRow(row), column)
        editor.frame = frame
        editor.font = cellFont
        editor.stringValue = table.cell(row: fileRow(row), column: column)
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

    func controlTextDidEndEditing(_ notification: Notification) {
        guard let editing, notification.object as? NSTextField === editor else { return }
        self.editing = nil
        let value = editor.stringValue
        editor.removeFromSuperview()
        document?.setCell(value, row: editing.fileRow, column: editing.column)
        // The next cell starts on the next pass: AppKit makes the table first responder once this returns.
        let next: (row: Int, column: Int)? = switch notification.userInfo?["NSTextMovement"] as? Int {
        case NSTextMovement.return.rawValue: (editing.row + 1, editing.column)
        case NSTextMovement.tab.rawValue: (editing.row, editing.column + 1)
        default: nil
        }
        if let next { DispatchQueue.main.async { [weak self] in self?.edit(row: next.row, column: next.column) } }
    }

    @objc private func runTool(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String, document?.perform(id) == true else { return NSSound.beep() }
    }

    /// A right-click picks the row or column it's on.
    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu === tableView.headerView?.menu, tableView.clickedColumn > 0 { currentColumn = tableView.clickedColumn - 1 }
        if menu === tableView.menu, tableView.clickedRow >= 0, !tableView.selectedRowIndexes.contains(tableView.clickedRow) {
            tableView.selectRowIndexes(IndexSet(integer: tableView.clickedRow), byExtendingSelection: false)
        }
        for item in menu.items {
            item.isEnabled = isEditable && (item.representedObject as? String).map { document?.unavailableReason(for: $0) == nil } == true
        }
    }

    // MARK: Moving

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> (any NSPasteboardWriting)? {
        guard isEditable, order == nil else { return nil }
        let item = NSPasteboardItem()
        item.setString("\(row)", forType: Self.rowPasteboardType)
        return item
    }

    func tableView(_ tableView: NSTableView, validateDrop info: any NSDraggingInfo, proposedRow row: Int,
                   proposedDropOperation operation: NSTableView.DropOperation) -> NSDragOperation {
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
        guard let old = notification.userInfo?["NSOldColumn"] as? Int, let new = notification.userInfo?["NSNewColumn"] as? Int, old != new else { return }
        document?.moveColumn(from: old - 1, to: new - 1)
    }

    // MARK: Sorting

    /// Ascending, descending, then file order again.
    func tableView(_ tableView: NSTableView, didClick tableColumn: NSTableColumn) {
        guard let column = Int(tableColumn.identifier.rawValue) else { return }
        commitEditing()
        switch sort {
        case (column, true)?: sort = (column, false)
        case (column, false)?: sort = nil; order = nil
        default: sort = (column, true)
        }
        reloadAll()
    }

    func sortBy(column: Int?, ascending: Bool = true) {
        commitEditing()
        sort = column.map { ($0, ascending) }
        if column == nil { order = nil }
        reloadAll()
    }

    /// File rows sorted by a column: numbers by value before text, text as Finder sorts names; ties keep file order.
    private func sorted(by column: Int, ascending: Bool) -> [Int] {
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

/// The table view: Return edits the selected cell, and Undo is the document's.
final class GridView: NSTableView {
    weak var owner: TableView?
    var documentUndoManager: UndoManager?

    override var undoManager: UndoManager? { documentUndoManager ?? super.undoManager }

    override func keyDown(with event: NSEvent) {
        let plain = event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty
        if plain, event.keyCode == 36 || event.keyCode == 76, let owner, owner.canEdit { return owner.editSelection() }
        super.keyDown(with: event)
    }
}

/// A cell that draws its text and nothing else: much cheaper than a text field per cell, which made opening a table
/// slower than opening the same file as plain text.
final class CellView: NSView {
    /// The fonts at the default size.
    static let font = NSFont.systemFont(ofSize: TableDocument.defaultFontSize)
    static let numberFont = NSFont.monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
    private static let paragraph: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        return style
    }()
    private static let numberParagraph: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byClipping
        style.alignment = .right
        return style
    }()
    private let isNumber: Bool
    var text = "" {
        didSet { if text != oldValue { needsDisplay = true } }
    }
    var font: NSFont {
        didSet { if font != oldValue { needsDisplay = true } }
    }

    init(identifier: NSUserInterfaceItemIdentifier, isNumber: Bool) {
        self.isNumber = isNumber
        font = isNumber ? Self.numberFont : Self.font
        super.init(frame: .zero)
        self.identifier = identifier
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: isNumber ? NSColor.secondaryLabelColor : NSColor.labelColor,
            .paragraphStyle: isNumber ? Self.numberParagraph : Self.paragraph,
        ]
        let line = text.replacingOccurrences(of: "\n", with: " ")  // one line per cell, as a spreadsheet shows it
        let height = font.boundingRectForFont.height
        let box = NSRect(x: 2, y: (bounds.height - height) / 2, width: bounds.width - 4, height: height)
        (line as NSString).draw(with: box, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: attributes)
    }

    // A cell reads as static text, as the text field it replaces did.
    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .staticText }
    override func accessibilityValue() -> Any? { text }
}
