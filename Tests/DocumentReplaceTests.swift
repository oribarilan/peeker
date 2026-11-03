import AppKit
import PeekerKit
import Testing

private enum SwappingPlugin: Plugin {
    static let id = "swapping"
    static let name = "Swapping"
    static let defaultExtensions: [String] = []
    static let tools = [ToolSpec(id: "after", title: "After")]

    static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument {
        Before()
    }
}

private final class Before: PluginDocument {
    let contentView = NSView()
    var onReplace: ((any PluginDocument) -> Void)?
    func unlock() { onReplace?(After()) }
}

private final class After: PluginDocument {
    let contentView = NSView()
    var tools: [ToolSpec] { SwappingPlugin.tools }
    func makeSidebar() -> [SidebarPanel] { [SidebarPanel(NSView(), sizing: .fill)] }
}

@Suite(.serialized) struct DocumentReplacing {
    @Test func documentsReplaceNothingByDefault() {
        final class Plain: PluginDocument { let contentView = NSView() }
        let plain = Plain()
        plain.onReplace = { _ in }
        #expect(plain.onReplace == nil)
    }

    @Test func aReplacementShowsWithItsTools() async throws {
        let url = try TempFile.make(Data("x".utf8), name: "f.bin")
        let document = await loadedDocument(url, with: SwappingPlugin.self)
        defer { document.close() }
        let before = try #require(document.pluginDocument as? Before)
        #expect(document.tools.isEmpty)
        before.unlock()
        #expect(document.pluginDocument is After)
        #expect(document.tools.map(\.spec.id) == ["after"])
    }
}
