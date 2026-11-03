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

    @Test func theActiveToolIsSelectedAndChecked() async throws {
        let controller = try await documentWindow(for: ToolPlugin.self)
        defer { controller.close() }
        let document = try #require(controller.current?.pluginDocument as? ToolDocument)
        let toolbar = try #require(controller.window?.toolbar)
        #expect(toolbar.selectedItemIdentifier == nil)
        document.activeTool = "pen"
        #expect(toolbar.selectedItemIdentifier?.rawValue == "tool.0")
        let pen = menuItem(0), turn = menuItem(1)
        _ = controller.validateMenuItem(pen)
        _ = controller.validateMenuItem(turn)
        #expect(pen.state == .on && turn.state == .off)
        document.activeTool = nil
        #expect(toolbar.selectedItemIdentifier == nil)
        _ = controller.validateMenuItem(pen)
        #expect(pen.state == .off)
    }

    @Test func runningAToolLeavesOnlyTheActiveOneSelected() async throws {
        let controller = try await documentWindow(for: ToolPlugin.self)
        defer { controller.close() }
        let toolbar = try #require(controller.window?.toolbar)
        toolbar.selectedItemIdentifier = NSToolbarItem.Identifier("tool.1")  // what clicking a selectable item does
        controller.runTool(menuItem(1))
        #expect(toolbar.selectedItemIdentifier == nil)
    }
}
