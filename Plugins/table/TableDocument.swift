import AppKit
import PeekerKit

/// A CSV or TSV file as a table. Edits are operations on the `CSVTable`, each undoable, pending until saved.
final class TableDocument: PluginDocument {
    private(set) var url: URL
    private let allowsEditing: Bool
    private let preferences: PluginPreferences?
    private var tooLarge: Bool
    /// How the file stores its text, so a save writes it back the same way.
    private var format: TextFormat
    /// The text as last loaded or saved, for Revert and to tell a recovered copy that changes nothing.
    private var savedText: String
    private(set) var table: CSVTable
    private(set) var delimiter: Delimiter
    private(set) var hasHeader: Bool
    private(set) var info: [InfoRow]
    private var byteCount: Int
    /// Each state of the table has its own number; Undo and Redo go back to earlier ones. The document is edited
    /// while the state shown isn't the one last saved.
    private var state = 0, savedState = 0, newestState = 0
    let undoManager = UndoManager()
    private lazy var view: TableView = {
        let view = TableView(document: self)
        view.tableView.documentUndoManager = undoManager
        return view
    }()
    var onEdit: (() -> Void)?
    var onSidebarChange: (() -> Void)?
    var onZoomChange: (() -> Void)?
    /// The cells' text size, remembered for every table opened after it changes.
    private(set) var fontSize = TableDocument.defaultFontSize
    static let defaultFontSize = NSFont.systemFontSize
    private static let fontSizes: ClosedRange<CGFloat> = 6...72

    init(url: URL, loaded: TablePlugin.Loaded, allowsEditing: Bool, preferences: PluginPreferences?) {
        self.url = url
        self.allowsEditing = allowsEditing
        self.preferences = preferences
        tooLarge = loaded.byteCount > TablePlugin.editableBytes
        format = loaded.format
        savedText = loaded.table.text
        table = loaded.table
        delimiter = loaded.table.delimiter
        hasHeader = loaded.header
        byteCount = loaded.byteCount
        info = Self.info(loaded.table, format: loaded.format, byteCount: loaded.byteCount)
        undoManager.groupsByEvent = false
        if let size = preferences?.double("fontSize"), Self.fontSizes.contains(size) { fontSize = size }
    }

    var contentView: NSView { view }
    var focusView: NSView? { view.tableView }
    var tools: [ToolSpec] { TablePlugin.tools }
    func makeSidebar() -> [SidebarPanel] { InfoPanel.make(info).map { [$0] } ?? [] }

    var editability: Editability {
        guard allowsEditing else { return .notEditable }
        return tooLarge ? .readOnly(TablePlugin.readOnlyReason) : .editable
    }

    var isEditable: Bool { editability == .editable }

    static func info(_ table: CSVTable, format: TextFormat, byteCount: Int) -> [InfoRow] {
        [InfoRow(label: "Rows", value: table.rowCount.formatted()),
         InfoRow(label: "Columns", value: table.columnCount.formatted()),
         InfoRow(label: "Encoding", value: String.localizedName(of: format.encoding) + (format.hasBOM ? " with BOM" : "")),
         InfoRow(label: "Size", value: ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file))]
    }

    /// The sidebar's counts again, after the table was read anew or saved.
    private func refreshInfo(byteCount: Int? = nil) {
        if let byteCount { self.byteCount = byteCount }
        info = Self.info(table, format: format, byteCount: self.byteCount)
        onSidebarChange?()
    }

    // MARK: Tools

    func isOn(_ tool: String) -> Bool? {
        switch tool {
        case "header-row": hasHeader
        case let id where id.hasPrefix("delimiter-"): id == "delimiter-\(delimiter)"
        default: nil
        }
    }

    func perform(_ id: String) -> Bool {
        view.commitEditing()  // text being typed lands before the rows and columns change under it
        switch id {
        case "zoom-in": setFontSize(fontSize + 1, beepsAtLimit: true)
        case "zoom-out": setFontSize(fontSize - 1, beepsAtLimit: true)
        case "zoom-actual": setFontSize(Self.defaultFontSize, beepsAtLimit: false)
        case "header-row":
            hasHeader.toggle()
            remember()
            view.reloadAll()
        case let id where id.hasPrefix("delimiter-"):
            guard let choice = Delimiter.allCases.first(where: { "delimiter-\($0)" == id }) else { return false }
            setDelimiter(choice)
        case "add-row-above" where isEditable: insertRows(above: true)
        case "add-row-below" where isEditable: insertRows(above: false)
        case "add-column-before" where isEditable: insertColumn(at: view.currentColumn ?? 0)
        case "add-column-after" where isEditable: insertColumn(at: (view.currentColumn ?? table.columnCount - 1) + 1)
        case "delete-rows" where isEditable:
            let rows = view.selectedFileRows
            guard !rows.isEmpty else { return false }
            removeRows(rows)
        case "delete-columns" where isEditable:
            guard let column = view.currentColumn, column < table.columnCount else { return false }
            removeColumn(column)
        default: return false
        }
        return true
    }

    func unavailableReason(for tool: String) -> String? {
        switch tool {
        case "delete-rows" where view.selectedFileRows.isEmpty: "Select the rows to delete."
        case "delete-columns" where view.currentColumn == nil: "Click a cell in the column to delete."
        default: nil
        }
    }

    private func setFontSize(_ size: CGFloat, beepsAtLimit: Bool) {
        let clamped = min(max(size, Self.fontSizes.lowerBound), Self.fontSizes.upperBound)
        guard clamped != fontSize else {
            if beepsAtLimit { NSSound.beep() }
            return
        }
        fontSize = clamped
        preferences?.set(Double(clamped), for: "fontSize")
        view.fontSize = clamped
        onZoomChange?()
    }

    private func insertRows(above: Bool) {
        let selected = view.selectedFileRows
        let first = hasHeader ? 1 : 0
        let at = above ? (selected.first ?? first) : (selected.last.map { $0 + 1 } ?? table.rowCount)
        insertRows([CSVTable.emptyRow], at: IndexSet(integer: max(at, first)))
    }

    /// Splits the text again at another delimiter. The undo history refers to the old rows and columns, so it goes;
    /// unsaved edits stay, as text.
    private func setDelimiter(_ choice: Delimiter) {
        guard choice != delimiter else { return }
        let text = isEdited ? table.serialized(lineEnding: "\n") : savedText
        delimiter = choice
        table = CSVTable(text: text, delimiter: choice)
        undoManager.removeAllActions()
        remember()
        view.reloadAll()
        refreshInfo()
    }

    private func remember() {
        FileChoices(preferences).remember(FileChoices.Choice(delimiter: delimiter, header: hasHeader), for: url)
    }

    // MARK: Edits

    /// What brings the table back, applied by Undo; each returns its own inverse for Redo.
    private enum Inverse {
        case row(Int, CSVRow)
        case rows([CSVRow])
        case insert([CSVRow], IndexSet)
        case remove(IndexSet)
    }

    func setCell(_ value: String, row: Int, column: Int) {
        guard isEditable, row < table.rowCount, table.cell(row: row, column: column) != value else { return }
        let before = table.rows[row]
        table.setCell(value, row: row, column: column)
        record(.row(row, before))
        view.reloadRows(IndexSet(integer: row))
    }

    func insertRows(_ rows: [CSVRow], at indexes: IndexSet) {
        table.insertRows(rows, at: indexes)
        record(.remove(indexes))
        view.reloadAll()
    }

    func removeRows(_ indexes: IndexSet) {
        let removed = table.removeRows(at: indexes)
        record(.insert(removed, indexes))
        view.reloadAll()
    }

    func moveRows(_ indexes: IndexSet, to destination: Int) {
        // A block of rows dropped onto itself goes nowhere and is no edit.
        if let first = indexes.first, let last = indexes.last, last - first + 1 == indexes.count, (first...last + 1).contains(destination) { return }
        let before = table.rows
        table.moveRows(from: indexes, to: destination)
        record(.rows(before))
        view.reloadAll()
    }

    func insertColumn(at index: Int) {
        let before = table.rows
        table.insertColumn(at: index)
        record(.rows(before))
        view.reloadAll()
    }

    func removeColumn(_ index: Int) {
        let before = table.rows
        table.removeColumn(at: index)
        record(.rows(before))
        view.reloadAll()
    }

    /// From a column dragged in the table, which has already moved its own column.
    func moveColumn(from source: Int, to destination: Int) {
        guard source != destination else { return }
        let before = table.rows
        table.moveColumn(from: source, to: destination)
        record(.rows(before))
        view.reloadCells()
    }

    /// Registers the way back and moves to a new state, or with `restoring`, to that earlier one (Undo and Redo).
    private func record(_ inverse: Inverse, restoring previous: Int? = nil) {
        let from = state
        if let previous {
            state = previous
        } else {
            newestState += 1
            state = newestState
        }
        undoManager.beginUndoGrouping()
        undoManager.registerUndo(withTarget: self) { $0.undo(inverse, restoring: from) }
        undoManager.endUndoGrouping()
        onEdit?()
    }

    private func undo(_ inverse: Inverse, restoring target: Int) {
        view.commitEditing()
        let redo: Inverse
        switch inverse {
        case .row(let index, let row):
            redo = .row(index, table.rows[index])
            table.rows[index] = row
        case .rows(let rows):
            redo = .rows(table.rows)
            table.rows = rows
        case .insert(let rows, let indexes):
            table.insertRows(rows, at: indexes)
            redo = .remove(indexes)
        case .remove(let indexes):
            redo = .insert(table.removeRows(at: indexes), indexes)
        }
        record(redo, restoring: target)
        if case .row(let index, _) = inverse { view.reloadRows(IndexSet(integer: index)) } else { view.reloadAll() }
    }

    var isEdited: Bool { state != savedState }

    // MARK: Saving

    /// The table at one state, serialized off the main thread as Plain Text's edits are.
    private nonisolated struct Snapshot: Encodable, Sendable {
        let table: CSVTable
        let state: Int
        func encode(to encoder: any Encoder) throws { try TextEdits(text: table.serialized(lineEnding: "\n")).encode(to: encoder) }
    }

    func unsavedEdits() -> UnsavedEdits? {
        isEditable && isEdited ? UnsavedEdits(Snapshot(table: table, state: state)) : nil
    }

    func restore(encoded edits: Data) -> Bool {
        guard isEditable, let text = (try? JSONDecoder().decode(TextEdits.self, from: edits))?.text else { return false }
        view.commitEditing()
        guard text != savedText else { return true }  // the recovered copy is the file as it is
        // A table of another text: the undo history's rows point into the old one, so it goes.
        table = CSVTable(text: text, delimiter: delimiter)
        undoManager.removeAllActions()
        newestState += 1
        state = newestState
        onEdit?()
        view.reloadAll()
        refreshInfo()
        return true
    }

    func save(_ edits: UnsavedEdits, accepting offer: SaveOffer?) async throws(PluginError) {
        guard isEditable, let snapshot = edits.value as? Snapshot else { throw PluginError(TablePlugin.readOnlyReason) }
        try await write(snapshot, to: url, offer: offer)
    }

    func saveAs(_ edits: UnsavedEdits?, to destination: URL, accepting offer: SaveOffer?) async throws(PluginError) {
        if isEditable, let snapshot = edits?.value as? Snapshot {
            try await write(snapshot, to: destination, offer: offer)
        } else {
            try await FileReplacement.copy(url, to: destination)
        }
        url = destination
        remember()  // the choices made for the file go with it
    }

    /// Writes the snapshot's state, which is then the saved one, whatever was edited since it was taken.
    private func write(_ snapshot: Snapshot, to destination: URL, offer: SaveOffer?) async throws(PluginError) {
        let text = snapshot.table.serialized(lineEnding: "\n")
        let target = offer == TextFile.saveAsUTF8 ? TextFormat(encoding: .utf8, hasBOM: false, lineEnding: format.lineEnding) : format
        let byteCount = try await TextFile.write(text, as: target, to: destination.path)
        format = target
        savedText = text
        savedState = snapshot.state
        refreshInfo(byteCount: byteCount)
    }

    func revertEdits() {
        view.commitEditing()
        table = CSVTable(text: savedText, delimiter: delimiter)
        undoManager.removeAllActions()
        state = savedState
        view.reloadAll()
        refreshInfo()
    }

    func reload() async throws(PluginError) -> Bool {
        let loaded = try await TablePlugin.load(url, delimiter: delimiter, header: hasHeader)
        guard !isEdited else { return true }  // edits made meanwhile win
        view.commitEditing()
        format = loaded.format
        savedText = loaded.table.text
        table = loaded.table
        tooLarge = loaded.byteCount > TablePlugin.editableBytes
        undoManager.removeAllActions()
        view.reloadAll()
        refreshInfo(byteCount: loaded.byteCount)
        return true
    }
}

extension TableDocument: Zooming {
    var zoomPercent: Double { fontSize / Self.defaultFontSize * 100 }
    var zoomRange: ClosedRange<Double> { Self.fontSizes.lowerBound / Self.defaultFontSize * 100...Self.fontSizes.upperBound / Self.defaultFontSize * 100 }

    func setZoom(_ percent: Double, around point: NSPoint?) {
        guard percent.isFinite else { return }
        setFontSize(Self.defaultFontSize * percent / 100, beepsAtLimit: false)
    }
}
