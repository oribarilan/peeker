import AppKit
import PeekerKit
import Testing

private enum ToolPlugin: Plugin {
    static let id = "tool"
    static let name = "Tool"
    static let defaultExtensions: [String] = []
    static let commands = [CommandSpec(id: "pen", title: "Pen", symbol: "pencil"), CommandSpec(id: "turn", title: "Turn", symbol: "rotate.left")]

    static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument { ToolDocument() }
}

private final class ToolDocument: PluginDocument {
    let contentView = NSView()
    var commands: [CommandSpec] { ToolPlugin.commands }
    var activeCommand: String? { didSet { onActiveCommandChange?() } }
    var onActiveCommandChange: (() -> Void)?
    func perform(_ id: String) -> Bool { true }
}

/// A document names the command waiting for the user; the window shows it as the toolbar's selected item and checks
/// its menu item.
@Suite(.serialized) struct ActiveCommands {
    private func menuItem(_ index: Int) -> NSMenuItem {
        let item = NSMenuItem(title: "", action: #selector(DocumentWindowController.runCommand(_:)), keyEquivalent: "")
        item.tag = index
        return item
    }

    @Test func documentsNameNoActiveCommandByDefault() {
        final class Plain: PluginDocument { let contentView = NSView() }
        #expect(Plain().activeCommand == nil)
    }

    @Test func theActiveCommandIsSelectedAndChecked() async throws {
        let controller = try await documentWindow(for: ToolPlugin.self)
        defer { controller.close() }
        let document = try #require(controller.current?.pluginDocument as? ToolDocument)
        let toolbar = try #require(controller.window?.toolbar)
        #expect(toolbar.selectedItemIdentifier == nil)
        document.activeCommand = "pen"
        #expect(toolbar.selectedItemIdentifier?.rawValue == "command.0")
        let pen = menuItem(0), turn = menuItem(1)
        _ = controller.validateMenuItem(pen)
        _ = controller.validateMenuItem(turn)
        #expect(pen.state == .on && turn.state == .off)
        document.activeCommand = nil
        #expect(toolbar.selectedItemIdentifier == nil)
        _ = controller.validateMenuItem(pen)
        #expect(pen.state == .off)
    }

    @Test func runningACommandLeavesOnlyTheActiveOneSelected() async throws {
        let controller = try await documentWindow(for: ToolPlugin.self)
        defer { controller.close() }
        let toolbar = try #require(controller.window?.toolbar)
        toolbar.selectedItemIdentifier = NSToolbarItem.Identifier("command.1")  // what clicking a selectable item does
        controller.runCommand(menuItem(1))
        #expect(toolbar.selectedItemIdentifier == nil)
    }
}
