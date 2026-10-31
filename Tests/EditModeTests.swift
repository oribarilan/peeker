import AppKit
import PeekerKit
import Testing

/// A plugin whose documents have an edit mode, set by the test, with one view command and one editing tool.
private enum EditablePlugin: Plugin {
    static let id = "editable"
    static let name = "Editable"
    static let defaultExtensions: [String] = []
    static let commands = [
        CommandSpec(id: "zoom", title: "Zoom", shortcut: "cmd+="),
        CommandSpec(id: "mark", title: "Mark", shortcut: "ctrl+cmd+m", isEditTool: true),
    ]
    static var nextMode = EditMode.available

    static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument {
        EditableDocument(editMode: nextMode)
    }
}

private final class EditableDocument: PluginDocument {
    let contentView = NSView()
    let editMode: EditMode
    var onEdit: (() -> Void)?
    private(set) var editingCalls: [Bool] = []
    private(set) var performed: [String] = []
    private var marks = 0
    private(set) var editingWhenRestored: Bool?

    init(editMode: EditMode) { self.editMode = editMode }

    var commands: [CommandSpec] { EditablePlugin.commands }
    var isEditing: Bool { editingCalls.last ?? false }

    func setEditing(_ on: Bool) { editingCalls.append(on) }

    func perform(_ id: String) -> Bool {
        performed.append(id)
        if id == "mark" { marks += 1; onEdit?() }
        return true
    }

    func unsavedEdits() -> UnsavedEdits? { marks > 0 ? UnsavedEdits(marks) : nil }

    func restore(encoded edits: Data) -> Bool {
        editingWhenRestored = isEditing
        marks = (try? JSONDecoder().decode(Int.self, from: edits)) ?? 0
        if marks > 0 { onEdit?() }
        return marks > 0
    }

    func save(_ edits: UnsavedEdits, accepting offer: SaveOffer?) async throws(PluginError) { marks = 0 }
    func revertEdits() { marks = 0 }
}

/// A document without an edit mode: the defaults.
private enum PlainPlugin: Plugin {
    static let id = "plain"
    static let name = "Plain"
    static let defaultExtensions: [String] = []
    static let commands = [CommandSpec(id: "zoom", title: "Zoom")]

    static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument {
        PlainDocument()
    }
}

private final class PlainDocument: PluginDocument {
    let contentView = NSView()
    var commands: [CommandSpec] { PlainPlugin.commands }
}

@Suite struct EditModeContract {
    @Test func documentsHaveNoEditModeByDefault() {
        #expect(PlainDocument().editMode == .none)
    }

    @Test func commandsAreNotEditToolsByDefault() {
        #expect(!CommandSpec(id: "a", title: "A").isEditTool)
        #expect(CommandSpec(id: "a", title: "A", isEditTool: true).isEditTool)
    }
}

@Suite(.serialized) struct EditModeHost {
    private func open(_ mode: EditMode = .available, plugin: any Plugin.Type = EditablePlugin.self) async throws -> DocumentViewController {
        EditablePlugin.nextMode = mode
        let url = try TempFile.make(Data("x".utf8), name: "f.bin")
        return await loadedDocument(url, with: plugin)
    }

    private func plugin(_ document: DocumentViewController) throws -> EditableDocument {
        try #require(document.pluginDocument as? EditableDocument)
    }

    @Test func opensInTheReadViewWithToolsLeftOutOfTheToolbar() async throws {
        let document = try await open()
        defer { document.close() }
        #expect(!document.isEditing)
        #expect(document.toolbarCommands.map(\.spec.id) == ["zoom"])
        #expect(document.commands.map(\.spec.id) == ["zoom", "mark"], "the menu still lists the tools")
    }

    @Test func editModeShowsTheToolsAndTellsTheDocument() async throws {
        let document = try await open()
        defer { document.close() }
        var changes = 0
        document.onCommandsChanged = { _ in changes += 1 }
        await document.toggleEditing { true }
        #expect(document.isEditing)
        #expect(try plugin(document).editingCalls == [true])
        #expect(document.toolbarCommands.map(\.spec.id) == ["zoom", "mark"])
        #expect(changes == 1)
    }

    @Test func aToolRunFromTheReadViewTurnsEditModeOnFirst() async throws {
        let document = try await open()
        defer { document.close() }
        document.run(EditablePlugin.commands[1])
        #expect(document.isEditing)
        #expect(try plugin(document).editingCalls == [true])
        #expect(try plugin(document).performed == ["mark"])
        #expect(document.isEdited)
    }

    @Test func aViewCommandLeavesTheReadViewAlone() async throws {
        let document = try await open()
        defer { document.close() }
        document.run(EditablePlugin.commands[0])
        #expect(!document.isEditing)
        #expect(try plugin(document).performed == ["zoom"])
    }

    @Test func anUnavailableDocumentRefusesWithItsReason() async throws {
        let document = try await open(.unavailable(reason: "Nope."))
        defer { document.close() }
        var refusals: [String] = []
        document.onEditRefused = { _, reason in refusals.append(reason) }
        document.run(EditablePlugin.commands[1])
        await document.toggleEditing { true }
        #expect(refusals == ["Nope.", "Nope."])
        #expect(!document.isEditing)
        #expect(try plugin(document).performed.isEmpty)
        #expect(try plugin(document).editingCalls.isEmpty)
    }

    @Test func aDocumentWithoutAnEditModeBehavesAsBefore() async throws {
        let document = try await open(plugin: PlainPlugin.self)
        defer { document.close() }
        await document.toggleEditing { true }
        #expect(!document.isEditing)
        #expect(document.editMode == .none)
        #expect(document.toolbarCommands.map(\.spec.id) == ["zoom"])
    }

    @Test func leavingAsksAndCancelStaysInEditMode() async throws {
        let document = try await open()
        defer { document.close() }
        document.run(EditablePlugin.commands[1])
        var asked = 0
        await document.toggleEditing { asked += 1; return false }
        #expect(asked == 1)
        #expect(document.isEditing && document.isEdited)
    }

    @Test func leavingWithSaveSavesAndLeaves() async throws {
        let document = try await open()
        defer { document.close() }
        document.run(EditablePlugin.commands[1])
        await document.toggleEditing { await document.save(prompts: StubPrompts()) == .saved }
        #expect(!document.isEditing && !document.isEdited)
        #expect(try plugin(document).editingCalls == [true, false])
    }

    @Test func leavingWithDontSaveDropsTheEditsAndLeaves() async throws {
        let document = try await open()
        defer { document.close() }
        document.run(EditablePlugin.commands[1])
        await document.toggleEditing { document.discardEdits(); return true }
        #expect(!document.isEditing && !document.isEdited)
        #expect(try plugin(document).unsavedEdits() == nil)
    }

    @Test func savingKeepsEditMode() async throws {
        let document = try await open()
        defer { document.close() }
        document.run(EditablePlugin.commands[1])
        #expect(await document.save(prompts: StubPrompts()) == .saved)
        #expect(document.isEditing)
    }

    @Test func recoveredEditsReopenInEditMode() async throws {
        EditablePlugin.nextMode = .available
        let url = try TempFile.make(Data("x".utf8), name: "f.bin")
        let document = DocumentViewController(url: url, entry: PluginEntry(EditablePlugin.self), config: Config(), allowsEditing: true, recovery: nil)
        defer { document.close() }
        document.loadViewIfNeeded()
        let record = try RecoveryRecord(id: "r", url: url, pluginID: EditablePlugin.id, fileModified: nil, edits: JSONEncoder().encode(2))
        document.restore(record)
        await document.load()
        #expect(document.isEditing && document.isEdited)
        #expect(try plugin(document).editingWhenRestored == true)
    }
}

@Suite(.serialized) struct EditModeMenu {
    @Test func editModeIsListedOnlyForDocumentsWithOne() async throws {
        EditablePlugin.nextMode = .available
        let editable = try await documentWindow(for: EditablePlugin.self)
        let plain = try await documentWindow(for: PlainPlugin.self)
        defer { editable.close(); plain.close() }
        let menu = NSMenu(title: "Commands")
        MainMenu.rebuildCommands(menu, for: editable)
        let item = try #require(menu.items.first)
        #expect(item.title == "Edit Mode" && item.keyEquivalent == "e" && item.keyEquivalentModifierMask == .command)
        #expect(item.state == .off)
        #expect(menu.items.compactMap { $0.isSeparatorItem ? nil : $0.title } == ["Edit Mode", "Zoom", "Mark"])
        await editable.current?.toggleEditing { true }
        MainMenu.rebuildCommands(menu, for: editable)
        #expect(menu.items.first?.state == .on)
        MainMenu.rebuildCommands(menu, for: plain)
        #expect(menu.items.map(\.title) == ["Zoom"])
    }
}
