import AppKit
import PeekerKit

/// The sidebar's thumbnails of a multi-page TIFF, one row per page, the page shown selected and the one under the
/// pointer tinted. Thumbnails decode off the main thread when their row first shows and stay cached while the
/// document is open.
final class PageList: HoverTableScrollView, NSTableViewDataSource, NSTableViewDelegate {
    /// The longer side of a thumbnail, in pixels.
    static let thumbnailSide = 256
    var url: URL  // follows a Save As
    private let pageCount: Int
    private let onSelect: (Int) -> Void
    private var thumbnails: [Int: CGImage] = [:]
    private var decoding: [Int: Task<CGImage?, Never>] = [:]

    init(url: URL, pageCount: Int, onSelect: @escaping (Int) -> Void) {
        self.url = url
        self.pageCount = pageCount
        self.onSelect = onSelect
        super.init(frame: .zero)
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("page"))
        table.addTableColumn(column)
        table.headerView = nil
        table.rowHeight = 140
        table.style = .sourceList
        table.dataSource = self
        table.delegate = self
        table.setAccessibilityLabel("Pages")
        hasVerticalScroller = true
        autohidesScrollers = true
        drawsBackground = false
        select(0)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    isolated deinit {
        decoding.values.forEach { $0.cancel() }
    }

    /// Selects the row of `page` and scrolls it into view, without telling `onSelect`.
    func select(_ page: Int) {
        guard table.selectedRow != page else { return }
        selecting = true
        table.selectRowIndexes([page], byExtendingSelection: false)
        selecting = false
        table.scrollRowToVisible(page)
    }

    private var selecting = false

    /// The thumbnail of `page`, decoded on first use.
    func thumbnail(of page: Int) async -> CGImage? {
        if let cached = thumbnails[page] { return cached }
        let url = url
        let task = decoding[page] ?? Task { await ImagePlugin.thumbnail(url, page: page, maxSide: Self.thumbnailSide) }
        decoding[page] = task
        let image = await task.value
        decoding[page] = nil
        if let image { thumbnails[page] = image }
        return image
    }

    func numberOfRows(in tableView: NSTableView) -> Int { pageCount }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? { rowView(for: row) }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: PageCell.identifier, owner: nil) as? PageCell ?? PageCell()
        cell.show(page: row, image: thumbnails[row])
        if thumbnails[row] == nil {
            Task { [weak self, weak cell] in
                guard let image = await self?.thumbnail(of: row), let cell, cell.page == row else { return }
                cell.show(page: row, image: image)
            }
        }
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !selecting, table.selectedRow >= 0 else { return }
        onSelect(table.selectedRow)
    }
}

/// A page's thumbnail with its number under it.
private final class PageCell: NSTableCellView {
    static let identifier = NSUserInterfaceItemIdentifier("PageCell")
    private let picture = NSImageView()
    private let number = NSTextField(labelWithString: "")
    private(set) var page = -1

    init() {
        super.init(frame: .zero)
        identifier = Self.identifier
        picture.imageScaling = .scaleProportionallyDown
        number.font = .preferredFont(forTextStyle: .caption1)
        number.textColor = .secondaryLabelColor
        number.alignment = .center
        let stack = NSStackView(views: [picture, number])
        stack.orientation = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
        ])
        picture.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func show(page: Int, image: CGImage?) {
        self.page = page
        number.stringValue = "\(page + 1)"
        picture.image = image.map { NSImage(cgImage: $0, size: .zero) }
        setAccessibilityLabel("Page \(page + 1)")
    }
}
