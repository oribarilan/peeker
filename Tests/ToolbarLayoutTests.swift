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
        let controller = try await documentWindow(for: MarkdownPlugin.self, file: file)
        defer { controller.close() }
        // Back and Forward, which Markdown documents get, come between the separator and Open With.
        #expect(Array(identifiers(controller).prefix(5))
                == [NSToolbarItem.Identifier.toggleSidebar.rawValue, NSToolbarItem.Identifier.sidebarTrackingSeparator.rawValue,
                    "back", "forward", "openWith"])
    }

    @Test func withoutASidebarOpenWithComesFirst() async throws {
        let controller = try await documentWindow(for: BarePlugin.self)
        defer { controller.close() }
        #expect(identifiers(controller).first == "openWith")
        #expect(!identifiers(controller).contains(NSToolbarItem.Identifier.sidebarTrackingSeparator.rawValue))
    }

    @Test func wrapLinesShowsLinesOfText() {
        #expect(TextPlugin.tools.first { $0.id == "toggle-wrap" }?.symbol == "text.alignleft")
    }
}
