import AppKit
import PeekerKit
import Testing

private enum ToolPlugin: Plugin {
    static let id = "tool"
    static let name = "Tool"
    static let defaultExtensions: [String] = []
    static let tools = [ToolSpec(id: "pen", title: "Pen", symbol: "pencil"), ToolSpec(id: "turn", title: "Turn", symbol: "rotate.left")]

    static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument { ToolDocument() }
}

private final class ToolDocument: PluginDocument {
    let contentView = NSView()
    var tools: [ToolSpec] { ToolPlugin.tools }
    var activeTool: String? { didSet { onActiveToolChange?() } }
    var onActiveToolChange: (() -> Void)?
    func perform(_ id: String) -> Bool { true }
}

/// A document names the tool waiting for the user; the window shows it as the toolbar's selected item and checks
/// its menu item.
@Suite(.serialized) struct ActiveTools {
    private func menuItem(_ index: Int) -> NSMenuItem {
        let item = NSMenuItem(title: "", action: #selector(DocumentWindowController.runTool(_:)), keyEquivalent: "")
        item.tag = index
        return item
    }

    @Test func documentsNameNoActiveToolByDefault() {
        final class Plain: PluginDocument { let contentView = NSView() }
        #expect(Plain().activeTool == nil)
    }

    private func style(_ controller: DocumentWindowController, _ index: Int) throws -> NSToolbarItem.Style {
        try #require(controller.window?.toolbar?.items.first { $0.itemIdentifier.rawValue == "tool.\(index)" }).style
    }

    @Test func theActiveToolIsFilledAndChecked() async throws {
        let controller = try await documentWindow(for: ToolPlugin.self)
        defer { controller.close() }
        let document = try #require(controller.current?.pluginDocument as? ToolDocument)
        try await waitUntil(seconds: 1) { (try? style(controller, 1)) != nil }
        #expect(try style(controller, 0) == .plain)
        document.activeTool = "pen"
        #expect(try style(controller, 0) == .prominent && style(controller, 1) == .plain)
        let pen = menuItem(0), turn = menuItem(1)
        _ = controller.validateMenuItem(pen)
        _ = controller.validateMenuItem(turn)
        #expect(pen.state == .on && turn.state == .off)
        document.activeTool = nil
        #expect(try style(controller, 0) == .plain)
        _ = controller.validateMenuItem(pen)
        #expect(pen.state == .off)
    }

    @Test func toolsAreNotSelectableSoTheyKeepTheirCapsules() async throws {
        let controller = try await documentWindow(for: ToolPlugin.self)
        defer { controller.close() }
        let toolbar = try #require(controller.window?.toolbar)
        #expect((controller as NSToolbarDelegate).toolbarSelectableItemIdentifiers?(toolbar).isEmpty ?? true)
    }

    @Test func aToolActiveWhenTheToolbarIsBuiltStartsFilled() async throws {
        let controller = try await documentWindow(for: ToolPlugin.self)
        defer { controller.close() }
        let document = try #require(controller.current?.pluginDocument as? ToolDocument)
        document.activeTool = "turn"
        var config = Config()
        config.showShortcuts = false
        controller.apply(config)  // rebuilds the toolbar
        try await waitUntil(seconds: 1) { (try? style(controller, 1)) == .prominent }
    }
}
