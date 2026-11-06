import AppKit
import PeekerData
import PeekerImage
import PeekerKit
import PeekerMarkdown
import PeekerPDF
import PeekerTable
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
            (TablePlugin.self, try TempFile.make(Data("a,b\n1,2\n".utf8), name: "f.csv")),
            (DataPlugin.self, try TempFile.make(Data("{\"a\": 1}\n".utf8), name: "f.json")),
        ]
        for (plugin, file) in cases {
            let declared = plugin.tools.map(\.id)
            let offered = try await documentTools(plugin, file)
            #expect(Set(offered).isSubset(of: declared), "\(plugin.id) offers \(offered), declares \(declared)")
        }
    }

    @Test func pluginsDeclareTheirTools() {
        #expect(ImagePlugin.tools.map(\.id) == ["zoom-in", "zoom-out", "zoom-fit", "zoom-actual", "previous-page", "next-page", "play-animation", "crop", "transform", "markup", "markup-arrow", "markup-box", "markup-text", "markup-pixelate", "markup-step", "markup-pen", "markup-marker", "markup-spotlight"])
        #expect(PDFPlugin.tools.map(\.id) == ["zoom-in", "zoom-out", "zoom-fit", "zoom-actual", "text-box", "sign", "highlight", "rotate-left", "rotate-right", "delete-page", "insert-pages", "save-selected-pages", "split"])
        #expect(TextPlugin.tools.map(\.id) == ["zoom-in", "zoom-out", "zoom-actual", "toggle-wrap"])
        #expect(MarkdownPlugin.tools.map(\.id) == ["zoom-in", "zoom-out", "zoom-actual"])
        #expect(TablePlugin.tools.map(\.id) == ["header-row", "delimiter-comma", "delimiter-semicolon", "delimiter-tab", "delimiter-pipe",
                                                "add-row-above", "add-row-below", "add-column-before", "add-column-after", "delete-rows", "delete-columns"])
        #expect(DataPlugin.tools.map(\.id) == ["show-text", "add-item", "add-child", "delete-item"])
    }

    @Test func eachPluginNamesItsSettingsIcon() {
        #expect([ImagePlugin.symbol, PDFPlugin.symbol, MarkdownPlugin.symbol, TablePlugin.symbol, DataPlugin.symbol, TextPlugin.symbol] == ["photo", "doc.richtext", "number", "tablecells", "curlybraces", "doc.plaintext"])
        #expect(PluginEntry(PDFPlugin.self).symbol == "doc.richtext")
        for symbol in [ImagePlugin.symbol, PDFPlugin.symbol, MarkdownPlugin.symbol, TablePlugin.symbol, DataPlugin.symbol, TextPlugin.symbol] {
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
        let keys = Dictionary(uniqueKeysWithValues: PDFPlugin.tools.map { ($0.id, $0.shortcut) })
        #expect(keys["text-box"] == "t" && keys["sign"] == "s" && keys["highlight"] == "h", "single letters, as Crop's C")
        #expect(keys["delete-page"] == .some(nil), "nothing destructive on a bare key")
        let tipped = PDFPlugin.tools.filter { $0.tip != nil }.map(\.id)
        #expect(tipped == ["text-box", "sign", "highlight"], "the tools that wait for a next step")
        #expect(PDFPlugin.tools.first { $0.id == "highlight" }?.tip?.contains("{key}") == true, "the key as the user set it")
        #expect(ImagePlugin.tools.filter { $0.tip != nil }.map(\.id) == ["crop", "markup"])
    }

    /// Option-Command-W is the standard key for closing all windows.
    @Test func wrapLinesHasNoDefaultShortcut() {
        let wrap = TextPlugin.tools.first { $0.id == "toggle-wrap" }
        #expect(wrap != nil && wrap?.shortcut == nil)
    }
}
