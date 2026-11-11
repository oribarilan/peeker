import AppKit
import PeekerKit
@testable import PeekerTable
import Testing

@MainActor private func open(
    _ text: String, name: String = "t.csv", editing: Bool = true, preferences: PluginPreferences? = nil,
    encoding: String.Encoding = .utf8
) async throws -> (TableDocument, URL) {
    let url = try TempFile.make(try #require(text.data(using: encoding)), name: name)
    return (try await openDocument(url, with: TablePlugin.self, as: TableDocument.self, editing: editing, preferences: preferences), url)
}

@MainActor private func contents(_ url: URL) throws -> String { try String(contentsOf: url, encoding: .utf8) }

@Suite(.serialized) struct TableDocumentOpening {
    @Test func opensWithTheGuessedDelimiterAndHeader() async throws {
        let (document, _) = try await open("name;price\nTea;3,50\n")
        #expect(document.delimiter == .semicolon && document.hasHeader)
        #expect(document.table.cell(row: 1, column: 1) == "3,50")
        #expect(document.editability == .editable)
        #expect(document.isOn("header-row") == true && document.isOn("delimiter-semicolon") == true && document.isOn("delimiter-comma") == false)
    }

    @Test func aTSVIsAlwaysTabs() async throws {
        let (document, _) = try await open("a,b\tc\n", name: "t.tsv")
        #expect(document.delimiter == .tab && document.table.columnCount == 2)
    }

    @Test func thePeekPanelDoesntEdit() async throws {
        let (document, _) = try await open("a,b\n", editing: false)
        #expect(document.editability == .notEditable)
        #expect(!document.perform("add-row-below"))
        #expect(document.unsavedEdits() == nil)
    }

    @Test func aBinaryFileIsntText() async throws {
        let url = try TempFile.make(Data([0, 159, 146, 150, 0, 1]), name: "b.csv")
        await #expect(throws: PluginError.self) { _ = try await TablePlugin.open(url, context: OpenContext(maxPixels: 0, allowsEditing: true)) }
    }
}

@Suite(.serialized) struct TableDocumentEditing {
    @Test func editingACellIsOneUndoStep() async throws {
        let (document, _) = try await open("a,b\n1,2\n")
        var edits = 0
        document.onEdit = { edits += 1 }
        document.setCell("42", row: 1, column: 0)
        #expect(document.table.cell(row: 1, column: 0) == "42" && edits == 1 && document.unsavedEdits() != nil)
        document.undoManager.undo()
        #expect(document.table.cell(row: 1, column: 0) == "1" && document.unsavedEdits() == nil)
        document.undoManager.redo()
        #expect(document.table.cell(row: 1, column: 0) == "42" && document.unsavedEdits() != nil)
    }

    @Test func rowsAndColumnsComeAndGo() async throws {
        let (document, _) = try await open("a,b\n1,2\n3,4\n")
        document.removeRows(IndexSet(integer: 1))
        #expect(document.table.rowCount == 2)
        document.insertColumn(at: 0)
        #expect(document.table.columnCount == 3)
        document.moveColumn(from: 0, to: 2)
        #expect(document.table.cell(row: 0, column: 2) == "")
        document.moveRows(IndexSet(integer: 1), to: 0)
        #expect(document.table.cell(row: 0, column: 0) == "3")
        for _ in 0..<4 { document.undoManager.undo() }
        #expect(document.table.serialized(lineEnding: "\n") == "a,b\n1,2\n3,4\n" && document.unsavedEdits() == nil)
    }

    @Test func editsWhileSortedLandOnTheirRow() async throws {
        let (document, _) = try await open("n\n3\n1\n2\n")
        let view = try #require(document.contentView as? TableView)
        view.sortBy(column: 0)
        #expect((0..<3).map(view.fileRow) == [2, 3, 1])
        document.setCell("9", row: view.fileRow(0), column: 0)
        #expect(document.table.cell(row: 2, column: 0) == "9")
        view.sortBy(column: nil)
        #expect((0..<3).map(view.fileRow) == [1, 2, 3])
    }

    @Test func sortingIsntAnEdit() async throws {
        let (document, _) = try await open("n\n3\n1\n")
        try #require(document.contentView as? TableView).sortBy(column: 0, ascending: false)
        #expect(document.unsavedEdits() == nil)
    }
}

@Suite(.serialized) struct TableDocumentSaving {
    @Test func savingWritesOnlyTheChangedRow() async throws {
        let (document, url) = try await open("a , b,\"c\"\r\n1,2,3\r\nx,y,z\r\n")
        document.setCell("9", row: 1, column: 0)
        try await document.save(try #require(document.unsavedEdits()), accepting: nil)
        #expect(try contents(url) == "a , b,\"c\"\r\n9,2,3\r\nx,y,z\r\n")
        #expect(document.unsavedEdits() == nil)
    }

    @Test func aCharacterTheEncodingCantHoldOffersUTF8() async throws {
        let (document, url) = try await open("name,city\nJosé,Zürich\n", encoding: .windowsCP1252)
        document.setCell("😀", row: 1, column: 0)
        let edits = try #require(document.unsavedEdits())
        do {
            try await document.save(edits, accepting: nil)
            Issue.record("expected the UTF-8 offer")
        } catch {
            #expect(error.offer == TextFile.saveAsUTF8)
        }
        try await document.save(edits, accepting: TextFile.saveAsUTF8)
        #expect(try contents(url) == "name,city\n😀,Zürich\n")
    }

    @Test func recoveryCarriesTheTextAndRestoreBringsItBack() async throws {
        let (document, _) = try await open("a,b\n1,2\n")
        document.setCell("x", row: 1, column: 1)
        let data = try #require(document.unsavedEdits()).encoded()
        #expect(TablePlugin.recoveryText(from: data) == "a,b\n1,x\n")
        let (fresh, _) = try await open("a,b\n1,2\n")
        #expect(fresh.restore(encoded: data))
        #expect(fresh.table.cell(row: 1, column: 1) == "x" && fresh.unsavedEdits() != nil)
    }

    @Test func revertGoesBackToTheFile() async throws {
        let (document, _) = try await open("a,b\n1,2\n")
        document.setCell("x", row: 1, column: 1)
        document.revertEdits()
        #expect(document.table.cell(row: 1, column: 1) == "2" && document.unsavedEdits() == nil)
    }

    @Test func saveAsWritesTheCopyAndFollowsIt() async throws {
        let (document, url) = try await open("a\n1\n")
        document.setCell("2", row: 1, column: 0)
        let copy = url.deletingLastPathComponent().appendingPathComponent("copy-\(UUID().uuidString).csv")
        try await document.saveAs(document.unsavedEdits(), to: copy, accepting: nil)
        #expect(try contents(copy) == "a\n2\n")
        #expect(try contents(url) == "a\n1\n" && document.url == copy)
    }
}

@Suite(.serialized) struct TableDocumentChoices {
    @Test func headerAndDelimiterAreRememberedPerFile() async throws {
        let scratch = ScratchDefaults()
        defer { scratch.close() }
        let (document, url) = try await open("a,b\n1,2\n", preferences: scratch.preferences("table"))
        #expect(document.perform("header-row") && !document.hasHeader)
        #expect(document.perform("delimiter-semicolon") && document.table.columnCount == 1)
        let again = try await openDocument(url, with: TablePlugin.self, as: TableDocument.self, preferences: scratch.preferences("table"))
        #expect(again.delimiter == .semicolon && !again.hasHeader)
    }

    @Test func aDelimiterSwitchIsntAnEdit() async throws {
        let (document, _) = try await open("a;b\n")
        #expect(document.perform("delimiter-semicolon"))
        #expect(document.table.columnCount == 2 && document.unsavedEdits() == nil)
    }
}

/// Found in review: states counted up and down, edits typed during a reload, an empty last row.
@Suite(.serialized) struct TableDocumentReviewFixes {
    @Test func anEditAfterUndoingPastASaveIsUnsaved() async throws {
        let (document, url) = try await open("a,b\n1,2\n")
        document.setCell("A", row: 1, column: 0)
        try await document.save(try #require(document.unsavedEdits()), accepting: nil)
        document.undoManager.undo()
        #expect(document.unsavedEdits() != nil, "the table is back to the file before the save")
        document.setCell("B", row: 1, column: 1)
        try await document.save(try #require(document.unsavedEdits(), "B isn't saved"), accepting: nil)
        #expect(try contents(url) == "a,b\n1,B\n")
    }

    @Test func aSaveMarksSavedOnlyWhatItWrote() async throws {
        let (document, _) = try await open("a\n1\n")
        document.setCell("2", row: 1, column: 0)
        let edits = try #require(document.unsavedEdits())
        document.setCell("3", row: 1, column: 0)  // after the snapshot the save writes
        try await document.save(edits, accepting: nil)
        #expect(document.unsavedEdits() != nil)
    }

    @Test func textBeingTypedIsCommittedBeforeRowsChange() async throws {
        let url = try TempFile.make(Data("a\n1\n2\n3\n".utf8), name: "e.csv")
        let document = try await openDocument(url, with: TablePlugin.self, as: TableDocument.self)
        let view = try #require(document.contentView as? TableView)
        let window = offscreenWindow(holding: view)
        defer { window.close() }
        view.edit(row: 0, column: 0)  // file row 1, "1"
        let field = try #require(window.firstResponder as? NSTextView)
        field.string = "typed"
        #expect(document.perform("add-row-above"))
        #expect((1..<document.table.rowCount).map { document.table.cell(row: $0, column: 0) }.contains("typed"))
        #expect(document.table.cell(row: 2, column: 0) == "typed", "on the row it was typed in, now one lower")
    }

    @Test func anEmptyLastRowSurvivesWithoutAFinalLineBreak() async throws {
        let (document, url) = try await open("a,b\n1,2")
        document.insertRows([CSVTable.emptyRow], at: IndexSet(integer: 2))
        try await document.save(try #require(document.unsavedEdits()), accepting: nil)
        let reopened = try await openDocument(url, with: TablePlugin.self, as: TableDocument.self)
        #expect(reopened.table.rowCount == 3)
    }

    @Test func recoveredTextLikeTheFileIsntAnEdit() async throws {
        let (document, _) = try await open("a\n1\n")
        #expect(document.restore(encoded: try JSONEncoder().encode(TextEdits(text: "a\n1\n"))))
        #expect(document.unsavedEdits() == nil)
    }
}

@Suite(.serialized) struct TableDocumentLimits {
    @Test func aFileOver50MBIsReadOnly() async throws {
        let row = "1,2,3,4,5,6,7,8,9,10\n"
        let url = try TempFile.make(Data(String(repeating: row, count: 51 * 1_048_576 / row.utf8.count + 1).utf8), name: "big.csv")
        let document = try await openDocument(url, with: TablePlugin.self, as: TableDocument.self)
        #expect(document.editability == .readOnly(TablePlugin.readOnlyReason))
        #expect(!document.perform("add-row-below") && document.unsavedEdits() == nil)
    }

    @Test func reloadShowsTheFileAsItIsNow() async throws {
        let url = try TempFile.make(Data("a\n1\n".utf8), name: "r.csv")
        let document = try await openDocument(url, with: TablePlugin.self, as: TableDocument.self)
        try Data("a\n1\n2\n".utf8).write(to: url)
        #expect(try await document.reload())
        #expect(document.table.rowCount == 3 && document.unsavedEdits() == nil)
    }
}
