import Foundation
import PeekerImage
import PeekerKit
import PeekerMarkdown
import PeekerPDF
import PeekerText
import Testing

/// The config checks command names against each plugin's static list, so a document must never offer one that
/// isn't in it.
@Suite struct PluginCommandsTests {
    private func documentCommands(_ plugin: any Plugin.Type, _ file: URL) async throws -> [String] {
        try await plugin.open(file, context: OpenContext(maxPixels: 100, allowsEditing: true)).commands.map(\.id)
    }

    @Test func documentsOfferOnlyCommandsTheirPluginDeclares() async throws {
        let png = try TempFile.make(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=")!, name: "f.png")
        let cases: [(any Plugin.Type, URL)] = [
            (ImagePlugin.self, png),
            (PDFPlugin.self, try TempFile.makePDF(pages: 1)),
            (TextPlugin.self, try TempFile.make(Data("a\n".utf8))),
            (MarkdownPlugin.self, try TempFile.make(Data("# a\n".utf8), name: "f.md")),
        ]
        for (plugin, file) in cases {
            let declared = plugin.commands.map(\.id)
            let offered = try await documentCommands(plugin, file)
            #expect(Set(offered).isSubset(of: declared), "\(plugin.id) offers \(offered), declares \(declared)")
        }
    }

    @Test func pluginsDeclareTheirCommands() {
        #expect(ImagePlugin.commands.map(\.id) == ["zoom-in", "zoom-out", "zoom-fit", "crop", "transform"])
        #expect(PDFPlugin.commands.map(\.id) == ["zoom-in", "zoom-out", "text-box", "sign", "highlight", "rotate-left", "rotate-right", "delete-page"])
        #expect(TextPlugin.commands.map(\.id) == ["zoom-in", "zoom-out", "toggle-wrap"])
        #expect(MarkdownPlugin.commands.isEmpty)
    }
}
