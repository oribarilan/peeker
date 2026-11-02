import AppKit
import PeekerImage
import PeekerKit
import PeekerPDF
import PeekerText
import Testing

/// A plugin with a view command, a menu-only command and an edit tool.
private enum Mixed: Plugin {
    static let id = "mixed"
    static let name = "Mixed"
    static let defaultExtensions: [String] = []
    static let commands = [
        CommandSpec(id: "look", title: "Look", symbol: "eye"),
        CommandSpec(id: "zoom", title: "Zoom", symbol: "plus.magnifyingglass", shortcut: "cmd+=", showsInToolbar: false),
        CommandSpec(id: "cut", title: "Cut", symbol: "scissors", isEditTool: true),
    ]
    static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument { MixedDocument() }
}

private final class MixedDocument: PluginDocument {
    let contentView = NSView()
    var commands: [CommandSpec] { Mixed.commands }
    var editMode: EditMode { .available }
    func perform(_ id: String) -> Bool { true }
    func setEditing(_ on: Bool) {}
}

@Suite(.serialized) struct ToolbarContents {
    private func identifiers(_ controller: DocumentWindowController) throws -> [String] {
        try #require(controller.window?.toolbar?.items.map(\.itemIdentifier.rawValue))
    }

    private func command(_ controller: DocumentWindowController, _ id: String) throws -> String {
        "command.\(try #require(controller.current?.commands.firstIndex { $0.spec.id == id }))"
    }

    @Test func commandsShowInTheToolbarByDefault() {
        #expect(CommandSpec(id: "a", title: "A").showsInToolbar)
        #expect(!CommandSpec(id: "a", title: "A", showsInToolbar: false).showsInToolbar)
    }

    @Test func zoomCommandsAreMenuOnly() {
        let menuOnly = { (commands: [CommandSpec]) in commands.filter { !$0.showsInToolbar }.map(\.id) }
        #expect(menuOnly(ImagePlugin.commands) == ["zoom-in", "zoom-out", "zoom-fit", "zoom-actual"])
        #expect(menuOnly(PDFPlugin.commands) == ["zoom-in", "zoom-out"])
        #expect(menuOnly(TextPlugin.commands) == ["zoom-in", "zoom-out"])
    }

    @Test func aMenuOnlyCommandIsInViewButNotTheToolbar() async throws {
        let controller = try await documentWindow(for: Mixed.self)
        defer { controller.close() }
        try await waitUntil(seconds: 1) { (try? identifiers(controller).contains(command(controller, "look"))) == true }
        #expect(try !identifiers(controller).contains(command(controller, "zoom")))
        let main = MainMenu.make(target: nil)
        let view = try #require(main.item(withTitle: "View")?.submenu), tools = try #require(main.item(withTitle: "Tools")?.submenu)
        MainMenu.rebuildCommands(view: view, tools: tools, for: controller)
        #expect(view.items.contains { $0.title == "Zoom" && $0.keyEquivalent == "=" })
    }

    @Test func viewCommandsAndEditToolsAreSeparateGroups() async throws {
        let controller = try await documentWindow(for: Mixed.self)
        defer { controller.close() }
        try await waitUntil(seconds: 1) { (try? identifiers(controller).contains(command(controller, "look"))) == true }
        #expect(try !identifiers(controller).contains(NSToolbarItem.Identifier.space.rawValue), "one group in the read view")
        await controller.current?.toggleEditing { true }
        let items = try identifiers(controller)
        let look = try #require(items.firstIndex(of: try command(controller, "look")))
        let cut = try #require(items.firstIndex(of: try command(controller, "cut")))
        #expect(look < cut && items[look + 1] == NSToolbarItem.Identifier.space.rawValue && look + 2 == cut)
    }

    @Test func commandButtonsArriveAfterTheContentShows() async throws {
        let url = try TempFile.make(Data("x".utf8), name: "f.bin")
        let entry = PluginEntry(Mixed.self)
        let controller = DocumentWindowController(url: url, catalog: PluginCatalog(entries: [entry], config: Config()), config: Config(), recovery: nil,
                                                  recoveryClipboard: nil, sidebarMemory: SidebarMemory(defaults: nil))
        defer { controller.close() }
        var atReady: [String]?
        // The benchmark's hook: when it fires, the open's timing is over.
        controller.onDocument = { document in document.onReady = { _, _ in atReady = try? identifiers(controller) } }
        controller.show(with: entry)
        try await waitUntil(seconds: 2) { atReady != nil }
        #expect(atReady?.contains { $0.hasPrefix("command.") } == false, "no command buttons while the open is timed")
        try await waitUntil(seconds: 1) { (try? identifiers(controller).contains(command(controller, "look"))) == true }
        await controller.current?.toggleEditing { true }
        #expect(try identifiers(controller).contains(command(controller, "cut")), "later changes rebuild at once")
    }
}
