import AppKit
import PeekerKit
@testable import PeekerText
import Testing

/// A document can say a command is on, such as Wrap Lines; the window checks its menu item and presses its button.
@Suite(.serialized) struct CommandStates {
    private func menuItem(_ index: Int) -> NSMenuItem {
        let item = NSMenuItem(title: "", action: #selector(DocumentWindowController.runCommand(_:)), keyEquivalent: "")
        item.tag = index
        return item
    }

    private func wrap(_ controller: DocumentWindowController) throws -> Int {
        try #require(controller.current?.commands.firstIndex { $0.spec.id == "toggle-wrap" })
    }

    private func button(_ controller: DocumentWindowController, _ index: Int) throws -> NSButton {
        let item = try #require(controller.window?.toolbar?.items.first { $0.itemIdentifier.rawValue == "command.\(index)" })
        return try #require(item.view as? NSButton)
    }

    @Test func documentsReportNoStateByDefault() {
        final class Plain: PluginDocument { let contentView = NSView() }
        #expect(Plain().isOn("anything") == nil)
    }

    @Test func textReportsWhetherLinesWrap() async throws {
        let controller = try await documentWindow(for: TextPlugin.self, name: "f.txt")
        defer { controller.close() }
        let document = try #require(controller.current?.pluginDocument as? TextDocument)
        #expect(document.isOn("toggle-wrap") == true && document.isOn("zoom-in") == nil)
        _ = document.perform("toggle-wrap")
        #expect(document.isOn("toggle-wrap") == false)
    }

    @Test func wrapLinesIsCheckedAndPressedWhileOn() async throws {
        let controller = try await documentWindow(for: TextPlugin.self, name: "f.txt")
        defer { controller.close() }
        let index = try wrap(controller)
        let item = menuItem(index)
        _ = controller.validateMenuItem(item)
        #expect(item.state == .on)
        #expect(try button(controller, index).state == .on)
        controller.runCommand(item)
        _ = controller.validateMenuItem(item)
        #expect(item.state == .off)
        #expect(try button(controller, index).state == .off)
    }

    @Test func commandsWithoutStateStayPlainToolbarItems() async throws {
        let controller = try await documentWindow(for: TextPlugin.self, name: "f.txt")
        defer { controller.close() }
        let zoom = try #require(controller.current?.commands.firstIndex { $0.spec.id == "zoom-in" })
        let item = try #require(controller.window?.toolbar?.items.first { $0.itemIdentifier.rawValue == "command.\(zoom)" })
        #expect(item.view == nil && item.image != nil)
    }
}
