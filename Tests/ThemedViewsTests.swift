import AppKit
import PeekerKit
@testable import PeekerMarkdown
@testable import PeekerText
import Testing

/// Theme tests change the one current theme, so they run one at a time and put System back.
@Suite(.serialized) @MainActor struct ThemedViews {
    private let paper = TextTheme.named("paper")!
    private let tokyo = TextTheme.named("tokyo-night")!

    private func textView(_ document: any PluginDocument) throws -> NSTextView {
        try #require(document.focusView as? NSTextView)
    }

    @Test func aTextDocumentFollowsTheTheme() async throws {
        defer { TextTheme.current = .system }
        TextTheme.current = paper
        let file = try TempFile.make(Data("hello\n".utf8))
        let document = try await openDocument(file, with: TextPlugin.self, as: TextDocument.self)
        let view = try textView(document)
        #expect(hex(view.backgroundColor, in: .aqua) == 0xF7F3EA)
        #expect(hex(try #require(view.textColor), in: .aqua) == 0x3B3A36)
        #expect(hex(view.insertionPointColor, in: .aqua) == 0x3B3A36)
        view.insertText("typed ", replacementRange: NSRange(location: 0, length: 0))
        view.setSelectedRange(NSRange(location: 2, length: 3))
        TextTheme.current = tokyo
        #expect(hex(view.backgroundColor, in: .darkAqua) == 0x1A1B26)
        #expect(hex(try #require(view.textColor), in: .darkAqua) == 0xA9B1D6)
        #expect(hex(try #require(view.selectedTextAttributes[.backgroundColor] as? NSColor), in: .darkAqua) == 0x2A2E40)
        #expect(document.text == "typed hello\n", "the text and the edit stay")
        #expect(view.selectedRange() == NSRange(location: 2, length: 3))
    }

    @Test func theMarkdownEditorFollowsTheTheme() async throws {
        defer { TextTheme.current = .system }
        let file = try TempFile.make(Data("# Title\n\nsee [docs](https://example.com) and `code`\n".utf8), name: "f.md")
        let editor = try await openDocument(file, with: MarkdownPlugin.self, as: MarkdownEditor.self)
        let view = try textView(editor)
        view.insertText("x", replacementRange: NSRange(location: (view.string as NSString).length, length: 0))
        TextTheme.current = TextTheme.named("catppuccin")!
        func color(at location: Int, _ key: NSAttributedString.Key = .foregroundColor) -> UInt32? {
            (editor.attributes(at: location)[key] as? NSColor).map { hex($0, in: .darkAqua) }
        }
        #expect(hex(view.backgroundColor, in: .darkAqua) == 0x1E1E2E)
        #expect(color(at: 0) == 0x6C7086, "the # is a marker")
        #expect(color(at: 3) == 0xCBA6F7, "the heading")
        #expect(color(at: 14) == 0x89B4FA, "the link text")
        #expect(color(at: 10) == 0xCDD6F4, "body text")
        let code = ((view.string as NSString).range(of: "code")).location
        #expect(color(at: code, .backgroundColor) == 0x181825)
        #expect(editor.unsavedEdits() != nil, "the typing stays")
    }

    @Test func thePeekPanelFollowsTheThemeAndPrintingDoesnt() async throws {
        defer { TextTheme.current = .system }
        TextTheme.current = tokyo
        let file = try TempFile.make(Data("# Title\n\n[docs](https://example.com)\n".utf8), name: "f.md")
        let document = try await openDocument(file, with: MarkdownPlugin.self, as: MarkdownDocument.self, editing: false)
        let view = try textView(document)
        #expect(hex(view.backgroundColor, in: .darkAqua) == 0x1A1B26)
        let heading = try #require(view.textStorage?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor)
        #expect(hex(heading, in: .darkAqua) == 0x7AA2F7)
        #expect(hex(try #require(view.linkTextAttributes?[.foregroundColor] as? NSColor), in: .darkAqua) == 0x7DCFFF)
        TextTheme.current = paper
        let recolored = try #require(view.textStorage?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor)
        #expect(hex(recolored, in: .aqua) == 0x2B2A27)
        #expect(document.renderedText.contains("Title"))

        let editor = try await openDocument(file, with: MarkdownPlugin.self, as: MarkdownEditor.self)
        let printed = try #require(editor.printText.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor)
        #expect(hex(printed, in: .aqua) == hex(.labelColor, in: .aqua), "printing uses the system colors")
    }
}

