import AppKit
import PeekerKit
import Testing

private enum BlockablePlugin: Plugin {
    static let id = "blockable"
    static let name = "Blockable"
    static let defaultExtensions: [String] = []
    static let commands = [CommandSpec(id: "turn", title: "Turn", symbol: "rotate.left", shortcut: "cmd+l")]

    static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument {
        BlockableDocument()
    }
}

private final class BlockableDocument: PluginDocument {
    let contentView = NSView()
    var reason: String?
    var commands: [CommandSpec] { BlockablePlugin.commands }
    func perform(_ id: String) -> Bool { true }
    func unavailableReason(for command: String) -> String? { command == "turn" ? reason : nil }
}

@Suite(.serialized) struct UnavailableCommands {
    @Test func documentsHaveNoReasonsByDefault() {
        final class Plain: PluginDocument { let contentView = NSView() }
        #expect(Plain().unavailableReason(for: "anything") == nil)
    }

    @Test func aCommandWithAReasonIsGreyedOutWithItAsTooltip() async throws {
        let controller = try await documentWindow(for: BlockablePlugin.self)
        defer { controller.close() }
        let document = try #require(controller.current?.pluginDocument as? BlockableDocument)
        let menuItem = NSMenuItem(title: "Turn", action: #selector(DocumentWindowController.runCommand(_:)), keyEquivalent: "l")
        menuItem.tag = 0
        let toolbarItem = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("command.0"))
        toolbarItem.tag = 0
        toolbarItem.action = #selector(DocumentWindowController.runCommand(_:))
        #expect(controller.validateMenuItem(menuItem))
        #expect(controller.validateToolbarItem(toolbarItem))
        #expect(toolbarItem.toolTip == "Turn")
        document.reason = "Not now."
        #expect(!controller.validateMenuItem(menuItem))
        #expect(!controller.validateToolbarItem(toolbarItem))
        #expect(toolbarItem.toolTip == "Not now.")
        document.reason = nil
        #expect(controller.validateMenuItem(menuItem))
        #expect(controller.validateToolbarItem(toolbarItem))
        #expect(toolbarItem.toolTip == "Turn")
    }
}
