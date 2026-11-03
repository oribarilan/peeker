import AppKit
import PeekerImage
import PeekerKit
import PeekerMarkdown
import PeekerPDF
import PeekerText
import Testing

/// The config checks tool names against each plugin's static list, so a document must never offer one that
/// isn't in it.
@Suite struct PluginToolsTests {
    private func documentTools(_ plugin: any Plugin.Type, _ file: URL) async throws -> [String] {
        try await plugin.open(file, context: OpenContext(maxPixels: 100, allowsEditing: true)).tools.map(\.id)
    }

    @Test func documentsOfferOnlyToolsTheirPluginDeclares() async throws {
        let png = try TempFile.make(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=")!, name: "f.png")
        let cases: [(any Plugin.Type, URL)] = [
            (ImagePlugin.self, png),
            (PDFPlugin.self, try TempFile.makePDF(pages: 1)),
            (TextPlugin.self, try TempFile.make(Data("a\n".utf8))),
            (MarkdownPlugin.self, try TempFile.make(Data("# a\n".utf8), name: "f.md")),
        ]
        for (plugin, file) in cases {
            let declared = plugin.tools.map(\.id)
            let offered = try await documentTools(plugin, file)
            #expect(Set(offered).isSubset(of: declared), "\(plugin.id) offers \(offered), declares \(declared)")
        }
    }

    @Test func pluginsDeclareTheirTools() {
        #expect(ImagePlugin.tools.map(\.id) == ["zoom-in", "zoom-out", "zoom-fit", "zoom-actual", "crop", "transform"])
        #expect(PDFPlugin.tools.map(\.id) == ["zoom-in", "zoom-out", "text-box", "sign", "highlight", "rotate-left", "rotate-right", "delete-page"])
        #expect(TextPlugin.tools.map(\.id) == ["zoom-in", "zoom-out", "toggle-wrap"])
        #expect(MarkdownPlugin.tools.map(\.id) == ["zoom-in", "zoom-out"])
    }

    @Test func eachPluginNamesItsSettingsIcon() {
        #expect([ImagePlugin.symbol, PDFPlugin.symbol, MarkdownPlugin.symbol, TextPlugin.symbol] == ["photo", "doc.richtext", "number", "doc.plaintext"])
        #expect(PluginEntry(PDFPlugin.self).symbol == "doc.richtext")
        for symbol in [ImagePlugin.symbol, PDFPlugin.symbol, MarkdownPlugin.symbol, TextPlugin.symbol] {
            #expect(NSImage(systemSymbolName: symbol, accessibilityDescription: nil) != nil, "\(symbol) is an SF Symbol")
        }
    }

    @Test func aPluginNamingNoIconGetsTheDefault() {
        enum Plain: Plugin {
            static let id = "plain"
            static let name = "Plain"
            static let defaultExtensions: [String] = []
            static let tools: [ToolSpec] = []
            static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument { throw PluginError("not used") }
        }
        #expect(Plain.symbol == "puzzlepiece.extension" && PluginEntry(Plain.self).symbol == "puzzlepiece.extension")
    }

    @Test func signLeavesControlCommandSToTheSidebar() {
        #expect(PDFPlugin.tools.first { $0.id == "sign" }?.shortcut == nil)
    }
}
