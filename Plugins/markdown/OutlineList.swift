import AppKit
import PeekerKit

/// The sidebar outline: one row per heading, a click jumps there. A table, not a stack of buttons: it only creates the visible rows, so 4,000 headings stay instant.
/// A row shows the hover tint under the pointer, and `mark` selects the heading of the section the cursor is in.
final class OutlineList: HoverTableScrollView, NSTableViewDataSource, NSTableViewDelegate {
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
        hasVerticalScroller = true
        autohidesScrollers = true
        drawsBackground = false
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// Selects the row at `index`, or none, and shows it. It's the cursor's section, so it doesn't jump anywhere.
    func mark(_ index: Int?) {
        guard let index, items.indices.contains(index) else { return table.deselectAll(nil) }
        table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        table.scrollRowToVisible(index)
    }

    func numberOfRows(in tableView: NSTableView) -> Int { items.count }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? { rowView(for: row) }

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
