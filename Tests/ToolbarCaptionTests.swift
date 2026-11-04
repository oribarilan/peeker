import AppKit
import PeekerKit
import Testing

/// A view tool on a key with modifiers, an edit tool on a single key, and an edit tool without a key.
private enum Keyed: Plugin {
    static let id = "keyed"
    static let name = "Keyed"
    static let defaultExtensions: [String] = []
    static let tools = [
        ToolSpec(id: "look", title: "Look", symbol: "eye", shortcut: "ctrl+cmd+l"),
        ToolSpec(id: "mark", title: "Mark", symbol: "highlighter", shortcut: "m", isEditTool: true),
        ToolSpec(id: "plain", title: "Plain", symbol: "trash", isEditTool: true),
    ]
    static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument { KeyedDocument() }
}

private final class KeyedDocument: PluginDocument {
    let contentView = NSView()
    var tools: [ToolSpec] { Keyed.tools }
    var editability: Editability { .editable }
    func perform(_ id: String) -> Bool { true }
}

@Suite struct ToolbarImages {
    private let symbol = NSImage(systemSymbolName: "highlighter", accessibilityDescription: nil)!

    @Test func aKeyIsDrawnBesideTheIcon() throws {
        let image = try #require(ToolbarImage.make(symbol: "highlighter", name: "Highlight", key: Shortcut(parsing: "h"), showsKey: true))
        #expect(image.size.width > symbol.size.width + 10, "icon, separator and key")
        #expect(image.isTemplate, "it follows the toolbar's colors, selected and greyed looks")
        #expect(image.accessibilityDescription == "Highlight")
    }

    @Test func withoutAKeyOrWithCaptionsOffItIsTheIconAlone() throws {
        let bare = try #require(ToolbarImage.make(symbol: "highlighter", name: "Highlight", key: nil, showsKey: true))
        let off = try #require(ToolbarImage.make(symbol: "highlighter", name: "Highlight", key: Shortcut(parsing: "h"), showsKey: false))
        #expect(bare.size == symbol.size && off.size == symbol.size)
        #expect(off.accessibilityDescription == "Highlight")
        #expect(ToolbarImage.make(symbol: nil, name: "Highlight", key: nil, showsKey: true) == nil)
    }
}

@Suite(.serialized) struct ToolbarCaptions {
    private func window(_ config: Config = Config()) async throws -> DocumentWindowController {
        let controller = try await documentWindow(for: Keyed.self, config: config)
        try await waitUntil(seconds: 1) { controller.window?.toolbar?.items.contains { $0.itemIdentifier.rawValue.hasPrefix("tool.") } == true }
        return controller
    }

    private func item(_ controller: DocumentWindowController, _ id: String) throws -> NSToolbarItem {
        let index = try #require(controller.current?.tools.firstIndex { $0.spec.id == id })
        return try #require(controller.window?.toolbar?.items.first { $0.itemIdentifier.rawValue == "tool.\(index)" })
    }

    private func width(_ controller: DocumentWindowController, _ id: String) throws -> CGFloat {
        try #require(try item(controller, id).image).size.width
    }

    @Test func aToolWithAKeyShowsItAndKeepsItsName() async throws {
        let controller = try await window()
        defer { controller.close() }
        let mark = try item(controller, "mark")
        #expect(mark.label == "Mark" && mark.paletteLabel == "Mark", "the overflow menu, Customize and VoiceOver keep the name")
        #expect(mark.toolTip == "Mark (M)")
        #expect(try width(controller, "mark") > NSImage(systemSymbolName: "highlighter", accessibilityDescription: nil)!.size.width + 10)
        #expect(try width(controller, "plain") == NSImage(systemSymbolName: "trash", accessibilityDescription: nil)!.size.width)
    }

    @Test func withCaptionsOffEveryToolIsAnIconAloneWithItsKeyInTheTooltip() async throws {
        var config = Config()
        config.showShortcuts = false
        let controller = try await window(config)
        defer { controller.close() }
        #expect(try width(controller, "mark") == NSImage(systemSymbolName: "highlighter", accessibilityDescription: nil)!.size.width)
        #expect(try item(controller, "mark").toolTip == "Mark (M)")
    }

    @Test func turningCaptionsOffRebuildsAnOpenWindow() async throws {
        let controller = try await window()
        defer { controller.close() }
        let captioned = try width(controller, "mark")
        var config = Config()
        config.showShortcuts = false
        controller.apply(config)
        try await waitUntil(seconds: 1) { ((try? width(controller, "mark")) ?? captioned) < captioned }
    }

    @Test func everyToolSitsOnItsOwnCapsule() async throws {
        let controller = try await window()
        defer { controller.close() }
        let items = try #require(controller.window?.toolbar?.items.map(\.itemIdentifier.rawValue))
        let tools = items.indices.filter { items[$0].hasPrefix("tool.") }
        #expect(tools.count == 3)
        for (a, b) in zip(tools, tools.dropFirst()) {
            #expect(b == a + 2 && items[a + 1] == NSToolbarItem.Identifier.space.rawValue, "\(items)")
        }
    }

    @Test func theSidebarBackAndForwardKeepTheirKeysInTheirTooltips() async throws {
        let controller = try await window()
        defer { controller.close() }
        // A caption would make the sidebar button too wide for the space above the sidebar.
        let sidebar = try #require(controller.navigationItem(DocumentWindowController.sidebar))
        #expect(sidebar.label == "Sidebar" && sidebar.toolTip == "Sidebar (⌃⌘S)")
        #expect(try #require(sidebar.image).size == NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: nil)!.size)
        #expect(controller.navigationItem(DocumentWindowController.back)?.toolTip == "Back (⌘[)")
    }
}
