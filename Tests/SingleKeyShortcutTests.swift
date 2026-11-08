import AppKit
import PeekerKit
@testable import PeekerImage
import Testing

private enum LetterPlugin: Plugin {
    static let id = "letters"
    static let name = "Letters"
    static let defaultExtensions: [String] = []
    static let tools = [
        ToolSpec(id: "crop", title: "Crop", symbol: "crop", shortcut: "c", isEditTool: true),
        ToolSpec(id: "zoom", title: "Zoom", shortcut: "cmd+="),
    ]

    static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument {
        LetterDocument()
    }
}

private final class LetterDocument: PluginDocument {
    let contentView = NSView()
    let editability = Editability.editable
    var onEdit: (() -> Void)?
    private(set) var performed: [String] = []
    var tools: [ToolSpec] { LetterPlugin.tools }
    func perform(_ id: String) -> Bool { performed.append(id); return true }
}

@Suite(.serialized) struct SingleKeyShortcuts {
    private func window() async throws -> DocumentWindowController {
        try await documentWindow(for: LetterPlugin.self)
    }

    @Test func aLetterRunsItsToolRightAfterOpeningButNotWhileTyping() async throws {
        let controller = try await window()
        defer { controller.close() }
        let window = try #require(controller.window)
        let document = try #require(controller.current?.pluginDocument as? LetterDocument)
        #expect(controller.handleToolKey(key("c", code: 8, in: window)))
        #expect(document.performed == ["crop"])
        #expect(!controller.handleToolKey(key("c", code: 8, in: window, modifiers: .command)), "Cmd+C is Copy")
        #expect(!controller.handleToolKey(key("x", code: 7, in: window)), "no tool on X")
        let field = NSTextView(frame: NSRect(x: 0, y: 0, width: 50, height: 20))
        window.contentView?.addSubview(field)
        window.makeFirstResponder(field)
        #expect(!controller.handleToolKey(key("c", code: 8, in: window)), "typing")
        #expect(document.performed == ["crop"])
    }

    @Test func theMenuShowsTheLetterInsteadOfAKeyEquivalent() async throws {
        let controller = try await window()
        defer { controller.close() }
        let main = MainMenu.make(target: nil)
        let view = try #require(main.item(withTitle: "View")?.submenu), tools = try #require(main.item(withTitle: "Tools")?.submenu)
        MainMenu.rebuildTools(view: view, tools: tools, for: controller)
        let crop = try #require(tools.items.first { $0.title.hasPrefix("Crop") })
        #expect(crop.title == "Crop (C)" && crop.keyEquivalent == "")
        let zoom = try #require(view.items.first { $0.title == "Zoom" })
        #expect(zoom.keyEquivalent == "=")
    }

    @Test func theConfigTakesSingleKeysOnlyForEditTools() throws {
        let entry = PluginEntry(LetterPlugin.self)
        let json = #"{"plugins": {"letters": {"tools": {"crop": {"shortcut": "k"}, "zoom": {"shortcut": "0"}}}}}"#
        let reading = Config.read(Data(json.utf8), plugins: [entry])
        let config = try #require(reading.config)
        #expect(config.keys["letters.crop"] == Shortcut(parsing: "k"))
        #expect(config.keys["letters.zoom"] == nil)
        #expect(reading.problems.map(\.path) == ["plugins.letters.tools.zoom.shortcut"])
        let escape = #"{"plugins": {"letters": {"tools": {"crop": {"shortcut": "esc"}}}}}"#
        #expect(Config.read(Data(escape.utf8), plugins: [entry]).config?.keys["letters.crop"] == nil)
    }

    @Test func editToolRecordersTakeSingleKeys() {
        let c = Shortcut(key: .character("c"))
        #expect(Shortcut.Rules.editTool.refusal(for: c) == nil)
        #expect(Shortcut.Rules.editTool.refusal(for: Shortcut(key: .character("c"), modifiers: .command)) == nil)
        #expect(Shortcut.Rules.editTool.refusal(for: Shortcut(key: .space)) != nil, "Space scrolls")
        #expect(Shortcut.Rules.viewTool.refusal(for: c) != nil)
    }
}

/// The image plugin's C, in a real window.
@Suite(.serialized) struct ImageSingleKeys {
    @Test func cStartsCroppingRightAfterOpening() async throws {
        let png = try imageFile(try cornerImage(width: 400, height: 200), type: .png)
        let controller = try await documentWindow(for: ImagePlugin.self, file: png)
        defer { controller.close() }
        let document = try #require(controller.current?.pluginDocument as? ImageDocument)
        #expect(controller.handleToolKey(key("c", code: 8, in: try #require(controller.window))))
        #expect(document.cropOverlay != nil)
    }

    @Test func markupKeysArmTheirTools() async throws {
        let png = try imageFile(try cornerImage(width: 400, height: 200), type: .png)
        let controller = try await documentWindow(for: ImagePlugin.self, file: png)
        defer { controller.close() }
        let window = try #require(controller.window)
        let document = try #require(controller.current?.pluginDocument as? ImageDocument)
        #expect(controller.handleToolKey(key("b", code: 11, in: window)))
        #expect(document.isOn("markup-box") == true)
        #expect(controller.handleToolKey(key("s", code: 1, in: window)))
        #expect(document.isOn("markup-spotlight") == true)
    }

    @Test func pageDownAndPageUpMoveBetweenTIFFPages() async throws {
        let controller = try await documentWindow(for: ImagePlugin.self, file: try multiPageTIFF([(40, 20), (20, 40)]))
        defer { controller.close() }
        let window = try #require(controller.window)
        let document = try #require(controller.current?.pluginDocument as? ImageDocument)
        let pageDown = String(UnicodeScalar(NSPageDownFunctionKey)!), pageUp = String(UnicodeScalar(NSPageUpFunctionKey)!)
        #expect(controller.handleToolKey(key(pageDown, code: 121, in: window)))
        await document.pageChange?.value
        #expect(document.page == 1)
        #expect(controller.handleToolKey(key(pageUp, code: 116, in: window)))
        await document.pageChange?.value
        #expect(document.page == 0)
    }

    @Test func aReadOnlyImageSaysWhyAndDoesntCrop() async throws {
        let controller = try await documentWindow(for: ImagePlugin.self, file: try twoFrameGIF())
        defer { controller.close() }
        var shown: [String] = []
        controller.present = { _, title, _ in shown.append(title) }
        let document = try #require(controller.current?.pluginDocument as? ImageDocument)
        #expect(controller.handleToolKey(key("c", code: 8, in: try #require(controller.window))))
        try await waitUntil(seconds: 1) { !shown.isEmpty }
        #expect(shown == ["This image has several frames."])
        #expect(document.cropOverlay == nil)
    }
}
