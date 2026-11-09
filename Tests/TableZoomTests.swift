import AppKit
import PeekerKit
@testable import PeekerTable
import Testing

@MainActor private func shown(_ text: String = "name,price\nTea,3\n", preferences: PluginPreferences? = nil) async throws -> (TableDocument, TableView, NSWindow) {
    let url = try TempFile.make(Data(text.utf8), name: "z.csv")
    let document = try await openDocument(url, with: TablePlugin.self, as: TableDocument.self, preferences: preferences)
    let view = try #require(document.contentView as? TableView)
    let window = offscreenWindow(holding: view)
    view.layoutSubtreeIfNeeded()
    return (document, view, window)
}

/// The size the first data cell draws its text at.
@MainActor private func cellSize(_ view: TableView) throws -> CGFloat {
    try #require(view.tableView.view(atColumn: 1, row: 0, makeIfNecessary: true) as? CellView).font.pointSize
}

@Suite(.serialized) struct TableZoomTests {
    @Test func zoomToolsAreMenuOnlyWithTheirShortcuts() {
        let zoom = TablePlugin.tools.filter { $0.id.hasPrefix("zoom-") }
        #expect(zoom.map(\.id) == ["zoom-in", "zoom-out", "zoom-actual"])
        #expect(zoom.map(\.title) == ["Zoom In", "Zoom Out", "Actual Size"])
        #expect(zoom.map(\.shortcut) == ["cmd+=", "cmd+-", "cmd+0"])
        #expect(zoom.allSatisfy { !$0.showsInToolbar && !$0.isEditTool })
    }

    @Test func zoomInGrowsTextRowsAndHeaderAndActualSizeGoesBack() async throws {
        let scratch = ScratchDefaults()
        defer { scratch.close() }
        let (document, view, window) = try await shown(preferences: scratch.preferences("table"))
        defer { window.close() }
        let table = view.tableView
        let row = table.rowHeight, header = try #require(table.headerView).frame.height, width = table.tableColumns[1].width
        let headerFont = try #require(table.tableColumns[1].headerCell.font).pointSize
        #expect(try cellSize(view) == NSFont.systemFontSize)
        #expect(document.perform("zoom-in") && document.perform("zoom-in"))
        let font = try #require(view.tableView.view(atColumn: 1, row: 0, makeIfNecessary: true) as? CellView).font
        #expect(font.pointSize == NSFont.systemFontSize + 2)
        #expect(table.rowHeight > row && table.rowHeight >= ceil(font.ascender - font.descender + font.leading), "no clipped text")
        #expect(try #require(table.headerView).frame.height > header)
        #expect(try #require(table.tableColumns[1].headerCell.font).pointSize > headerFont)
        #expect(table.tableColumns[1].width > width)
        #expect(document.perform("zoom-actual"))
        #expect(try cellSize(view) == NSFont.systemFontSize && table.rowHeight == row)
        #expect(try #require(table.headerView).frame.height == header && abs(table.tableColumns[1].width - width) < 0.01)
    }

    @Test func zoomOutStopsAtTheSmallestSize() async throws {
        let (document, view, window) = try await shown()
        defer { window.close() }
        for _ in 0..<20 { #expect(document.perform("zoom-out")) }
        #expect(try cellSize(view) == 6 && document.zoomPercent == 6 / NSFont.systemFontSize * 100)
    }

    @Test func editingACellWorksAtALargerSize() async throws {
        let (document, view, window) = try await shown()
        defer { window.close() }
        #expect(document.perform("zoom-in"))
        view.edit(row: 0, column: 1)
        let field = view.editor
        #expect(field.font?.pointSize == NSFont.systemFontSize + 1 && field.frame.height == view.tableView.rowHeight)
        document.setZoom(200, around: nil)
        #expect(field.superview != nil && field.font?.pointSize == NSFont.systemFontSize * 2, "typing goes on at the new size")
        field.stringValue = "4"
        view.controlTextDidEndEditing(Notification(name: NSControl.textDidEndEditingNotification, object: field,
                                                   userInfo: ["NSTextMovement": NSTextMovement.other.rawValue]))
        #expect(document.table.cell(row: 1, column: 1) == "4")
    }

    @Test func theSizeIsRememberedForTheNextFileOnly() async throws {
        let scratch = ScratchDefaults()
        defer { scratch.close() }
        let (first, _, window) = try await shown(preferences: scratch.preferences("table"))
        defer { window.close() }
        let (open, openView, other) = try await shown(preferences: scratch.preferences("table"))
        defer { other.close() }
        #expect(first.perform("zoom-in"))
        #expect(scratch.preferences("table").double("fontSize") == Double(NSFont.systemFontSize + 1))
        #expect(try cellSize(openView) == NSFont.systemFontSize && open.zoomPercent == 100, "a table already open keeps its size")
        let (next, nextView, third) = try await shown(preferences: scratch.preferences("table"))
        defer { third.close() }
        #expect(try cellSize(nextView) == NSFont.systemFontSize + 1 && next.zoomPercent > 100)
    }

    @Test func zoomingReportsAndSetsAPercentage() async throws {
        let scratch = ScratchDefaults()
        defer { scratch.close() }
        let (document, view, window) = try await shown(preferences: scratch.preferences("table"))
        defer { window.close() }
        var changes = 0
        document.onZoomChange = { changes += 1 }
        let base = NSFont.systemFontSize
        #expect(document.zoomPercent == 100 && !document.pinchesNatively)
        #expect(document.zoomRange == (6 / base * 100)...(72 / base * 100))
        document.setZoom(150, around: nil)
        #expect(document.zoomPercent == 150 && changes == 1)
        #expect(try cellSize(view) == base * 1.5, "fractional sizes are fine")
        #expect(scratch.preferences("table").double("fontSize") == Double(base * 1.5))
        document.setZoom(150, around: NSPoint(x: 10, y: 10))
        #expect(changes == 1, "no change, no call")
        document.setZoom(10_000, around: nil)
        #expect(try cellSize(view) == 72 && changes == 2)
        #expect(document.perform("zoom-in") && changes == 2, "at the limit nothing changes")
        #expect(document.perform("zoom-out") && changes == 3)
        #expect(document.perform("zoom-actual") && document.zoomPercent == 100 && changes == 4)
        document.setZoom(0, around: nil)
        #expect(try cellSize(view) == 6 && changes == 5)
    }
}
