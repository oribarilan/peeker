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

    @Test func noneRouteIsTheEmptyExtension() {
        #expect(Config(parsing: "open.none = text").routes == ["": "text"])
    }

    @Test func missingFileMeansDefaultsButUnreadableFileThrows() throws {
        let missing = FileManager.default.temporaryDirectory.appending(path: "no-such-\(UUID().uuidString)")
        #expect(try Config.load(from: missing).quickLookKey == Shortcut(key: .space))
        let notUTF8 = try TempFile.make(Data([0xff, 0xfe, 0xfd]), name: "config")
        #expect(throws: (any Error).self) { try Config.load(from: notUTF8) }
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
