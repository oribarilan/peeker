import AppKit

/// The table view, taking clicks, drags and keys as a spreadsheet does: a click makes a cell current, a drag selects
/// a block, arrows and Tab move, Return edits, typing replaces the cell and Delete clears the selection. Row numbers
/// keep AppKit's row selection, so rows still move by dragging them. Undo is the document's.
final class GridView: NSTableView {
    weak var owner: TableView?
    var documentUndoManager: UndoManager?

    override var undoManager: UndoManager? { documentUndoManager ?? super.undoManager }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let row = row(at: point), column = column(at: point)
        guard let owner, row >= 0, column > 0 else {
            super.mouseDown(with: event)
            if row >= 0, column == 0 {
                owner?.clickRow(row, extending: event.modifierFlags.contains(.shift), toggling: event.modifierFlags.contains(.command))
            }
            return
        }
        window?.makeFirstResponder(self)  // ends typing in another cell first
        if event.clickCount == 2 { return owner.edit(row: row, column: column - 1) }
        owner.click(CellPosition(row: row, column: column - 1), extending: event.modifierFlags.contains(.shift))
        // A drag grows a block until the mouse goes up, scrolling at the edges.
        while let next = window?.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]), next.type == .leftMouseDragged {
            autoscroll(with: next)
            let at = convert(next.locationInWindow, from: nil)
            let overRow = self.row(at: at), overColumn = self.column(at: at)
            if overRow >= 0, overColumn > 0 { owner.click(CellPosition(row: overRow, column: overColumn - 1), extending: true) }
        }
    }

    override func keyDown(with event: NSEvent) {
        guard let owner, !handle(event, owner: owner) else { return }
        super.keyDown(with: event)
    }

    /// Whether the table took the key.
    private func handle(_ event: NSEvent, owner: TableView) -> Bool {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let plain = modifiers.isEmpty, shift = modifiers == .shift
        switch event.keyCode {
        case 123 where plain || shift: owner.move(rows: 0, columns: -1, extending: shift)
        case 124 where plain || shift: owner.move(rows: 0, columns: 1, extending: shift)
        case 125 where plain || shift: owner.move(rows: 1, columns: 0, extending: shift)
        case 126 where plain || shift: owner.move(rows: -1, columns: 0, extending: shift)
        case 48 where plain || shift: owner.move(rows: 0, columns: shift ? -1 : 1)  // Tab
        case 36 where plain, 76 where plain: owner.editCurrent()  // Return, Enter
        case 51 where plain, 117 where plain: owner.clearSelection()  // Delete, Forward Delete
        default:
            guard owner.canEdit, Self.types(event) else { return false }
            owner.typeOver(event)
        }
        return true
    }

    /// A key that types: no Command or Control, and characters that aren't control characters or the function keys'
    /// private-use ones. A dead key has no characters yet, and types once the field editor has it.
    static func types(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection([.command, .control]).isEmpty, let characters = event.characters else { return false }
        return characters.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) && !(0xF700...0xF8FF).contains($0.value) }
    }

    override func selectAll(_ sender: Any?) { owner?.selectAll() }

    override func becomeFirstResponder() -> Bool {
        defer { owner?.selectionChanged(scrolling: false) }
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        defer { owner?.selectionChanged(scrolling: false) }
        return super.resignFirstResponder()
    }
}

/// The column titles: a sort arrow shows on the title under the pointer (and stays on the sorted one); a click on
/// it sorts, and a click anywhere else on the title selects the column or starts dragging it.
final class TableHeaderView: NSTableHeaderView {
    weak var owner: TableView?
    /// The data column under the pointer, which shows the arrow.
    private(set) var hovered: Int? {
        didSet { if hovered != oldValue { owner?.hoveredTitleChanged() } }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.filter { $0.owner === self }.forEach(removeTrackingArea)
        addTrackingArea(
            NSTrackingArea(
                rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self))
    }

    override func mouseMoved(with event: NSEvent) { hovered = dataColumn(at: event) }
    override func mouseEntered(with event: NSEvent) { hovered = dataColumn(at: event) }
    override func mouseExited(with event: NSEvent) { hovered = nil }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let column = dataColumn(at: event), isOnArrow(point, column: column + 1) { return owner?.cycleSort(column) ?? () }
        super.mouseDown(with: event)
    }

    /// Whether `point` is on the sort arrow of the table column at `index`, a little wider than drawn.
    func isOnArrow(_ point: NSPoint, column index: Int) -> Bool {
        guard let tableView, index < tableView.numberOfColumns else { return false }
        let bounds = headerRect(ofColumn: index)
        return tableView.tableColumns[index].headerCell.sortIndicatorRect(forBounds: bounds).insetBy(dx: -4, dy: -4).contains(point)
    }

    private func dataColumn(at event: NSEvent) -> Int? {
        let index = column(at: convert(event.locationInWindow, from: nil))
        return index > 0 ? index - 1 : nil
    }
}

/// A column title that can be tinted, for columns the selection covers.
final class TableHeaderCell: NSTableHeaderCell {
    var isTinted = false

    override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
        super.draw(withFrame: cellFrame, in: controlView)
        guard isTinted else { return }
        NSColor.controlAccentColor.withAlphaComponent(0.16).setFill()
        cellFrame.fill(using: .sourceOver)
    }
}
