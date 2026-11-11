import AppKit
import PeekerKit

/// The sidebar's outline: the top-level keys, or array items; a click goes to one.
final class DataOutlineList: HoverTableScrollView, NSTableViewDataSource, NSTableViewDelegate {
    private let items: [String]
    private let onPick: (Int) -> Void

    init(items: [String], onPick: @escaping (Int) -> Void) {
        self.items = items
        self.onPick = onPick
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

    func numberOfRows(in tableView: NSTableView) -> Int { items.count }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? { rowView(for: row) }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell =
            tableView.makeView(withIdentifier: .init("cell"), owner: nil) as? NSTextField
            ?? {
                let field = NSTextField(labelWithString: "")
                field.identifier = .init("cell")
                field.lineBreakMode = .byTruncatingTail
                field.font = .systemFont(ofSize: 12)
                return field
            }()
        cell.stringValue = items[row]
        return cell
    }

    @objc private func clicked() {
        guard items.indices.contains(table.clickedRow) else { return }
        onPick(table.clickedRow)
    }
}
