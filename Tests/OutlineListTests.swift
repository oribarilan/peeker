import AppKit
@testable import PeekerMarkdown
import Testing

@MainActor private func outline(_ anchors: @escaping (Int) -> Void = { _ in }) -> (OutlineList, NSWindow) {
    let items = [OutlineItem(title: "One", level: 1, line: 1), OutlineItem(title: "Two", level: 2, line: 3),
                 OutlineItem(title: "Three", level: 2, line: 5)]
    let list = OutlineList(items: items, onAnchor: anchors)
    let window = offscreenWindow(holding: list, width: 220, height: 300)
    list.layoutSubtreeIfNeeded()
    return (list, window)
}

/// A mouse event of `type` over the middle of `row`, or outside the list for -1.
@MainActor private func mouse(_ type: NSEvent.EventType, over row: Int, in list: OutlineList) -> NSEvent {
    let point = row < 0 ? NSPoint(x: -50, y: -50) : list.table.convert(NSPoint(x: list.table.rect(ofRow: row).midX, y: list.table.rect(ofRow: row).midY), to: nil)
    return NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: 0, windowNumber: list.window?.windowNumber ?? 0,
                              context: nil, eventNumber: 0, clickCount: 0, pressure: 0)!
}

@Suite struct OutlineListHover {
    @Test func aRowHighlightsWhileThePointerIsOverIt() {
        var anchors: [Int] = []
        let (list, window) = outline { anchors.append($0) }
        defer { window.close() }
        list.mouseMoved(with: mouse(.mouseMoved, over: 1, in: list))
        #expect(list.hoveredRow == 1)
        #expect((list.table.rowView(atRow: 1, makeIfNecessary: false) as? OutlineRowView)?.isHovered == true)
        list.mouseMoved(with: mouse(.mouseMoved, over: 2, in: list))
        #expect(list.hoveredRow == 2)
        #expect((list.table.rowView(atRow: 1, makeIfNecessary: false) as? OutlineRowView)?.isHovered == false)
        list.mouseExited(with: mouse(.mouseMoved, over: -1, in: list))
        #expect(list.hoveredRow == nil)
        #expect(list.table.selectedRow == -1, "hovering selects nothing")
        #expect(anchors.isEmpty, "and jumps nowhere")
    }

    @Test func markSelectsARowOrNoneWithoutJumping() {
        var anchors: [Int] = []
        let (list, window) = outline { anchors.append($0) }
        defer { window.close() }
        list.mark(2)
        #expect(list.table.selectedRow == 2)
        list.mark(nil)
        #expect(list.table.selectedRow == -1)
        list.mark(7)
        #expect(list.table.selectedRow == -1, "a row that isn't there marks nothing")
        #expect(anchors.isEmpty)
    }
}
