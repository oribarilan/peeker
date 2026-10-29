import AppKit
import Testing
import UniformTypeIdentifiers

@Suite struct ConfigParsing {
    @Test func routesDisablesKeysAndQuickLook() {
        let config = Config(parsing: """
            # comment line
            disable = image
            open.MD = markdown   # trailing comment
            key.pdf.highlight = cmd+shift+h
            quicklook.key = opt+space
            plugin.idle = 15
            """)
        #expect(config.disabled == ["image"])
        #expect(config.routes == ["md": "markdown"])
        #expect(config.keys["pdf.highlight"] == Shortcut(key: .character("h"), modifiers: [.command, .shift]))
        #expect(config.quickLookKey == Shortcut(key: .space, modifiers: [.option]))
        #expect(config.pluginIdleSeconds == 15)
    }

    @Test func quickLookDefaultsToSpaceAndCanBeTurnedOff() {
        #expect(Config().quickLookKey == Shortcut(key: .space))
        #expect(Config(parsing: "quicklook.key = off").quickLookKey == nil)
    }

    @Test func malformedLinesAreSkippedNotFatal() {
        let config = Config(parsing: "open.md\nkey.pdf.save = cmd+banana\nplugin.idle = soon\nopen.md = markdown")
        #expect(config.routes == ["md": "markdown"])
        #expect(config.keys.isEmpty)
        #expect(config.pluginIdleSeconds == 60)
    }
}

@Suite struct ShortcutParsing {
    @Test func namedKeysMapToTheirKeyCodes() {
        #expect(Shortcut(parsing: "space")?.keyCode == 49)
        #expect(Shortcut(parsing: "ctrl+opt+h") == Shortcut(key: .character("h"), modifiers: [.control, .option]))
        #expect(Shortcut(parsing: "cmd+h")?.keyCode == 4)
    }

    @Test func rejectsUnknownTokensAndMissingKey() {
        #expect(Shortcut(parsing: "cmd+hyper+h") == nil)
        #expect(Shortcut(parsing: "cmd+shift") == nil)
    }
}

@Suite struct Routing {
    private func entry(_ id: String, _ types: [String]) -> PluginEntry {
        PluginEntry(manifest: PluginManifest(id: id, name: id, types: types, executable: id), helpers: URL(filePath: "/tmp"))
    }

    private func catalog(_ configText: String) -> PluginCatalog {
        PluginCatalog(entries: [entry("text", ["public.plain-text"]), entry("markdown", ["net.daringfireball.markdown"]), entry("image", ["public.image"])],
                      config: Config(parsing: configText))
    }

    private let markdownFile = URL(filePath: "/tmp/notes.md")

    @Test func exactTypeMatchBeatsSupertypeMatch() {
        #expect(catalog("").candidates(for: markdownFile).map(\.id) == ["markdown", "text"])
        #expect(catalog("").defaultPlugin(for: markdownFile)?.id == "markdown")
    }

    @Test func configRouteOverridesRanking() {
        #expect(catalog("open.md = text").defaultPlugin(for: markdownFile)?.id == "text")
    }

    @Test func routeToAPluginThatDoesNotSupportTheFileIsIgnored() {
        #expect(catalog("open.md = image").defaultPlugin(for: markdownFile)?.id == "markdown")
    }

    @Test func disabledPluginsAreNeverCandidates() {
        #expect(catalog("disable = markdown").candidates(for: markdownFile).map(\.id) == ["text"])
        #expect(catalog("disable = markdown, text").defaultPlugin(for: markdownFile) == nil)
    }

    @Test func imagesRouteThroughTypeConformance() {
        #expect(catalog("").defaultPlugin(for: URL(filePath: "/tmp/photo.heic"))?.id == "image")
    }
}

@Suite struct MarkdownTreeConversion {
    @Test func headingsListsAndTasksCarrySourceLines() {
        let blocks = MarkdownTree.blocks(from: "# Title\n\n- [ ] open\n- [x] done\n- plain\n")
        #expect(blocks.count == 2)
        #expect(blocks[0]["k"] as? String == "h")
        #expect(blocks[0]["n"] as? Int == 1)
        let items = blocks[1]["i"] as? [[String: Any]] ?? []
        #expect(items.map { $0["t"] as? Bool } == [false, true, nil])
        #expect(items.map { $0["n"] as? Int } == [3, 4, 5])
        #expect(MarkdownTree.taskCounts(in: blocks) == (done: 1, total: 2))
    }

    @Test func inlineStylesBecomeSpanBits() {
        let blocks = MarkdownTree.blocks(from: "Some **bold** and `code` with [a link](https://example.com).")
        let spans = blocks.first?["s"] as? [[Any]] ?? []
        let bold = spans.first { $0.first as? String == "bold" }
        let code = spans.first { $0.first as? String == "code" }
        let link = spans.first { $0.count > 2 }
        #expect(bold?[1] as? Int == SpanStyle.strong.rawValue)
        #expect(code?[1] as? Int == SpanStyle.code.rawValue)
        #expect(link?[2] as? String == "https://example.com")
    }

    @Test func togglingATaskEditsOnlyThatLine() throws {
        let file = FileManager.default.temporaryDirectory.appending(path: "ppp-test-\(UUID().uuidString).md")
        try "# Plan\n- [ ] first\n- [ ] second\n".write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: file) }
        try MarkdownTree.toggleTask(atLine: 3, inFile: file.path)
        #expect(try String(contentsOf: file, encoding: .utf8) == "# Plan\n- [ ] first\n- [x] second\n")
        #expect(throws: PluginFailure.self) { try MarkdownTree.toggleTask(atLine: 1, inFile: file.path) }
    }
}
