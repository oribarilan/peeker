import AppKit
import PDFKit

/// Sidebar panels a plugin can ask for: outline, thumbnails, info.
enum Sidebar {
    static func make(_ panels: [Panel], component: Component?, onAnchor: @escaping (Int) -> Void) -> NSView? {
        let views = panels.compactMap { panel -> (NSView, Column.Sizing)? in
            switch panel {
            case .thumbnails: (component as? PDFComponent).map { ($0.makeThumbnails(), .fill) }
            case .outline(let items): outline(items, onAnchor: onAnchor).map { ($0, .fill) }
            case .info(let rows): info(rows).map { ($0, .fit) }
            }
        }
        return views.isEmpty ? nil : Column(views)
    }

    private static func outline(_ items: [OutlineItem], onAnchor: @escaping (Int) -> Void) -> NSView? {
        guard !items.isEmpty else { return nil }
        return OutlineList(items: items, onAnchor: onAnchor).scrollView
    }

    /// One selectable text field with tab stops, not a grid of labels: the sidebar is laid out on the way to the first
    /// paint, and a grid of wrapping labels cost several milliseconds of Auto Layout there.
    private static func info(_ rows: [InfoRow]) -> NSView? {
        guard !rows.isEmpty else { return nil }
        let font = NSFont.systemFont(ofSize: 11)
        let labelWidth = rows.map { ceil(($0.label as NSString).size(withAttributes: [.font: font]).width) }.max() ?? 0
        let style = NSMutableParagraphStyle()
        style.tabStops = [NSTextTab(textAlignment: .right, location: labelWidth), NSTextTab(textAlignment: .left, location: labelWidth + 8)]
        style.headIndent = labelWidth + 8
        style.paragraphSpacing = 4
        let text = NSMutableAttributedString()
        for (index, row) in rows.enumerated() {
            text.append(NSAttributedString(string: "\t" + row.label, attributes: [.font: font, .foregroundColor: NSColor.secondaryLabelColor]))
            text.append(NSAttributedString(string: "\t" + row.value + (index < rows.count - 1 ? "\n" : ""), attributes: [.font: font, .foregroundColor: NSColor.labelColor]))
        }
        text.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: text.length))
        let field = NSTextField(wrappingLabelWithString: "")
        field.attributedStringValue = text
        field.isSelectable = true
        return field
    }

    /// Stacks the panels top to bottom by hand: info panels take the height of their text, list panels (outline,
    /// thumbnails) share what's left.
    private final class Column: NSView {
        enum Sizing { case fit, fill }
        private let panels: [(view: NSView, sizing: Sizing)]
        private static let insets = NSEdgeInsets(top: 8, left: 10, bottom: 10, right: 10)
        private static let spacing: CGFloat = 14
        private static let minimumFillHeight: CGFloat = 80

        init(_ panels: [(NSView, Sizing)]) {
            self.panels = panels
            super.init(frame: .zero)
            for (view, _) in panels { addSubview(view) }
        }

        required init?(coder: NSCoder) { fatalError("not used") }
        override var isFlipped: Bool { true }

        override func layout() {
            super.layout()
            let insets = Self.insets
            let width = max(0, bounds.width - insets.left - insets.right)
            let top = insets.top + safeAreaInsets.top
            let heights = panels.map { panel -> CGFloat? in
                guard panel.sizing == .fit else { return nil }
                if let field = panel.view as? NSTextField {
                    return ceil(field.cell?.cellSize(forBounds: NSRect(x: 0, y: 0, width: width, height: .greatestFiniteMagnitude)).height ?? 0)
                }
                return panel.view.fittingSize.height
            }
            let fixed = heights.compactMap { $0 }.reduce(0, +) + Self.spacing * CGFloat(panels.count - 1)
            let fillCount = CGFloat(heights.count { $0 == nil })
            let fillHeight = max(Self.minimumFillHeight, (bounds.height - top - insets.bottom - fixed) / max(fillCount, 1))
            var y = top
            for (panel, height) in zip(panels, heights) {
                let height = height ?? fillHeight
                panel.view.frame = NSRect(x: insets.left, y: y, width: width, height: height)
                y += height + Self.spacing
            }
        }
    }

    /// A table, not a stack of buttons: it only creates the visible rows, so 4,000 headings stay instant.
    private final class OutlineList: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        let scrollView = NSScrollView()
        private let table = NSTableView()
        private let items: [OutlineItem]
        private let onAnchor: (Int) -> Void

        init(items: [OutlineItem], onAnchor: @escaping (Int) -> Void) {
            self.items = items
            self.onAnchor = onAnchor
            super.init()
            table.addTableColumn(NSTableColumn(identifier: .init("title")))
            table.headerView = nil
            table.style = .sourceList
            table.rowHeight = 20
            table.dataSource = self
            table.delegate = self
            table.target = self
            table.action = #selector(clicked)
            scrollView.documentView = table
            scrollView.hasVerticalScroller = true
            scrollView.drawsBackground = false
            objc_setAssociatedObject(scrollView, Unmanaged.passUnretained(self).toOpaque(), self, .OBJC_ASSOCIATION_RETAIN)
        }

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
}
