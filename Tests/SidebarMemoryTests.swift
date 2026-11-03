import AppKit
import PeekerKit
@testable import PeekerText
import Testing

/// A plugin whose documents have no sidebar panels.
private enum Bare: Plugin {
    static let id = "bare"
    static let name = "Bare"
    static let defaultExtensions: [String] = []
    static let tools: [ToolSpec] = []
    static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument { BareDocument() }
}

private final class BareDocument: PluginDocument {
    let contentView = NSView()
}

/// A plugin whose documents have sidebar panels and no tools, like Markdown.
private enum Outline: Plugin {
    static let id = "outline"
    static let name = "Outline"
    static let defaultExtensions: [String] = []
    static let tools: [ToolSpec] = []
    static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument { OutlineDocument() }
}

private final class OutlineDocument: PluginDocument {
    let contentView = NSView()
    func makeSidebar() -> [SidebarPanel] { [SidebarPanel(NSView(), sizing: .fill)] }
}

@Suite(.serialized) struct SidebarMemoryTests {
    @Test func openingADocumentWithoutToolsDoesNotRebuildTheToolbar() async throws {
        let url = try TempFile.make(Data("x".utf8), name: "f.bin")
        let document = DocumentViewController(url: url, entry: PluginEntry(Outline.self), config: Config(), allowsEditing: true,
                                              recovery: nil, sidebarMemory: SidebarMemory(defaults: nil))
        let window = offscreenWindow(holding: document.view)
        defer { window.close(); document.close() }
        #expect(document.hasSidebar, "assumed while the file opens, so the first toolbar has the button")
        var rebuilds = 0
        document.onToolsChanged = { _ in rebuilds += 1 }
        await document.load()
        try await Task.sleep(for: .milliseconds(100))  // past the frame the sidebar arrives in
        #expect(rebuilds == 0)
        #expect(document.hasSidebar)
    }

    private func sidebar(_ controller: DocumentWindowController) -> NSSplitViewItem? {
        controller.current?.splitViewItems.first { $0.behavior == .sidebar }
    }

    private func width(_ controller: DocumentWindowController) -> CGFloat {
        sidebar(controller)?.viewController.view.frame.width ?? 0
    }

    /// A text window, once its sidebar is in.
    private func textWindow(_ memory: SidebarMemory) async throws -> DocumentWindowController {
        let controller = try await documentWindow(for: TextPlugin.self, name: "f.txt", sidebar: memory)
        try await waitUntil(seconds: 2) { sidebar(controller) != nil }
        controller.window?.layoutIfNeeded()
        return controller
    }

    @Test func aNewWindowOpensWithTheRememberedState() async throws {
        let hidden = SidebarMemory(defaults: nil)
        hidden.remember(hidden: true, width: 250)
        let first = try await textWindow(hidden)
        defer { first.close() }
        #expect(sidebar(first)?.isCollapsed == true)

        let wide = SidebarMemory(defaults: nil)
        wide.remember(hidden: false, width: 250)
        let second = try await textWindow(wide)
        defer { second.close() }
        #expect(sidebar(second)?.isCollapsed == false)
        #expect(abs(width(second) - 250) < 1)
    }

    @Test func hidingInOneWindowHidesItInTheOthers() async throws {
        let memory = SidebarMemory(defaults: nil)
        let first = try await textWindow(memory)
        let second = try await textWindow(memory)
        defer { first.close(); second.close() }
        try #require(sidebar(first)).isCollapsed = true
        first.window?.layoutIfNeeded()
        try await waitUntil(seconds: 2) { memory.isHidden && sidebar(second)?.isCollapsed == true }
    }

    @Test func aSaveAndAReloadKeepTheSidebarAsItWas() async throws {
        let memory = SidebarMemory(defaults: nil)
        let controller = try await textWindow(memory)
        defer { controller.close() }
        let item = try #require(sidebar(controller))
        item.isCollapsed = true
        let document = try #require(controller.current)
        try document.type("mine")
        #expect(await document.save(prompts: StubPrompts()) == .saved)
        #expect(sidebar(controller) === item && item.isCollapsed)
        try Data("theirs".utf8).write(to: controller.url)
        document.reloadIfChangedOnDisk()
        try await waitUntil(seconds: 2) { document.shownText == "theirs" }
        try await Task.sleep(for: .milliseconds(50))
        #expect(sidebar(controller) === item && item.isCollapsed)
    }

    @Test func theToolbarStartsWithTheSidebarButtonWhenThereIsASidebar() async throws {
        let text = try await textWindow(SidebarMemory(defaults: nil))
        let bare = try await documentWindow(for: Bare.self)
        defer { text.close(); bare.close() }
        let textItems = try #require(text.window?.toolbar?.items.map(\.itemIdentifier))
        #expect(textItems.first == .toggleSidebar)
        // It's known to have no sidebar a frame after its content shows.
        try await waitUntil(seconds: 1) { bare.window?.toolbar?.items.contains { $0.itemIdentifier == .toggleSidebar } == false }
    }

    @Test func aDocumentWithoutPanelsHasNoSidebarToShow() async throws {
        let controller = try await documentWindow(for: Bare.self, sidebar: SidebarMemory(defaults: nil))
        defer { controller.close() }
        try await Task.sleep(for: .milliseconds(50))  // past the frame the sidebar would arrive in
        #expect(sidebar(controller) == nil)
        let item = NSMenuItem(title: "Show Sidebar", action: #selector(NSSplitViewController.toggleSidebar(_:)), keyEquivalent: "")
        #expect(!controller.validateMenuItem(item))
    }
}
