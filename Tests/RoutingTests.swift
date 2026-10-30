import AppKit
import PeekerKit
import Testing
import UniformTypeIdentifiers

/// Stands in for every routed plugin; routing never opens anything.
private enum RoutedPlugin: Plugin {
    static let id = "routed"
    static let name = "Routed"
    static let fileTypes: [UTType] = []
    static let commands: [CommandSpec] = []

    static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument {
        throw PluginError("not used")
    }
}

@Suite struct Routing {
    private func entry(_ id: String, _ types: [String]) -> PluginEntry {
        PluginEntry(id: id, name: id, fileTypes: types.map { UTType($0) ?? UTType(importedAs: $0) }, plugin: RoutedPlugin.self)
    }

    private var entries: [PluginEntry] {
        [entry("text", ["public.plain-text"]), entry("markdown", ["net.daringfireball.markdown"]), entry("image", ["public.image"])]
    }

    /// A catalog under the config `json`.
    private func catalog(_ json: String = "{}") -> PluginCatalog {
        PluginCatalog(entries: entries, config: Config.read(Data(json.utf8), plugins: entries).config ?? Config())
    }

    private let markdownFile = URL(filePath: "/tmp/notes.md")

    @Test func exactTypeMatchBeatsSupertypeMatch() {
        #expect(catalog().candidates(for: markdownFile).map(\.id) == ["markdown", "text"])
        #expect(catalog().defaultPlugin(for: markdownFile)?.id == "markdown")
    }

    @Test func configRouteOverridesRanking() {
        #expect(catalog(#"{"open": {"md": "text"}}"#).defaultPlugin(for: markdownFile)?.id == "text")
    }

    @Test func routeToAPluginThatDoesNotSupportTheFileIsIgnored() {
        #expect(catalog(#"{"open": {"md": "image"}}"#).defaultPlugin(for: markdownFile)?.id == "markdown")
    }

    @Test func disabledPluginsAreNeverCandidates() {
        #expect(catalog(#"{"plugins": {"markdown": {"enabled": false}}}"#).candidates(for: markdownFile).map(\.id) == ["text"])
        #expect(catalog(#"{"plugins": {"markdown": {"enabled": false}, "text": {"enabled": false}}}"#).defaultPlugin(for: markdownFile) == nil)
    }

    @Test func imagesRouteThroughTypeConformance() {
        #expect(catalog().defaultPlugin(for: URL(filePath: "/tmp/photo.heic"))?.id == "image")
    }

    @Test func untypedExtensionsUseTheConfigRoute() {
        #expect(catalog(#"{"open": {"conf": "text"}}"#).defaultPlugin(for: URL(filePath: "/tmp/nginx.conf"))?.id == "text")
        #expect(catalog().defaultPlugin(for: URL(filePath: "/tmp/nginx.conf")) == nil)
    }

    @Test func extensionlessDotfilesUseTheNoneRoute() throws {
        let file = try TempFile.make(Data("export A=1\n".utf8), name: ".zshrc")   // Finder reports public.data
        #expect(catalog(#"{"open": {"noExtension": "text"}}"#).defaultPlugin(for: file)?.id == "text")
        #expect(catalog(#"{"open": {"noExtension": "text"}, "plugins": {"text": {"enabled": false}}}"#).defaultPlugin(for: file) == nil)
    }

    @Test func symlinksRouteByTheirTargetsType() throws {
        let target = try TempFile.make(Data("hello\n".utf8), name: "notes.txt")
        let link = target.deletingLastPathComponent().appending(path: "link.txt")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        #expect(catalog().defaultPlugin(for: link)?.id == "text")
    }

    @Test func symlinkedDotfilesUseTheNoneRoute() throws {
        let target = try TempFile.make(Data("export A=1\n".utf8), name: "zshrc-target")
        let link = target.deletingLastPathComponent().appending(path: ".zshrc")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        #expect(catalog(#"{"open": {"noExtension": "text"}}"#).defaultPlugin(for: link)?.id == "text")
    }

    @Test func typedFilesStillIgnoreRoutesToPluginsThatDontSupportThem() {
        #expect(catalog(#"{"open": {"md": "image"}}"#).defaultPlugin(for: markdownFile)?.id == "markdown")
    }

    @Test func reloadAppliesTheNewRoutes() {
        let catalog = catalog(#"{"open": {"conf": "text"}}"#)
        catalog.reload(config: Config())
        #expect(catalog.defaultPlugin(for: URL(filePath: "/tmp/nginx.conf")) == nil)
    }
}
