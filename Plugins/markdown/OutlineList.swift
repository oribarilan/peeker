import AppKit

/// The sidebar outline: one row per heading, a click jumps there. A table, not a stack of buttons: it only creates the visible rows, so 4,000 headings stay instant.
final class OutlineList: NSScrollView, NSTableViewDataSource, NSTableViewDelegate {
    private let table = NSTableView()
    private let items: [OutlineItem]
    private let onAnchor: (Int) -> Void

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
        drawsBackground = false
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func numberOfRows(in tableView: NSTableView) -> Int { items.count }

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
}
