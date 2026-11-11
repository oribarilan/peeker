import AppKit
import PeekerKit
import Testing

private enum Tipped: Plugin {
    static let id = "tipped"
    static let name = "Tipped"
    static let defaultExtensions: [String] = []
    static let tools = [
        ToolSpec(
            id: "mark", title: "Mark", symbol: "highlighter", shortcut: "m", isEditTool: true,
            tip: "Select text and press {key}, or drag while Mark is on."),
        ToolSpec(id: "plain", title: "Plain", symbol: "trash", isEditTool: true),
        ToolSpec(id: "hidden", title: "Hidden", symbol: "eye", isEditTool: true, showsInToolbar: false, tip: "Not shown here."),
    ]
    static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument { TippedDocument() }
}

private final class TippedDocument: PluginDocument {
    let contentView = NSView()
    var tools: [ToolSpec] { Tipped.tools }
    var editability: Editability { .editable }
    func perform(_ id: String) -> Bool { true }
}

@Suite struct TipMemory {
    @Test func aTipShowsOnceUntilReset() {
        let tips = TipStore(defaults: nil)
        #expect(!tips.hasShownAny)
        #expect(!tips.hasShown("pdf.highlight"))
        tips.markShown("pdf.highlight")
        #expect(tips.hasShown("pdf.highlight") && !tips.hasShown("pdf.sign") && tips.hasShownAny)
        tips.reset()
        #expect(!tips.hasShown("pdf.highlight") && !tips.hasShownAny)
    }

    @Test func itsKeptInThePreferencesItIsGiven() throws {
        let (defaults, name) = scratchDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        TipStore(defaults: defaults).markShown("image.crop")
        #expect(TipStore(defaults: defaults).hasShown("image.crop"))
    }

    @Test func theKeyIsFilledInOrTheToolIsNamed() {
        let tip = "Select text and press {key}, or drag while Mark is on."
        #expect(TipStore.text(tip, title: "Mark", key: Shortcut(parsing: "m")) == "Select text and press M, or drag while Mark is on.")
        #expect(TipStore.text(tip, title: "Mark", key: nil) == "Select text and click Mark, or drag while Mark is on.")
    }
}

@Suite(.serialized) struct FirstUseTips {
    /// A window whose toolbar buttons count as on screen, and whose tips are recorded rather than drawn.
    private func window(_ tips: TipStore, onScreen: Bool = true) async throws -> (DocumentWindowController, () -> Int) {
        let controller = try await documentWindow(for: Tipped.self, tips: tips)
        try await waitUntil(seconds: 1) { controller.window?.toolbar?.items.contains { $0.itemIdentifier.rawValue == "tool.0" } == true }
        var shown = 0
        controller.isOnScreen = { _ in onScreen }
        controller.presentTip = { _, _ in shown += 1 }
        return (controller, { shown })
    }

    private func run(_ controller: DocumentWindowController, _ index: Int) {
        let item = NSMenuItem(title: "", action: #selector(DocumentWindowController.runTool(_:)), keyEquivalent: "")
        item.tag = index
        controller.runTool(item)
    }

    @Test func theFirstRunShowsTheTipFromItsButtonAndTheSecondDoesnt() async throws {
        let tips = TipStore(defaults: nil)
        let (controller, shown) = try await window(tips)
        defer { controller.close() }
        run(controller, 0)
        #expect(shown() == 1)
        #expect(controller.tipPopover?.behavior == .transient, "the next click anywhere closes it")
        #expect(controller.tipText == "Select text and press M, or drag while Mark is on.")
        let size = try #require(controller.tipPopover?.contentViewController?.preferredContentSize)
        #expect(size.width > 100 && size.height > 20, "the bubble is sized to its words: \(size)")
        #expect(tips.hasShown("tipped.mark"))
        run(controller, 0)
        #expect(shown() == 1, "no second bubble")
    }

    @Test func aToolWithoutATipShowsNothing() async throws {
        let (controller, shown) = try await window(TipStore(defaults: nil))
        defer { controller.close() }
        run(controller, 1)
        #expect(shown() == 0)
    }

    @Test func aTipWaitsWhileItsButtonIsntShowing() async throws {
        let tips = TipStore(defaults: nil)
        let (controller, shown) = try await window(tips, onScreen: false)
        defer { controller.close() }
        run(controller, 0)
        #expect(shown() == 0)
        #expect(!tips.hasShown("tipped.mark"), "kept for a run where its button shows")
    }
}
