import AppKit
import PeekerKit
@testable import PeekerText
import Testing

/// A plugin whose one command reports no state.
private enum PlainCommandPlugin: Plugin {
    static let id = "plaincommand"
    static let name = "Plain Command"
    static let defaultExtensions: [String] = []
    static let commands = [CommandSpec(id: "go", title: "Go", symbol: "arrow.right")]
    static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument { PlainCommandDocument() }
}

private final class PlainCommandDocument: PluginDocument {
    let contentView = NSView()
    var commands: [CommandSpec] { PlainCommandPlugin.commands }
    func perform(_ id: String) -> Bool { true }
}

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
        let image = try await documentWindow(for: PlainCommandPlugin.self)
        defer { image.close() }
        try await waitUntil(seconds: 1) { image.window?.toolbar?.items.contains { $0.itemIdentifier.rawValue == "command.0" } == true }
        let item = try #require(image.window?.toolbar?.items.first { $0.itemIdentifier.rawValue == "command.0" })
        #expect(item.view == nil && item.image != nil)
    }
}
