import AppKit
import PeekerImage
import PeekerKit
import PeekerMarkdown
import PeekerPDF
import PeekerText
import Testing

/// A plugin with a view tool, a menu-only tool and an edit tool.
private enum Mixed: Plugin {
    static let id = "mixed"
    static let name = "Mixed"
    static let defaultExtensions: [String] = []
    static let tools = [
        ToolSpec(id: "look", title: "Look", symbol: "eye"),
        ToolSpec(id: "zoom", title: "Zoom", symbol: "plus.magnifyingglass", shortcut: "cmd+=", showsInToolbar: false),
        ToolSpec(id: "cut", title: "Cut", symbol: "scissors", isEditTool: true),
    ]
    static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument { MixedDocument() }
}

private final class MixedDocument: PluginDocument {
    let contentView = NSView()
    var tools: [ToolSpec] { Mixed.tools }
    var editability: Editability { .editable }
    func perform(_ id: String) -> Bool { true }
}

@Suite(.serialized) struct ToolbarContents {
    private func identifiers(_ controller: DocumentWindowController) throws -> [String] {
        try #require(controller.window?.toolbar?.items.map(\.itemIdentifier.rawValue))
    }

    private func command(_ controller: DocumentWindowController, _ id: String) throws -> String {
        "tool.\(try #require(controller.current?.tools.firstIndex { $0.spec.id == id }))"
    }

    @Test func commandsShowInTheToolbarByDefault() {
        #expect(ToolSpec(id: "a", title: "A").showsInToolbar)
        #expect(!ToolSpec(id: "a", title: "A", showsInToolbar: false).showsInToolbar)
    }

    @Test func zoomAndPageToolsAreMenuOnly() {
        let menuOnly = { (tools: [ToolSpec]) in tools.filter { !$0.showsInToolbar }.map(\.id) }
        #expect(menuOnly(ImagePlugin.tools) == ["zoom-in", "zoom-out", "zoom-fit", "zoom-actual", "previous-page", "next-page", "play-animation", "markup-arrow", "markup-line", "markup-box", "markup-text", "markup-pixelate", "markup-step", "markup-pen", "markup-marker", "markup-spotlight"])
        #expect(menuOnly(PDFPlugin.tools) == ["zoom-in", "zoom-out", "zoom-fit", "zoom-actual", "insert-pages", "save-selected-pages", "split"])
        #expect(menuOnly(TextPlugin.tools) == ["zoom-in", "zoom-out", "zoom-actual"])
        #expect(menuOnly(MarkdownPlugin.tools) == ["zoom-in", "zoom-out", "zoom-actual"])
    }

    @Test func aMenuOnlyToolIsInViewButNotTheToolbar() async throws {
        let controller = try await documentWindow(for: Mixed.self)
        defer { controller.close() }
        try await waitUntil(seconds: 1) { (try? identifiers(controller).contains(command(controller, "look"))) == true }
        #expect(try !identifiers(controller).contains(command(controller, "zoom")))
        let main = MainMenu.make(target: nil)
        let view = try #require(main.item(withTitle: "View")?.submenu), tools = try #require(main.item(withTitle: "Tools")?.submenu)
        MainMenu.rebuildTools(view: view, tools: tools, for: controller)
        #expect(view.items.contains { $0.title == "Zoom" && $0.keyEquivalent == "=" })
    }

    @Test func viewToolsAndEditToolsAreSeparateGroups() async throws {
        let controller = try await documentWindow(for: Mixed.self)
        defer { controller.close() }
        try await waitUntil(seconds: 1) { (try? identifiers(controller).contains(command(controller, "look"))) == true }
        let items = try identifiers(controller)
        let look = try #require(items.firstIndex(of: try command(controller, "look")))
        let cut = try #require(items.firstIndex(of: try command(controller, "cut")))
        #expect(look < cut && items[look + 1] == NSToolbarItem.Identifier.space.rawValue && look + 2 == cut)
    }

    @Test func toolButtonsArriveAfterTheContentShows() async throws {
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
        #expect(atReady?.contains { $0.hasPrefix("tool.") } == false, "no tool buttons while the open is timed")
        try await waitUntil(seconds: 1) { (try? identifiers(controller).contains(command(controller, "look"))) == true }
        #expect(try identifiers(controller).contains(command(controller, "cut")), "later changes rebuild at once")
    }
}
