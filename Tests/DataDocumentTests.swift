import AppKit
import PeekerKit
@testable import PeekerData
import Testing

@MainActor private func open(
    _ text: String, name: String = "d.json", editing: Bool = true, preferences: PluginPreferences? = nil,
    encoding: String.Encoding = .utf8
) async throws -> (DataDocument, URL, NSWindow) {
    let url = try TempFile.make(try #require(text.data(using: encoding)), name: name)
    let document = try await openDocument(url, with: DataPlugin.self, as: DataDocument.self, editing: editing, preferences: preferences)
    let window = offscreenWindow(holding: document.contentView)
    document.contentView.layoutSubtreeIfNeeded()
    return (document, url, window)
}

@MainActor private func contents(_ url: URL) throws -> String { try String(contentsOf: url, encoding: .utf8) }

@Suite(.serialized) struct DataDocumentViews {
    @Test func opensAsATreeWithTheFirstLevelOpen() async throws {
        let (document, _, window) = try await open(#"{"name": "app", "deps": {"a": 1, "b": 2}}"#)
        defer { window.close() }
        #expect(document.root?.children.map(\.key) == ["name", "deps"] && document.error == nil)
        #expect(!document.tree.isHidden && document.isOn("show-text") == false)
        #expect(document.tree.outlineView.numberOfRows == 4, "name, deps, and deps' a and b")
        #expect(DataTreeView.shown(try #require(document.root?.children[1])) == "2 keys")
    }

    @Test func showTextIsRememberedForTheNextFile() async throws {
        let scratch = ScratchDefaults()
        defer { scratch.close() }
        let (document, _, window) = try await open(#"{"a": 1}"#, preferences: scratch.preferences("data"))
        defer { window.close() }
        #expect(document.perform("show-text") && document.isOn("show-text") == true && document.tree.isHidden)
        let (next, _, other) = try await open(#"{"b": 2}"#, preferences: scratch.preferences("data"))
        defer { other.close() }
        #expect(next.isOn("show-text") == true && next.tree.isHidden)
    }

    @Test func aBadFileOpensInTheTextWithTheError() async throws {
        let (document, _, window) = try await open("{\n  \"a\": 1\n  \"b\": 2\n}")
        defer { window.close() }
        #expect(document.root == nil && document.error?.line == 3 && document.tree.isHidden)
        #expect(document.unavailableReason(for: "show-text")?.contains("Line 3") == true)
        #expect(!document.perform("show-text"))
    }

    @Test func editingTheTextUpdatesTheTreeAndFixesTheError() async throws {
        let (document, _, window) = try await open("{\"a\": 1 \"b\": 2}")
        defer { window.close() }
        document.textView.insertText(",", replacementRange: NSRange(location: 8, length: 0))
        document.reparse()
        #expect(document.error == nil && document.root?.children.count == 2 && !document.tree.isHidden)
    }

    @Test func thePeekPanelAndLargeFilesDontEdit() async throws {
        let (panel, _, window) = try await open(#"{"a": 1}"#, editing: false)
        defer { window.close() }
        #expect(panel.editability == .notEditable && !panel.perform("add-item"))
        let big = "[" + String(repeating: "1234567890,", count: 1_000_000) + "0]"
        let (large, _, other) = try await open(big)
        defer { other.close() }
        if case .readOnly = large.editability {} else { Issue.record("a file over 10 MB should be read-only") }
    }

    @Test func theOutlineListsTheTopLevel() async throws {
        let (document, _, window) = try await open(#"{"name": "app", "scripts": {"build": "x"}}"#)
        defer { window.close() }
        let panels = document.makeSidebar()
        let list = try #require(panels.first?.view as? DataOutlineList)
        #expect(list.table.numberOfRows == 2)
        document.go(toTopLevel: 1)
        #expect(document.tree.selectedNodes.first?.key == "scripts")
    }
}

@Suite(.serialized) struct DataDocumentEditing {
    @Test func treeEditsChangeOnlyTheirTextAndUndoAsOneStep() async throws {
        let text = "{\n  \"a\": 1, // keep me\n  \"b\": 2\n}\n"
        let (document, url, window) = try await open(text)
        defer { window.close() }
        var edits = 0
        document.onEdit = { edits += 1 }
        document.setValue(try #require(document.root?.children[0]), to: "5")
        #expect(document.text == "{\n  \"a\": 5, // keep me\n  \"b\": 2\n}\n" && edits >= 1)
        #expect(document.root?.children[0].value == "5")
        document.undoManager.undo()
        #expect(document.text == text)
        document.undoManager.redo()
        try await document.save(try #require(document.unsavedEdits()), accepting: nil)
        #expect(try contents(url) == "{\n  \"a\": 5, // keep me\n  \"b\": 2\n}\n" && document.unsavedEdits() == nil)
    }

    @Test func addingRenamingMovingAndDeleting() async throws {
        let (document, _, window) = try await open("{\n  \"a\": 1,\n  \"b\": 2\n}")
        defer { window.close() }
        document.tree.select(try #require(document.root?.children[1]))
        #expect(document.perform("add-item"))
        document.tree.commitEditing()
        #expect(document.text == "{\n  \"a\": 1,\n  \"b\": 2,\n  \"key\": null\n}")
        document.rename(try #require(document.root?.children[2]), to: "c")
        document.move(try #require(document.root?.children[2]), to: 0)
        #expect(document.text == "{\n  \"c\": null,\n  \"a\": 1,\n  \"b\": 2\n}")
        document.tree.select(try #require(document.root?.children[1]))
        #expect(document.perform("delete-item"))
        #expect(document.text == "{\n  \"c\": null,\n  \"b\": 2\n}")
    }

    @Test func aCharacterTheEncodingCantHoldOffersUTF8() async throws {
        let (document, url, window) = try await open(#"{"city": "Zürich"}"#, encoding: .windowsCP1252)
        defer { window.close() }
        document.setValue(try #require(document.root?.children[0]), to: "😀")
        let edits = try #require(document.unsavedEdits())
        do {
            try await document.save(edits, accepting: nil)
            Issue.record("expected the UTF-8 offer")
        } catch {
            #expect(error.offer == TextFile.saveAsUTF8)
        }
        try await document.save(edits, accepting: TextFile.saveAsUTF8)
        #expect(try contents(url) == #"{"city": "😀"}"#)
    }

    @Test func recoveryRevertAndReload() async throws {
        let (document, url, window) = try await open(#"{"a": 1}"#)
        defer { window.close() }
        document.setValue(try #require(document.root?.children[0]), to: "2")
        let data = try #require(document.unsavedEdits()).encoded()
        #expect(DataPlugin.recoveryText(from: data) == #"{"a": 2}"#)
        document.revertEdits()
        #expect(document.text == #"{"a": 1}"# && document.unsavedEdits() == nil)
        #expect(document.restore(encoded: data) && document.root?.children[0].value == "2")
        document.revertEdits()
        try Data(#"{"a": 3}"#.utf8).write(to: url)
        #expect(try await document.reload())
        #expect(document.root?.children[0].value == "3")
    }

    @Test func editingAValueThroughTheTree() async throws {
        let (document, _, window) = try await open(#"{"a": 1, "b": "x"}"#)
        defer { window.close() }
        let node = try #require(document.root?.children[1])
        document.tree.edit(node, key: false)
        #expect(document.tree.editor.superview != nil && document.tree.editor.stringValue == "x")
        document.tree.editor.stringValue = "y"
        document.tree.controlTextDidEndEditing(Notification(name: NSControl.textDidEndEditingNotification, object: document.tree.editor))
        #expect(document.text == #"{"a": 1, "b": "y"}"#)
    }
}

@Suite(.serialized) struct DataDocumentReviewFixes {
    @Test func deletingSeveralItemsLeavesValidJSON() async throws {
        let (document, _, window) = try await open("{\n  \"a\": 1,\n  \"b\": 2,\n  \"c\": 3\n}")
        defer { window.close() }
        let rows = IndexSet([1, 2])
        document.tree.outlineView.selectRowIndexes(rows, byExtendingSelection: false)
        #expect(document.perform("delete-item"))
        #expect(document.text == "{\n  \"a\": 1\n}")
        let (array, _, other) = try await open("[1, 2, 3]")
        defer { other.close() }
        array.tree.outlineView.selectAll(nil)
        #expect(array.perform("delete-item"))
        #expect(array.error == nil && array.root?.children.isEmpty == true)
    }

    @Test func aCellBeingEditedIsCommittedBeforeATreeEdit() async throws {
        let (document, _, window) = try await open(#"{"a": 1, "b": 2, "c": 3}"#)
        defer { window.close() }
        let b = try #require(document.root?.children[1])
        document.tree.select(b)
        document.tree.edit(b, key: false)
        document.tree.editor.stringValue = "9"
        #expect(document.perform("delete-item"))
        #expect(document.text == #"{"a": 1, "c": 3}"#)
    }

    @Test func undoThenAnotherEditRightAway() async throws {
        let (document, _, window) = try await open("{\n  \"a\": 1\n}")
        defer { window.close() }
        #expect(document.perform("add-item"))
        document.tree.commitEditing()
        document.undoManager.undo()
        #expect(document.perform("add-item"))
        document.tree.commitEditing()
        #expect(document.error == nil && document.root?.children.count == 2)
    }

    @Test func closingAnEditorWithoutTypingChangesNothing() async throws {
        let (document, _, window) = try await open(#"{"a": "café"}"#)
        defer { window.close() }
        let node = try #require(document.root?.children[0])
        document.tree.edit(node, key: false)
        document.tree.commitEditing()
        #expect(document.unsavedEdits() == nil && !document.undoManager.canUndo)
    }

    @Test func fixingTheTextKeepsTheText() async throws {
        let (document, _, window) = try await open("{\"a\": 1 \"b\": 2}")
        defer { window.close() }
        window.makeFirstResponder(document.textView)
        document.textView.insertText(",", replacementRange: NSRange(location: 8, length: 0))
        document.reparse()
        #expect(document.error == nil && document.isOn("show-text") == true && document.tree.isHidden)
    }

    @Test func aScalarFileHasNoItemsToChange() async throws {
        let (document, _, window) = try await open("42")
        defer { window.close() }
        #expect(document.unavailableReason(for: "add-item") != nil && document.unavailableReason(for: "delete-item") != nil)
    }

    @Test func overSixteenMegabytesShowsTextOnly() async throws {
        let big = "[" + String(repeating: "\"abcdefghij\",", count: 1_500_000) + "0]"
        let (document, _, window) = try await open(big)
        defer { window.close() }
        #expect(document.root == nil && document.tree.isHidden)
        #expect(document.unavailableReason(for: "show-text") == DataDocument.textOnlyReason)
    }
}
