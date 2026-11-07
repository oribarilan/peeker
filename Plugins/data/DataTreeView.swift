import AppKit

/// The tree: key and value columns over the document's parse. Cells draw their text; a text field goes over the cell
/// being edited. Drags reorder an item within its parent.
final class DataTreeView: NSView, NSOutlineViewDataSource, NSOutlineViewDelegate, NSTextFieldDelegate {
    private weak var document: DataDocument?
    let outlineView = TreeOutlineView()
    private let scrollView = NSScrollView()
    private var editing: (node: DataNode, key: Bool)?
    private static let pasteboardType = NSPasteboard.PasteboardType("dev.peeker.data-item")
    private(set) lazy var editor: NSTextField = {
        let field = NSTextField(string: "")
        field.delegate = self
        field.focusRingType = .none
        field.cell?.usesSingleLineMode = true
        return field
    }()

    init(document: DataDocument) {
        self.document = document
        super.init(frame: .zero)
        outlineView.owner = self
        outlineView.documentUndoManager = document.undoManager
        for (id, title, width) in [("key", "Key", 220.0), ("value", "Value", 400.0)] {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
            column.title = title
            column.width = width
            column.minWidth = 60
            outlineView.addTableColumn(column)
        }
        outlineView.outlineTableColumn = outlineView.tableColumns[0]
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.allowsMultipleSelection = true
        outlineView.usesAlternatingRowBackgroundColors = true
        outlineView.style = .plain
        outlineView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        outlineView.target = self
        outlineView.doubleAction = #selector(doubleClicked)
        outlineView.registerForDraggedTypes([Self.pasteboardType])
        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor), scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor), scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// The items shown at the top: the top value's children, or the value itself when it isn't an object or array.
    private var topItems: [DataNode] {
        guard let root = document?.root else { return [] }
        return root.isContainer ? root.children : [root]
    }

    var selectedNodes: [DataNode] { outlineView.selectedRowIndexes.compactMap { outlineView.item(atRow: $0) as? DataNode } }

    /// The tree again, first level open.
    func reload() {
        outlineView.reloadData()
        if outlineView.numberOfRows > 0, outlineView.numberOfRows < 200 {
            for item in topItems where item.isContainer && item.children.count < 50 { outlineView.expandItem(item) }
        }
    }

    // MARK: Keeping place across a parse

    struct State {
        let expanded: [[Int]]
        let selected: [[Int]]
    }

    func state() -> State {
        guard let document else { return State(expanded: [], selected: []) }
        let rows = 0..<outlineView.numberOfRows
        let nodes = rows.compactMap { outlineView.item(atRow: $0) as? DataNode }
        return State(expanded: nodes.filter { outlineView.isItemExpanded($0) }.map(document.indexPath),
                     selected: selectedNodes.map(document.indexPath))
    }

    func restore(_ state: State) {
        guard let document else { return }
        outlineView.reloadData()
        outlineView.collapseItem(nil, collapseChildren: true)
        for path in state.expanded.sorted(by: { $0.count < $1.count }) {
            if let node = document.node(at: path) { outlineView.expandItem(node) }
        }
        let rows = state.selected.compactMap { document.node(at: $0) }.map { outlineView.row(forItem: $0) }.filter { $0 >= 0 }
        outlineView.selectRowIndexes(IndexSet(rows), byExtendingSelection: false)
    }

    /// Selects `node`, opening its parents, and scrolls it into view.
    func select(_ node: DataNode) {
        var parents: [DataNode] = [], current = node.parent
        while let parent = current, parent !== document?.root {
            parents.insert(parent, at: 0)
            current = parent.parent
        }
        for parent in parents { outlineView.expandItem(parent) }
        let row = outlineView.row(forItem: node)
        guard row >= 0 else { return }
        outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        outlineView.scrollRowToVisible(row)
        window?.makeFirstResponder(outlineView)
    }

    // MARK: Data

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        (item as? DataNode)?.children.count ?? topItems.count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        (item as? DataNode)?.children[index] ?? topItems[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        (item as? DataNode)?.children.isEmpty == false
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? DataNode, let id = tableColumn?.identifier.rawValue else { return nil }
        let cell = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(id), owner: self) as? TreeCell ?? TreeCell(identifier: id)
        if id == "key" {
            cell.set(node.key ?? "\(node.index)", dim: node.key == nil)
        } else {
            cell.set(Self.shown(node), dim: node.isContainer || node.kind == .null)
        }
        return cell
    }

    /// A value as the tree shows it: a string's text, a scalar as written, an object or array by its size.
    static func shown(_ node: DataNode) -> String {
        switch node.kind {
        case .object: node.children.count == 1 ? "1 key" : "\(node.children.count) keys"
        case .array: node.children.count == 1 ? "1 item" : "\(node.children.count) items"
        case .element: node.children.count == 1 ? "1 child" : "\(node.children.count) children"
        default: (node.value ?? "").replacingOccurrences(of: "\n", with: " ")
        }
    }

    /// Rows draw their cells into one layer each, which keeps the first frame quick.
    func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        let identifier = NSUserInterfaceItemIdentifier("treeRow")
        let rowView = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableRowView ?? NSTableRowView()
        rowView.identifier = identifier
        rowView.canDrawSubviewsIntoLayer = true
        return rowView
    }

    // MARK: Editing

    @objc private func doubleClicked() {
        guard let node = outlineView.item(atRow: outlineView.clickedRow) as? DataNode else { return }
        edit(node, key: outlineView.clickedColumn == 0)
    }

    /// Return edits the selected item's value, or its key when it's an object or array.
    func editSelection() {
        guard let node = selectedNodes.first else { return }
        edit(node, key: node.isContainer)
    }

    func edit(_ node: DataNode, key: Bool) {
        guard document?.canEditTree == true, key ? node.key != nil : !node.isContainer else { return }
        let row = outlineView.row(forItem: node)
        guard row >= 0 else { return }
        outlineView.scrollRowToVisible(row)
        var frame = outlineView.frameOfCell(atColumn: key ? 0 : 1, row: row)
        if key, let cell = outlineView.view(atColumn: 0, row: row, makeIfNecessary: true) { frame = cell.convert(cell.bounds, to: outlineView) }
        guard !frame.isEmpty else { return }
        editing = (node, key)
        editor.frame = frame
        editor.font = TreeCell.font
        editor.stringValue = key ? node.key ?? "" : node.value ?? ""
        outlineView.addSubview(editor)
        window?.makeFirstResponder(editor)
    }

    /// Ends typing in a cell, keeping what was typed.
    func commitEditing() {
        if editing != nil { window?.makeFirstResponder(outlineView) }
        if let editing { finish(editing) }  // outside a window, nothing else ends it
    }

    /// Ends typing in a cell, dropping it.
    func cancelEditing() {
        guard editing != nil else { return }
        editing = nil
        editor.abortEditing()
        editor.removeFromSuperview()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        guard selector == #selector(cancelOperation(_:)), editing != nil else { return false }
        editing = nil
        editor.abortEditing()
        editor.removeFromSuperview()
        window?.makeFirstResponder(outlineView)
        return true
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        guard let editing, notification.object as? NSTextField === editor else { return }
        finish(editing)
        window?.makeFirstResponder(outlineView)
    }

    private func finish(_ editing: (node: DataNode, key: Bool)) {
        self.editing = nil
        let value = editor.stringValue
        editor.removeFromSuperview()
        if editing.key { document?.rename(editing.node, to: value) } else { document?.setValue(editing.node, to: value) }
    }

    // MARK: Moving within a parent

    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> (any NSPasteboardWriting)? {
        guard document?.canEditTree == true, let node = item as? DataNode, let document, node.parent != nil else { return nil }
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(document.indexPath(of: node).map(String.init).joined(separator: "."), forType: Self.pasteboardType)
        return pasteboardItem
    }

    private func dragged(_ info: any NSDraggingInfo) -> DataNode? {
        guard let string = info.draggingPasteboard.pasteboardItems?.first?.string(forType: Self.pasteboardType) else { return nil }
        return document?.node(at: string.split(separator: ".").compactMap { Int($0) })
    }

    func outlineView(_ outlineView: NSOutlineView, validateDrop info: any NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
        guard info.draggingSource as? NSOutlineView === outlineView, let node = dragged(info), index >= 0 else { return [] }
        let target = (item as? DataNode) ?? document?.root
        return target === node.parent ? .move : []
    }

    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: any NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
        guard let node = dragged(info) else { return false }
        document?.move(node, to: index > node.index ? index - 1 : index)
        return true
    }
}

/// The outline view: Return edits, and Undo is the document's.
final class TreeOutlineView: NSOutlineView {
    weak var owner: DataTreeView?
    var documentUndoManager: UndoManager?

    override var undoManager: UndoManager? { documentUndoManager ?? super.undoManager }

    override func keyDown(with event: NSEvent) {
        let plain = event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty
        if plain, event.keyCode == 36 || event.keyCode == 76, let owner { return owner.editSelection() }
        super.keyDown(with: event)
    }
}

/// A cell that draws its text, as the Table plugin's do: much cheaper than a text field per cell.
final class TreeCell: NSView {
    static let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
    private static let paragraph: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        return style
    }()
    private var text = "", dim = false

    init(identifier: String) {
        super.init(frame: .zero)
        self.identifier = NSUserInterfaceItemIdentifier(identifier)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func set(_ text: String, dim: Bool) {
        guard text != self.text || dim != self.dim else { return }
        self.text = text
        self.dim = dim
        needsDisplay = true
    }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        let height = Self.font.boundingRectForFont.height
        let box = NSRect(x: 2, y: (bounds.height - height) / 2, width: bounds.width - 4, height: height)
        (text as NSString).draw(with: box, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: [
            .font: Self.font, .foregroundColor: dim ? NSColor.secondaryLabelColor : NSColor.labelColor, .paragraphStyle: Self.paragraph,
        ])
    }

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .staticText }
    override func accessibilityValue() -> Any? { text }
}
