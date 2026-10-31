import AppKit
import PeekerKit
import Testing

private enum LetterPlugin: Plugin {
    static let id = "letters"
    static let name = "Letters"
    static let defaultExtensions: [String] = []
    static let commands = [
        CommandSpec(id: "crop", title: "Crop", symbol: "crop", shortcut: "c", isEditTool: true),
        CommandSpec(id: "zoom", title: "Zoom", shortcut: "cmd+="),
    ]

    static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument {
        LetterDocument()
    }
}

private final class LetterDocument: PluginDocument {
    let contentView = NSView()
    let editMode = EditMode.available
    var onEdit: (() -> Void)?
    private(set) var performed: [String] = []
    var commands: [CommandSpec] { LetterPlugin.commands }
    func perform(_ id: String) -> Bool { performed.append(id); return true }
}

@Suite(.serialized) struct SingleKeyShortcuts {
    private func window() async throws -> DocumentWindowController {
        let url = try TempFile.make(Data("x".utf8), name: "f.bin")
        let entry = PluginEntry(LetterPlugin.self)
        let controller = DocumentWindowController(url: url, catalog: PluginCatalog(entries: [entry], config: Config()), config: Config(),
                                                  allowsEditing: true, recovery: nil, recoveryClipboard: nil)
        controller.show(with: entry)
        try await waitUntil(seconds: 2) { controller.current?.pluginDocument != nil }
        return controller
    }

    private func key(_ character: String, code: UInt16, in window: NSWindow, modifiers: NSEvent.ModifierFlags = []) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0, windowNumber: window.windowNumber,
                         context: nil, characters: character, charactersIgnoringModifiers: character, isARepeat: false, keyCode: code)!
    }

    @Test func aLetterRunsItsToolOnlyInEditModeAndNotWhileTyping() async throws {
        let controller = try await window()
        defer { controller.close() }
        let window = try #require(controller.window)
        let document = try #require(controller.current?.pluginDocument as? LetterDocument)
        #expect(!controller.handleSingleKey(key("c", code: 8, in: window)), "read view")
        await controller.current?.toggleEditing { true }
        #expect(controller.handleSingleKey(key("c", code: 8, in: window)))
        #expect(document.performed == ["crop"])
        #expect(!controller.handleSingleKey(key("c", code: 8, in: window, modifiers: .command)), "Cmd+C is Copy")
        #expect(!controller.handleSingleKey(key("x", code: 7, in: window)), "no tool on X")
        let field = NSTextView(frame: NSRect(x: 0, y: 0, width: 50, height: 20))
        window.contentView?.addSubview(field)
        window.makeFirstResponder(field)
        #expect(!controller.handleSingleKey(key("c", code: 8, in: window)), "typing")
        #expect(document.performed == ["crop"])
    }

    @Test func theMenuShowsTheLetterInsteadOfAKeyEquivalent() async throws {
        let controller = try await window()
        defer { controller.close() }
        let menu = NSMenu(title: "Commands")
        MainMenu.rebuildCommands(menu, for: controller)
        let crop = try #require(menu.items.first { $0.title.hasPrefix("Crop") })
        #expect(crop.title == "Crop (C)" && crop.keyEquivalent == "")
        let zoom = try #require(menu.items.first { $0.title == "Zoom" })
        #expect(zoom.keyEquivalent == "=")
    }

    @Test func theConfigTakesSingleKeysOnlyForEditTools() throws {
        let entry = PluginEntry(LetterPlugin.self)
        let json = #"{"plugins": {"letters": {"commands": {"crop": {"shortcut": "k"}, "zoom": {"shortcut": "0"}}}}}"#
        let reading = Config.read(Data(json.utf8), plugins: [entry])
        let config = try #require(reading.config)
        #expect(config.keys["letters.crop"] == Shortcut(parsing: "k"))
        #expect(config.keys["letters.zoom"] == nil)
        #expect(reading.problems.map(\.path) == ["plugins.letters.commands.zoom.shortcut"])
        let escape = #"{"plugins": {"letters": {"commands": {"crop": {"shortcut": "esc"}}}}}"#
        #expect(Config.read(Data(escape.utf8), plugins: [entry]).config?.keys["letters.crop"] == nil)
    }

    @Test func editToolRecordersTakeSingleKeys() {
        let c = Shortcut(key: .character("c"))
        #expect(Shortcut.Rules.editTool.refusal(for: c) == nil)
        #expect(Shortcut.Rules.editTool.refusal(for: Shortcut(key: .character("c"), modifiers: .command)) == nil)
        #expect(Shortcut.Rules.editTool.refusal(for: Shortcut(key: .space)) != nil, "Space scrolls")
        #expect(Shortcut.Rules.command.refusal(for: c) != nil)
    }
}
