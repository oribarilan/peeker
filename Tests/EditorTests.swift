import AppKit
import PeekerKit
import Testing

/// A plugin whose documents' editability is set by the test, with one view tool and one edit tool.
private enum EditablePlugin: Plugin {
    static let id = "editable"
    static let name = "Editable"
    static let defaultExtensions: [String] = []
    static let tools = [
        ToolSpec(id: "zoom", title: "Zoom", shortcut: "cmd+="),
        ToolSpec(id: "mark", title: "Mark", shortcut: "ctrl+cmd+m", isEditTool: true),
        ToolSpec(id: "export", title: "Export Pages…", isEditTool: true, showsInToolbar: false, menu: .file),
    ]
    static var nextEditability = Editability.editable

    static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument {
        EditableDocument(editability: nextEditability)
    }
}

private final class EditableDocument: PluginDocument {
    let contentView = NSView()
    let editability: Editability
    var onEdit: (() -> Void)?
    var onReplace: ((any PluginDocument) -> Void)?
    private(set) var performed: [String] = []
    private var marks = 0

    init(editability: Editability) { self.editability = editability }

    var tools: [ToolSpec] { EditablePlugin.tools }

    func perform(_ id: String) -> Bool {
        performed.append(id)
        if id == "mark" { marks += 1; onEdit?() }
        return true
    }

    func unsavedEdits() -> UnsavedEdits? { marks > 0 ? UnsavedEdits(marks) : nil }

    func restore(encoded edits: Data) -> Bool {
        marks = (try? JSONDecoder().decode(Int.self, from: edits)) ?? 0
        if marks > 0 { onEdit?() }
        return marks > 0
    }

    func save(_ edits: UnsavedEdits, accepting offer: SaveOffer?) async throws(PluginError) { marks = 0 }
    func revertEdits() { marks = 0 }
}

/// A document with no edit tools: the defaults.
private enum PlainPlugin: Plugin {
    static let id = "plain"
    static let name = "Plain"
    static let defaultExtensions: [String] = []
    static let tools = [ToolSpec(id: "zoom", title: "Zoom")]

    static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument {
        PlainDocument()
    }
}

private final class PlainDocument: PluginDocument {
    let contentView = NSView()
    var tools: [ToolSpec] { PlainPlugin.tools }
}

@Suite struct EditabilityContract {
    @Test func documentsAreNotEditableByDefault() {
        #expect(PlainDocument().editability == .notEditable)
    }

    @Test func toolsAreNotEditToolsByDefault() {
        #expect(!ToolSpec(id: "a", title: "A").isEditTool)
        #expect(ToolSpec(id: "a", title: "A", isEditTool: true).isEditTool)
    }
}

@Suite(.serialized) struct EditorHost {
    private func open(_ editability: Editability = .editable) async throws -> DocumentViewController {
        EditablePlugin.nextEditability = editability
        let url = try TempFile.make(Data("x".utf8), name: "f.bin")
        return await loadedDocument(url, with: EditablePlugin.self)
    }

    private func plugin(_ document: DocumentViewController) throws -> EditableDocument {
        try #require(document.pluginDocument as? EditableDocument)
    }

    @Test func editToolsAreInTheToolbarFromTheStart() async throws {
        let document = try await open()
        defer { document.close() }
        #expect(document.toolbarTools.map(\.spec.id) == ["zoom", "mark"])
    }

    @Test func anEditToolRunsAtOnce() async throws {
        let document = try await open()
        defer { document.close() }
        document.run(EditablePlugin.tools[1])
        #expect(try plugin(document).performed == ["mark"])
        #expect(document.isEdited)
    }

    @Test func recoveredEditsApplyStraightAway() async throws {
        EditablePlugin.nextEditability = .editable
        let url = try TempFile.make(Data("x".utf8), name: "f.bin")
        let document = DocumentViewController(url: url, entry: PluginEntry(EditablePlugin.self), config: Config(), allowsEditing: true, recovery: nil)
        defer { document.close() }
        document.loadViewIfNeeded()
        let record = try RecoveryRecord(id: "r", url: url, pluginID: EditablePlugin.id, fileModified: nil, edits: JSONEncoder().encode(2))
        document.restore(record)
        await document.load()
        #expect(document.isEdited)
        #expect(try plugin(document).unsavedEdits() != nil)
    }
}

@Suite(.serialized) struct EditorWindow {
    private func menus() throws -> (view: NSMenu, tools: NSMenu) {
        let main = MainMenu.make(target: nil)
        return (try #require(main.item(withTitle: "View")?.submenu), try #require(main.item(withTitle: "Tools")?.submenu))
    }

    private func titles(_ menu: NSMenu) -> [String] { menu.items.map { $0.isSeparatorItem ? "-" : $0.title } }

    @Test func theToolbarHasTheEditToolsAndNoEditButton() async throws {
        EditablePlugin.nextEditability = .editable
        let controller = try await documentWindow(for: EditablePlugin.self)
        defer { controller.close() }
        let identifiers = try #require(controller.window?.toolbar?.items.map(\.itemIdentifier.rawValue))
        #expect(!identifiers.contains("edit"))
        #expect(identifiers.filter { $0.hasPrefix("tool.") } == ["tool.0", "tool.1"])
    }

    @Test func viewToolsGoInViewAndEditToolsInTools() async throws {
        EditablePlugin.nextEditability = .editable
        let editable = try await documentWindow(for: EditablePlugin.self)
        defer { editable.close() }
        let (view, tools) = try menus()
        MainMenu.rebuildTools(view: view, tools: tools, for: editable)
        #expect(titles(view) == ["Show Sidebar", "Show Toolbar", "Enter Full Screen", "-", "Zoom"])
        #expect(titles(tools) == ["Mark"])
        let mark = try #require(tools.items.last)
        #expect(mark.keyEquivalent == "m" && mark.keyEquivalentModifierMask == [.control, .command] && mark.target === editable)
    }

    @Test func fileToolsGoInFileAfterSaveAs() async throws {
        EditablePlugin.nextEditability = .editable
        let editable = try await documentWindow(for: EditablePlugin.self)
        defer { editable.close() }
        let main = MainMenu.make(target: nil)
        let (view, tools) = try menus()
        let file = try #require(main.item(withTitle: "File")?.submenu)
        MainMenu.rebuildTools(view: view, tools: tools, file: file, for: editable)
        let names = titles(file)
        let saveAs = try #require(names.firstIndex(of: "Save As…"))
        #expect(names[saveAs + 1] == "Export Pages…")
        #expect(titles(tools) == ["Mark"])
        MainMenu.rebuildTools(view: view, tools: tools, file: file, for: nil)
        #expect(!titles(file).contains("Export Pages…"), "gone with no document in front")
    }

    @Test func withoutEditToolsToolsShowsAGreyedNoToolsItem() async throws {
        EditablePlugin.nextEditability = .editable
        let editable = try await documentWindow(for: EditablePlugin.self)
        let plain = try await documentWindow(for: PlainPlugin.self)
        defer { editable.close(); plain.close() }
        let (view, tools) = try menus()
        #expect(titles(tools) == ["No Tools"], "before any window")
        MainMenu.rebuildTools(view: view, tools: tools, for: editable)
        MainMenu.rebuildTools(view: view, tools: tools, for: editable)
        #expect(titles(view).filter { $0 == "Zoom" }.count == 1 && titles(tools) == ["Mark"])
        MainMenu.rebuildTools(view: view, tools: tools, for: plain)
        #expect(titles(tools) == ["No Tools"])
        MainMenu.rebuildTools(view: view, tools: tools, for: nil)
        #expect(titles(view) == ["Show Sidebar", "Show Toolbar", "Enter Full Screen"])
        #expect(titles(tools) == ["No Tools"])
        let noTools = try #require(tools.items.first)
        #expect(noTools.action == nil, "an item without an action is greyed out")
    }

    @Test func itemsMacOSAddsSurviveARebuild() async throws {
        EditablePlugin.nextEditability = .editable
        let editable = try await documentWindow(for: EditablePlugin.self)
        defer { editable.close() }
        let (view, tools) = try menus()
        // AppKit puts Show Tab Bar and Show All Tabs at the top of a View menu.
        view.insertItem(NSMenuItem(title: "Show Tab Bar", action: nil, keyEquivalent: ""), at: 0)
        view.insertItem(.separator(), at: 1)
        MainMenu.rebuildTools(view: view, tools: tools, for: editable)
        MainMenu.rebuildTools(view: view, tools: tools, for: editable)
        #expect(titles(view) == ["Show Tab Bar", "-", "Show Sidebar", "Show Toolbar", "Enter Full Screen", "-", "Zoom"])
        MainMenu.rebuildTools(view: view, tools: tools, for: nil)
        #expect(titles(view) == ["Show Tab Bar", "-", "Show Sidebar", "Show Toolbar", "Enter Full Screen"])
    }

    @Test func commandEIsFree() {
        #expect(!MainMenu.fixedShortcuts.contains { $0.shortcut == Shortcut(parsing: "cmd+e") })
    }
}

/// The note a read-only document shows under the toolbar, if any.
@MainActor private func readOnlyNote(in document: DocumentViewController) -> String? {
    func find(_ view: NSView) -> ReadOnlyNote? { (view as? ReadOnlyNote) ?? view.subviews.lazy.compactMap(find).first }
    return find(document.view)?.reason
}

@Suite(.serialized) struct ReadOnlyEditor {
    private func window() async throws -> DocumentWindowController {
        EditablePlugin.nextEditability = .readOnly("Nope.")
        return try await documentWindow(for: EditablePlugin.self)
    }

    @Test func editToolsAreGreyedOutWithTheReasonAndViewToolsWork() async throws {
        let controller = try await window()
        defer { controller.close() }
        let main = MainMenu.make(target: nil)
        let view = try #require(main.item(withTitle: "View")?.submenu), tools = try #require(main.item(withTitle: "Tools")?.submenu)
        MainMenu.rebuildTools(view: view, tools: tools, for: controller)
        #expect(!controller.validateMenuItem(try #require(tools.item(withTitle: "Mark"))))
        #expect(controller.validateMenuItem(try #require(view.item(withTitle: "Zoom"))))
        let mark = try #require(controller.window?.toolbar?.items.first { $0.itemIdentifier.rawValue == "tool.1" })
        #expect(!controller.validateToolbarItem(mark) && mark.toolTip == "Nope.")
        let zoom = try #require(controller.window?.toolbar?.items.first { $0.itemIdentifier.rawValue == "tool.0" })
        #expect(controller.validateToolbarItem(zoom))
    }

    @Test func anEditToolsShortcutGivesTheReasonAndRunsNothing() async throws {
        let controller = try await window()
        defer { controller.close() }
        var shown: [String] = []
        controller.present = { _, title, _ in shown.append(title) }
        let window = try #require(controller.window)
        #expect(controller.handleToolKey(key("m", code: 46, in: window, modifiers: [.control, .command])))
        try await waitUntil(seconds: 1) { !shown.isEmpty }
        #expect(shown == ["Nope."])
        #expect(try #require(controller.current?.pluginDocument as? EditableDocument).performed.isEmpty)
    }

    @Test func theWindowShowsTheReasonUnderTheToolbar() async throws {
        let controller = try await window()
        defer { controller.close() }
        #expect(readOnlyNote(in: try #require(controller.current)) == "Nope.")
    }

    @Test func aReplacementThatCanBeEditedDropsTheNote() async throws {
        let controller = try await window()
        defer { controller.close() }
        let document = try #require(controller.current)
        let plugin = try #require(document.pluginDocument as? EditableDocument)
        plugin.onReplace?(EditableDocument(editability: .editable))
        #expect(readOnlyNote(in: document) == nil)
        #expect(document.unavailableReason(for: EditablePlugin.tools[1]) == nil)
    }

    @Test func thePeekPanelShowsNoNote() async throws {
        EditablePlugin.nextEditability = .readOnly("Nope.")
        let document = await loadedDocument(try TempFile.make(Data("x".utf8), name: "f.bin"), with: EditablePlugin.self, allowsEditing: false)
        defer { document.close() }
        #expect(readOnlyNote(in: document) == nil)
    }
}
