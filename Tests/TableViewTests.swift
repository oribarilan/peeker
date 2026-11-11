import AppKit
import PeekerKit
@testable import PeekerTable
import Testing

@MainActor private func shown(_ text: String) async throws -> (TableDocument, TableView, NSWindow) {
    let url = try TempFile.make(Data(text.utf8), name: "v.csv")
    let document = try await openDocument(url, with: TablePlugin.self, as: TableDocument.self)
    let view = try #require(document.contentView as? TableView)
    let window = offscreenWindow(holding: view)
    view.layoutSubtreeIfNeeded()
    return (document, view, window)
}

@Suite(.serialized) struct TableViewBehavior {
    @Test func columnTitlesComeFromTheHeaderOrLetters() async throws {
        let (document, view, window) = try await shown("name,price\nTea,3\n")
        defer { window.close() }
        #expect(view.tableView.tableColumns.map(\.title) == ["", "name", "price"])
        #expect(document.perform("header-row"))
        #expect(view.tableView.tableColumns.map(\.title) == ["", "A", "B"])
        #expect(view.tableView.numberOfRows == 2)
        #expect(TableView.letters(25) == "Z" && TableView.letters(26) == "AA" && TableView.letters(701) == "ZZ")
    }

    @Test func theTitlesArrowCyclesTheSort() async throws {
        let (document, view, window) = try await shown("n\n3\n1\n2\n")
        defer { window.close() }
        view.cycleSort(0)
        #expect((0..<3).map(view.fileRow) == [2, 3, 1])
        view.cycleSort(0)
        #expect((0..<3).map(view.fileRow) == [1, 3, 2])
        view.cycleSort(0)
        #expect(view.order == nil && (0..<3).map(view.fileRow) == [1, 2, 3])
        withExtendedLifetime(document) {}
    }

    @Test func movingAColumnReachesTheFile() async throws {
        let (document, view, window) = try await shown("a,b,c\n1,2,3\n")
        defer { window.close() }
        view.tableViewColumnDidMove(
            Notification(
                name: NSTableView.columnDidMoveNotification, object: view.tableView,
                userInfo: ["NSOldColumn": 3, "NSNewColumn": 1]))
        #expect(document.table.serialized(lineEnding: "\n") == "c,a,b\n3,1,2\n")
    }

    @Test func editingThroughTheTable() async throws {
        let (document, view, window) = try await shown("a,b\n1,2\n")
        defer { window.close() }
        view.edit(row: 0, column: 1)
        let field = view.editor
        #expect(field.superview === view.tableView && field.stringValue == "2")
        field.stringValue = "7"
        view.controlTextDidEndEditing(
            Notification(
                name: NSControl.textDidEndEditingNotification, object: field,
                userInfo: ["NSTextMovement": NSTextMovement.other.rawValue]))
        #expect(document.table.cell(row: 1, column: 1) == "7" && field.superview == nil)
    }
}
