import AppKit
import PeekerKit
import Testing

/// Stands in for every routed plugin; routing never opens anything.
private enum RoutedPlugin: Plugin {
    static let id = "routed"
    static let name = "Routed"
    static let defaultExtensions: [String] = []
    static let commands: [CommandSpec] = []

    static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument {
        throw PluginError("not used")
    }
}

@Suite struct Routing {
    private func entry(_ id: String, _ extensions: [String]) -> PluginEntry {
        PluginEntry(id: id, name: id, defaultExtensions: extensions, plugin: RoutedPlugin.self)
    }

    /// In sidebar order.
    private var entries: [PluginEntry] {
        [entry("image", ["png", "heic"]), entry("markdown", ["md", "markdown"]), entry("text", ["txt", "conf", noExtension])]
    }

    /// A catalog under the config `json`.
    private func catalog(_ json: String = "{}") -> PluginCatalog {
        PluginCatalog(entries: entries, config: Config.read(Data(json.utf8), plugins: entries).config ?? Config())
    }

    private func owner(_ path: String, _ catalog: PluginCatalog? = nil) -> String? {
        (catalog ?? self.catalog()).owner(for: URL(filePath: path))?.id
    }

    @Test func aFileOpensInThePluginThatListsItsExtension() {
        #expect(owner("/tmp/notes.md") == "markdown")
        #expect(owner("/tmp/photo.heic") == "image")
        #expect(owner("/tmp/nginx.conf") == "text")
    }

    @Test func extensionsMatchWithoutRegardToCase() {
        #expect(owner("/tmp/README.MD") == "markdown")
    }

    @Test func filesWithNoExtensionMatchNoExtension() throws {
        #expect(owner("/tmp/Makefile") == "text")
        let dotfile = try TempFile.make(Data("export A=1\n".utf8), name: ".zshrc")
        #expect(catalog().owner(for: dotfile)?.id == "text")
    }

    @Test func anExtensionNoPluginListsOpensNowhere() {
        #expect(owner("/tmp/movie.mp4") == nil)
    }

    @Test func aFolderOpensNowhere() throws {
        let folder = try TempFile.make(Data(), name: "placeholder").deletingLastPathComponent()
        #expect(catalog().owner(for: folder) == nil)
    }

    @Test func aDisabledOwnerOpensNothingAndNoOtherPluginTakesItsFiles() {
        #expect(owner("/tmp/notes.md", catalog(#"{"plugins": {"markdown": {"enabled": false}}}"#)) == nil)
    }

    @Test func symlinksUseTheirTargetsExtension() throws {
        let target = try TempFile.make(Data("# Notes\n".utf8), name: "notes.md")
        let link = target.deletingLastPathComponent().appending(path: "link.txt")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        #expect(catalog().owner(for: link)?.id == "markdown")
    }

    @Test func aSymlinkToAFileWithNoExtensionMatchesNoExtension() throws {
        let target = try TempFile.make(Data("export A=1\n".utf8), name: "zshrc-target")
        let link = target.deletingLastPathComponent().appending(path: "rc.md")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        #expect(catalog().owner(for: link)?.id == "text")
    }

    @Test func configListsReplaceTheDefaults() {
        let moved = catalog(#"{"plugins": {"markdown": {"extensions": ["markdown"]}, "text": {"extensions": ["txt", "md"]}}}"#)
        #expect(owner("/tmp/notes.md", moved) == "text")
        #expect(owner("/tmp/notes.markdown", moved) == "markdown")
        #expect(owner("/tmp/nginx.conf", moved) == nil, "conf left Plain Text's list")
    }

    @Test func openWithListsTheOwnerFirstThenEveryOtherEnabledPlugin() {
        let markdownFile = URL(filePath: "/tmp/notes.md")
        #expect(catalog().openWithChoices(for: markdownFile).map(\.id) == ["markdown", "image", "text"])
        #expect(catalog().openWithChoices(for: URL(filePath: "/tmp/movie.mp4")).map(\.id) == ["image", "markdown", "text"])
        #expect(catalog(#"{"plugins": {"image": {"enabled": false}}}"#).openWithChoices(for: markdownFile).map(\.id) == ["markdown", "text"])
    }

    @Test func reloadAppliesTheNewLists() {
        let catalog = catalog(#"{"plugins": {"text": {"extensions": []}}}"#)
        #expect(owner("/tmp/nginx.conf", catalog) == nil)
        catalog.reload(config: Config())
        #expect(owner("/tmp/nginx.conf", catalog) == "text")
    }

    @Test func builtInPluginsAreInSidebarOrder() {
        #expect(PluginCatalog.builtIn.map { $0.id } == ["image", "pdf", "markdown", "text"])
    }
}
