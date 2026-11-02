import AppKit
import PeekerKit
@testable import PeekerMarkdown
@testable import PeekerText
import Testing

/// A Markdown file in a window whose catalog has the Markdown and Plain Text plugins.
@MainActor private func markdownWindow() async throws -> DocumentWindowController {
    let url = try TempFile.make(Data("# Hi".utf8), name: "a.md")
    let entries = [PluginEntry(MarkdownPlugin.self), PluginEntry(TextPlugin.self)]
    let catalog = PluginCatalog(entries: entries, config: Config())
    let controller = DocumentWindowController(url: url, catalog: catalog, config: Config(), recovery: nil, recoveryClipboard: nil,
                                              sidebarMemory: SidebarMemory(defaults: nil))
    controller.show(with: entries[0])
    try await waitUntil(seconds: 2) { controller.current?.pluginDocument != nil }
    return controller
}

@Suite(.serialized) struct FileMenuOpenWith {
    private func openWith() throws -> NSMenuItem {
        try #require(MainMenu.make(target: nil).item(withTitle: "File")?.submenu?.item(withTitle: "Open With"))
    }

    @Test func listsThePluginsWithTheCurrentOneChecked() async throws {
        let controller = try await markdownWindow()
        defer { controller.close() }
        let item = try openWith()
        #expect(controller.validateMenuItem(item))
        let choices = try #require(item.submenu?.items)
        #expect(choices.map(\.title) == ["Markdown", "Plain Text"])
        #expect(choices.map { controller.validateMenuItem($0) } == [true, true])
        #expect(choices.map(\.state) == [.on, .off])
    }

    @Test func choosingAPluginReopensTheTabWithIt() async throws {
        let controller = try await markdownWindow()
        defer { controller.close() }
        let item = try openWith()
        _ = controller.validateMenuItem(item)
        let text = try #require(item.submenu?.item(withTitle: "Plain Text"))
        controller.reopenWithMenu(text)
        try await waitUntil(seconds: 2) { controller.current?.entry.id == "text" && controller.current?.pluginDocument != nil }
    }

    @Test func onlyADocumentWindowAnswersIt() throws {
        let item = try openWith()
        #expect(item.action == #selector(DocumentWindowController.reopenWithMenu(_:)) && item.target == nil)
        #expect(!AppDelegate().responds(to: item.action))
    }

    @Test func theToolbarControlHasATooltip() async throws {
        let controller = try await markdownWindow()
        defer { controller.close() }
        let control = try #require(controller.window?.toolbar?.items.first { $0.itemIdentifier.rawValue == "openWith" })
        #expect(control.toolTip == "Open With")
    }
}

@Suite(.serialized) struct RevertToSaved {
    private func revertItem() throws -> NSMenuItem {
        try #require(MainMenu.make(target: nil).item(withTitle: "File")?.submenu?.item(withTitle: "Revert to Saved…"))
    }

    @Test func greyedOutWithoutUnsavedEdits() async throws {
        let controller = try await documentWindow(for: TextPlugin.self, name: "f.txt")
        defer { controller.close() }
        #expect(!controller.validateMenuItem(try revertItem()))
        try #require(controller.current).type("mine")
        #expect(controller.validateMenuItem(try revertItem()))
    }

    @Test func confirmingGoesBackToTheSavedText() async throws {
        let controller = try await documentWindow(for: TextPlugin.self, name: "f.txt")
        defer { controller.close() }
        var asked = 0
        controller.confirmRevert = { _ in asked += 1; return true }
        let document = try #require(controller.current)
        try document.type("mine")
        await controller.revert()
        #expect(asked == 1)
        #expect(document.shownText == "x" && !document.isEdited)
    }

    @Test func cancellingKeepsTheEdits() async throws {
        let controller = try await documentWindow(for: TextPlugin.self, name: "f.txt")
        defer { controller.close() }
        controller.confirmRevert = { _ in false }
        let document = try #require(controller.current)
        try document.type("mine")
        await controller.revert()
        #expect(document.pendingText == "mine" && document.isEdited)
    }
}
