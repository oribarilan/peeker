import AppKit
import PeekerKit
@testable import PeekerMarkdown
@testable import PeekerText
import Testing

/// A plugin whose documents have no sidebar.
private enum BarePlugin: Plugin {
    static let id = "bare"
    static let name = "Bare"
    static let defaultExtensions: [String] = []
    static let tools: [ToolSpec] = []
    static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument { BareDocument() }
}

private final class BareDocument: PluginDocument {
    let contentView = NSView()
}

@Suite(.serialized) struct ToolbarLayout {
    private func identifiers(_ controller: DocumentWindowController) -> [String] {
        controller.window?.toolbar?.items.map(\.itemIdentifier.rawValue) ?? []
    }

    @Test func theSidebarButtonRidesOverTheSidebar() async throws {
        let file = try TempFile.make(Data("# One\ntext\n".utf8), name: "f.md")
        let controller = try await documentWindow(for: MarkdownPlugin.self, file: file, others: [TextPlugin.self])
        defer { controller.close() }
        // Back and Forward, which Markdown documents get, come between the separator and Open With.
        #expect(Array(identifiers(controller).prefix(6))
                == ["sidebar", NSToolbarItem.Identifier.sidebarTrackingSeparator.rawValue,
                    "back", "forward", "openWith", "showInFinder"])
    }

    @Test func withoutASidebarOpenWithComesFirst() async throws {
        let controller = try await documentWindow(for: BarePlugin.self, name: "f.txt", others: [TextPlugin.self])
        defer { controller.close() }
        #expect(identifiers(controller).prefix(2) == ["openWith", "showInFinder"])
        #expect(!identifiers(controller).contains(NSToolbarItem.Identifier.sidebarTrackingSeparator.rawValue))
    }

    @Test func showInFinderIsAFolderButtonThatRevealsTheFile() async throws {
        let controller = try await documentWindow(for: BarePlugin.self, name: "f.txt", others: [])
        defer { controller.close() }
        let item = try #require(controller.window?.toolbar?.items.first { $0.itemIdentifier == DocumentWindowController.showInFinder })
        #expect(item.label == "Show in Finder" && item.toolTip == "Show in Finder" && item.image != nil)
        var revealed: [URL] = []
        controller.revealInFinder = { revealed.append($0) }
        _ = (item.target as? NSObject)?.perform(item.action, with: item)
        #expect(revealed == [controller.url])
    }

    @Test func wrapLinesShowsLinesOfText() {
        #expect(TextPlugin.tools.first { $0.id == "toggle-wrap" }?.symbol == "text.alignleft")
    }
}
