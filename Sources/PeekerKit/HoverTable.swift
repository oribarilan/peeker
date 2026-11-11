import AppKit

/// A scroll view holding `table`, whose row under the pointer shows the hover tint. The table's delegate returns
/// `rowView(for:)` from `tableView(_:rowViewForRow:)`.
open class HoverTableScrollView: NSScrollView {
    public let table = NSTableView()
    /// The row under the pointer, or nil.
    public private(set) var hoveredRow: Int?

    public override init(frame: NSRect) {
        super.init(frame: frame)
        documentView = table
        addTrackingArea(
            NSTrackingArea(
                rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
                owner: self))
    }

    public required init?(coder: NSCoder) { nil }

    /// A row view for `row`, hovered if the pointer is over it.
    public func rowView(for row: Int) -> HoverRowView {
        let view = HoverRowView()
        view.isHovered = row == hoveredRow
        return view
    }

    open override func mouseMoved(with event: NSEvent) { hover(at: event.locationInWindow) }
    open override func mouseEntered(with event: NSEvent) { hover(at: event.locationInWindow) }
    open override func mouseExited(with event: NSEvent) { setHovered(nil) }

    open override func scrollWheel(with event: NSEvent) {
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
            (table.rowView(atRow: old, makeIfNecessary: false) as? HoverRowView)?.isHovered = old == row
        }
        hoveredRow = row
    }
}
