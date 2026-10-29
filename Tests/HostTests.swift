import AppKit
import PreviewPPKit
import Testing
import UniformTypeIdentifiers

@Suite struct ConfigParsing {
    @Test func routesDisablesAndKeysAreRead() {
        let config = Config(parsing: """
            # comment line
            disable = csv, csv-web
            open.CSV = csv-proc   # trailing comment
            key.markdown.toggle-source = cmd+shift+e
            """)
        #expect(config.disabled == ["csv", "csv-web"])
        #expect(config.routes == ["csv": "csv-proc"])
        #expect(config.keys["markdown.toggle-source"] == Shortcut("e", [.command, .shift]))
    }

    @Test func malformedLinesAreSkippedNotFatal() {
        let config = Config(parsing: "open.md\nkey.text.save = cmd+banana\nopen.md = markdown")
        #expect(config.routes == ["md": "markdown"])
        #expect(config.keys.isEmpty)
    }
}

@Suite struct ShortcutParsing {
    @Test func modifiersAndKey() {
        #expect(Shortcut(parsing: "ctrl+opt+h") == Shortcut("h", [.control, .option]))
    }

    @Test func rejectsUnknownTokensAndMissingKey() {
        #expect(Shortcut(parsing: "cmd+hyper+h") == nil)
        #expect(Shortcut(parsing: "cmd+shift") == nil)
    }
}

@Suite struct CSVParsing {
    @Test func quotedFieldsKeepCommasQuotesAndNewlines() {
        let rows = CSV.parse("name,note\r\n\"Doe, Jane\",\"said \"\"hi\"\"\"\nRoe,\"two\nlines\"")
        #expect(rows == [["name", "note"], ["Doe, Jane", "said \"hi\""], ["Roe", "two\nlines"]])
    }
}

@Suite struct MarkdownTasks {
    let source = """
        - [ ] first
        ```
        - [ ] inside a code fence
        ```
        - [x] second
        """

    @Test func togglesTheNthTaskOutsideCodeFences() {
        let toggled = MarkdownRenderer.toggleTask(at: 1, in: source)
        #expect(toggled.components(separatedBy: "\n") == ["- [ ] first", "```", "- [ ] inside a code fence", "```", "- [ ] second"])
    }

    @Test func renderedCheckboxesLinkToTheirTaskIndex() {
        let rendered = MarkdownRenderer.render("- [ ] first\n- [x] second")
        #expect(rendered.string.contains("☐ first"))
        #expect(rendered.string.contains("☑ second"))
        let link = rendered.attribute(.link, at: (rendered.string as NSString).range(of: "☑").location, effectiveRange: nil) as? URL
        #expect(link?.absoluteString == "ppp-task://1")
    }
}

@Suite struct Routing {
    final class AnyText: Plugin {
        static let manifest = PluginManifest(id: "any-text", name: "Any Text", fileTypes: [.plainText])
        func open(_ url: URL, host: any PluginHost) throws -> Viewer { Viewer(content: NSViewController()) }
    }

    final class CSVOnly: Plugin {
        static let manifest = PluginManifest(id: "csv-only", name: "CSV", fileTypes: [.commaSeparatedText])
        func open(_ url: URL, host: any PluginHost) throws -> Viewer { Viewer(content: NSViewController()) }
    }

    private func registry(_ configText: String) -> PluginRegistry {
        let registry = PluginRegistry(config: Config(parsing: configText))
        registry.register(AnyText.self, runtime: .builtin)
        registry.register(CSVOnly.self, runtime: .builtin)
        return registry
    }

    private let csv = URL(filePath: "/tmp/report.csv")

    @Test func exactTypeMatchBeatsSupertypeMatch() {
        #expect(registry("").candidates(for: csv).map(\.id) == ["csv-only", "any-text"])
        #expect(registry("").defaultPlugin(for: csv)?.id == "csv-only")
    }

    @Test func configRouteOverridesRanking() {
        #expect(registry("open.csv = any-text").defaultPlugin(for: csv)?.id == "any-text")
    }

    @Test func disabledPluginsAreNeverCandidates() {
        #expect(registry("disable = csv-only").candidates(for: csv).map(\.id) == ["any-text"])
    }

    @Test func sameIDInSecondRuntimeIsKeptUnderSuffix() {
        let registry = registry("")
        registry.register(CSVOnly.self, runtime: .bundle)
        #expect(registry.entries.map(\.id) == ["any-text", "csv-only", "csv-only@bundle"])
    }
}
