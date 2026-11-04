import AppKit

/// The sidebar outline: one row per heading, a click jumps there. A table, not a stack of buttons: it only creates the visible rows, so 4,000 headings stay instant.
/// A row highlights under the pointer, and `mark` selects the heading of the section the cursor is in.
final class OutlineList: NSScrollView, NSTableViewDataSource, NSTableViewDelegate {
    let table = NSTableView()
    private let items: [OutlineItem]
    private let onAnchor: (Int) -> Void
    /// The row under the pointer, or nil.
    private(set) var hoveredRow: Int?

    init(items: [OutlineItem], onAnchor: @escaping (Int) -> Void) {
        self.items = items
        self.onAnchor = onAnchor
        super.init(frame: .zero)
        table.addTableColumn(NSTableColumn(identifier: .init("title")))
        table.headerView = nil
        table.style = .sourceList
        table.rowHeight = 20
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.action = #selector(clicked)
        documentView = table
        hasVerticalScroller = true
        autohidesScrollers = true
        drawsBackground = false
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
                                       owner: self))
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// Selects the row at `index`, or none, and shows it. It's the cursor's section, so it doesn't jump anywhere.
    func mark(_ index: Int?) {
        guard let index, items.indices.contains(index) else { return table.deselectAll(nil) }
        table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        table.scrollRowToVisible(index)
    }

    func numberOfRows(in tableView: NSTableView) -> Int { items.count }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let view = OutlineRowView()
        view.isHovered = row == hoveredRow
        return view
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = items[row]
        let cell = tableView.makeView(withIdentifier: .init("cell"), owner: nil) as? NSTextField ?? {
            let field = NSTextField(labelWithString: "")
            field.identifier = .init("cell")
            field.lineBreakMode = .byTruncatingTail
            return field
        }()
        cell.stringValue = String(repeating: "   ", count: max(0, item.level - 1)) + item.title
        cell.font = .systemFont(ofSize: 12, weight: item.level == 1 ? .semibold : .regular)
        return cell
    }

    @objc private func clicked() {
        guard items.indices.contains(table.clickedRow) else { return }
        onAnchor(items[table.clickedRow].line)
    }

    // MARK: Hover

    override func mouseMoved(with event: NSEvent) { hover(at: event.locationInWindow) }
    override func mouseEntered(with event: NSEvent) { hover(at: event.locationInWindow) }
    override func mouseExited(with event: NSEvent) { setHovered(nil) }

    override func scrollWheel(with event: NSEvent) {
        super.scrollWheel(with: event)
        if let window, hoveredRow != nil { hover(at: window.mouseLocationOutsideOfEventStream) }  // rows moved under the pointer
    }

    private func hover(at windowPoint: NSPoint) {
        let row = table.row(at: table.convert(windowPoint, from: nil))
        setHovered(row >= 0 ? row : nil)
    }

    private func setHovered(_ row: Int?) {
        guard row != hoveredRow else { return }
        for old in [hoveredRow, row].compactMap({ $0 }) {
            (table.rowView(atRow: old, makeIfNecessary: false) as? OutlineRowView)?.isHovered = old == row
        }
        hoveredRow = row
    }
}

/// A row that draws a faint fill while the pointer is over it, under the source list's own selection.
final class OutlineRowView: NSTableRowView {
    var isHovered = false {
        didSet { if isHovered != oldValue { needsDisplay = true } }
    }

    override func drawBackground(in dirtyRect: NSRect) {
        super.drawBackground(in: dirtyRect)
        guard isHovered, !isSelected else { return }
        NSColor.quaternarySystemFill.setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 6, dy: 1), xRadius: 5, yRadius: 5).fill()
    }
}
