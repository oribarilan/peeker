import AppKit
import PeekerKit
import Testing

/// A plugin whose Paint tool offers two colors, and an Erase tool without choices.
private enum Choosy: Plugin {
    static let id = "choosy"
    static let name = "Choosy"
    static let defaultExtensions: [String] = []
    static let tools = [
        ToolSpec(
            id: "paint", title: "Paint", symbol: "paintbrush", isEditTool: true,
            choices: [
                ToolSpec.Choice(id: "paint-red", title: "Red", color: RGBA(red: 1, green: 0, blue: 0, alpha: 1)),
                ToolSpec.Choice(id: "paint-blue", title: "Blue", color: RGBA(red: 0, green: 0, blue: 1, alpha: 1)),
            ],
            choicesTitle: "Paint Color"),
        ToolSpec(id: "erase", title: "Erase", symbol: "eraser", isEditTool: true),
    ]
    @MainActor static var last: ChoosyDocument?
    static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument {
        await MainActor.run {
            let document = ChoosyDocument()
            last = document
            return document
        }
    }
}

private final class ChoosyDocument: PluginDocument {
    let contentView = NSView()
    var tools: [ToolSpec] { Choosy.tools }
    var editability: Editability { .editable }
    var color = "paint-red"
    var performed: [String] = []
    var blocked: String?
    var activeTool: String?
    func perform(_ id: String) -> Bool {
        performed.append(id)
        activeTool = "paint"  // picking a color arms Paint, as Highlight's colors do
        if id.hasPrefix("paint-") { color = id }
        return true
    }
    func isOn(_ tool: String) -> Bool? { tool.hasPrefix("paint-") ? tool == color : nil }
    func unavailableReason(for tool: String) -> String? { tool == "paint" ? blocked : nil }
}

@MainActor private func toolsMenu(for controller: DocumentWindowController?) throws -> NSMenu {
    let main = MainMenu.make(target: nil)
    let view = try #require(main.item(withTitle: "View")?.submenu), tools = try #require(main.item(withTitle: "Tools")?.submenu)
    MainMenu.rebuildTools(view: view, tools: tools, for: controller)
    return tools
}

@Suite(.serialized) struct ToolChoices {
    @Test func theChoicesAreASubmenuAfterTheirTool() async throws {
        let controller = try await documentWindow(for: Choosy.self)
        defer { controller.close() }
        let tools = try toolsMenu(for: controller)
        #expect(tools.items.map(\.title) == ["Paint", "Paint Color", "Erase"])
        let submenu = try #require(tools.item(withTitle: "Paint Color")?.submenu)
        #expect(submenu.items.map { $0.representedObject as? String } == ["paint-red", "paint-blue"])
        #expect(submenu.items.map { $0.accessibilityLabel() } == ["Red", "Blue"], "VoiceOver reads the name, not the dot")
        #expect(submenu.items.allSatisfy { $0.attributedTitle?.string.hasPrefix("●") == true }, "a dot in the choice's color")
        #expect(tools.item(withTitle: "Erase")?.submenu == nil)
    }

    @Test func theCurrentChoiceIsCheckedAndPickingOneRunsIt() async throws {
        let controller = try await documentWindow(for: Choosy.self)
        defer { controller.close() }
        let document = try #require(Choosy.last)
        let submenu = try #require(try toolsMenu(for: controller).item(withTitle: "Paint Color")?.submenu)
        let red = submenu.items[0], blue = submenu.items[1]
        #expect(controller.validateMenuItem(red) && controller.validateMenuItem(blue))
        #expect(red.state == .on && blue.state == .off)
        controller.runChoice(blue)
        #expect(document.performed == ["paint-blue"])
        _ = controller.validateMenuItem(red)
        _ = controller.validateMenuItem(blue)
        #expect(red.state == .off && blue.state == .on)
    }

    @Test func choicesAreGreyedOutWithTheirTool() async throws {
        let controller = try await documentWindow(for: Choosy.self)
        defer { controller.close() }
        try #require(Choosy.last).blocked = "Not now."
        let red = try #require(try toolsMenu(for: controller).item(withTitle: "Paint Color")?.submenu?.items.first)
        #expect(!controller.validateMenuItem(red))
    }

    @Test func aRebuildWithoutTheDocumentRemovesThem() async throws {
        let controller = try await documentWindow(for: Choosy.self)
        defer { controller.close() }
        let main = MainMenu.make(target: nil)
        let view = try #require(main.item(withTitle: "View")?.submenu), tools = try #require(main.item(withTitle: "Tools")?.submenu)
        MainMenu.rebuildTools(view: view, tools: tools, for: controller)
        MainMenu.rebuildTools(view: view, tools: tools, for: nil)
        #expect(tools.items.map(\.title) == ["No Tools"])
    }

    @Test func theToolbarButtonHasTheChoicesBehindAnArrow() async throws {
        let controller = try await documentWindow(for: Choosy.self)
        defer { controller.close() }
        let index = try #require(controller.current?.tools.firstIndex { $0.spec.id == "paint" })
        try await waitUntil(seconds: 1) { controller.window?.toolbar?.items.contains { $0.itemIdentifier.rawValue == "tool.\(index)" } == true }
        let item = try #require(controller.window?.toolbar?.items.first { $0.itemIdentifier.rawValue == "tool.\(index)" } as? NSMenuToolbarItem)
        #expect(item.showsIndicator)
        #expect(item.menu.items.map { $0.representedObject as? String } == ["paint-red", "paint-blue"])
        #expect(item.action == #selector(DocumentWindowController.runTool(_:)), "the button itself runs the tool")
        controller.runChoice(try #require(item.menu.items.last))
        #expect(item.style == .prominent, "Paint shows as active")
        let erase = try #require(controller.current?.tools.firstIndex { $0.spec.id == "erase" })
        #expect(!(controller.window?.toolbar?.items.first { $0.itemIdentifier.rawValue == "tool.\(erase)" } is NSMenuToolbarItem))
    }
}
