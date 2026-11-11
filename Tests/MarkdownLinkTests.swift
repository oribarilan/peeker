import AppKit
import PeekerKit
@testable import PeekerMarkdown
import Testing

@Suite struct HeadingNaming {
    private func outline(_ titles: String...) -> [OutlineItem] {
        titles.enumerated().map { OutlineItem(title: $1, level: 2, line: $0 + 1) }
    }

    @Test func punctuationIsDroppedAndSpacesBecomeHyphens() {
        #expect(HeadingNames.name(for: "What's new?") == "whats-new")
        #expect(HeadingNames.name(for: "Install") == "install")
        #expect(HeadingNames.name(for: "snake_case and-dash") == "snake_case-and-dash")
    }

    @Test func codeAndEmphasisNameByTheirText() {
        // The Editor's outline titles keep inline code's backticks; the panel's don't. Both name the same.
        #expect(HeadingNames.name(for: "The `peek` command") == "the-peek-command")
        #expect(HeadingNames.name(for: "The peek command") == "the-peek-command")
    }

    @Test func nonASCIILettersStayAndEmojiGo() {
        #expect(HeadingNames.name(for: "Café au lait") == "café-au-lait")
        #expect(HeadingNames.name(for: "🚀 Launch!") == "-launch")
        #expect(HeadingNames.name(for: "Version 2.0") == "version-20")
    }

    @Test func twoSpacesGiveTwoHyphens() {
        #expect(HeadingNames.name(for: "a  b") == "a--b")
    }

    @Test func repeatsGetNumbersInOrder() {
        #expect(HeadingNames.names(for: outline("Notes", "Other", "Notes", "Notes")) == ["notes", "other", "notes-1", "notes-2"])
    }

    @Test func matchingIgnoresCaseAndDecodesPercentEscapes() {
        let items = outline("Notes", "Café au lait", "Notes")
        #expect(HeadingNames.index(of: "NOTES", in: items) == 0)
        #expect(HeadingNames.index(of: "notes-1", in: items) == 2)
        #expect(HeadingNames.index(of: "caf%C3%A9-au-lait", in: items) == 1)
        #expect(HeadingNames.index(of: "missing", in: items) == nil)
    }

    @Test func anHTMLAnchorMatchesNothing() async throws {
        let file = try TempFile.make(Data("<a id=\"top\"></a>\n\n# Title\n".utf8), name: "f.md")
        let editor = try await openDocument(file, with: MarkdownPlugin.self, as: MarkdownEditor.self)
        #expect(HeadingNames.index(of: "top", in: editor.outline) == nil)
    }

    @Test func theEditorAndThePanelNameTheSameHeadings() async throws {
        let source = "# What's new?\n\n## The `peek` **command**\n\n## Notes\n\n## Notes\n\n## Café au lait\n"
        let file = try TempFile.make(Data(source.utf8), name: "f.md")
        let editor = try await openDocument(file, with: MarkdownPlugin.self, as: MarkdownEditor.self)
        let panel = try await openDocument(file, with: MarkdownPlugin.self, as: MarkdownDocument.self, editing: false)
        let names = ["whats-new", "the-peek-command", "notes", "notes-1", "café-au-lait"]
        #expect(HeadingNames.names(for: editor.outline) == names)
        #expect(HeadingNames.names(for: panel.outline) == names)
    }
}

@Suite struct LinkResolving {
    private let file = URL(filePath: "/docs/project/README.md")

    private func resolve(_ destination: String) -> String? {
        LinkOpener.resolve(destination, against: file)?.absoluteString
    }

    @Test func pathsResolveAgainstTheFilesFolder() {
        #expect(resolve("other.md") == "file:///docs/project/other.md")
        #expect(resolve("./notes/a.txt") == "file:///docs/project/notes/a.txt")
        #expect(resolve("../up.md") == "file:///docs/up.md")
    }

    @Test func theFragmentIsKeptAndTheQueryDropped() throws {
        #expect(resolve("docs/guide.md#setup") == "file:///docs/project/docs/guide.md#setup")
        #expect(resolve("guide.md?plain=1#setup") == "file:///docs/project/guide.md#setup")
        #expect(resolve("guide.md?plain=1") == "file:///docs/project/guide.md")
    }

    @Test func spacesWorkEscapedOrInAngleBrackets() throws {
        #expect(try #require(LinkOpener.resolve("my%20notes.md", against: file)).path == "/docs/project/my notes.md")
        // swift-markdown hands over a `<my notes.md>` destination without the brackets.
        #expect(try #require(LinkOpener.resolve("my notes.md", against: file)).path == "/docs/project/my notes.md")
    }

    @Test func aSlashStartsAtTheDisksRoot() {
        #expect(resolve("/abs/x.md") == "file:///abs/x.md")
    }

    @Test func aHeadingAloneResolvesToTheFileItself() throws {
        let url = try #require(LinkOpener.resolve("#install", against: file))
        #expect(url.path == file.path && url.fragment == "install")
    }

    @Test func linksWithASchemeAreLeftToOpen() {
        for link in ["https://example.com/a.md", "mailto:someone@example.com", "file:///docs/other.md", "x-custom:open"] {
            #expect(resolve(link) == nil, "\(link)")
        }
    }
}

/// A Markdown file named `name` holding `text`, opened in the Editor or, with `editing` false, the Peek panel.
private func openMarkdown<Document>(
    _ text: String, name: String = "README.md", as type: Document.Type,
    editing: Bool = true
) async throws -> (URL, Document) {
    let file = try TempFile.make(Data(text.utf8), name: name)
    return (file, try await openDocument(file, with: MarkdownPlugin.self, as: type, editing: editing))
}

/// Forty lines of filler, so a window shows only part of the text.
private let filler = (1...40).map { "Line \($0) of filler text.\n" }.joined()
/// Forty paragraphs, for the rendered view, which joins plain lines into one paragraph.
private let paragraphs = (1...40).map { "Line \($0) of filler text.\n\n" }.joined()

@MainActor private extension NSScrollView {
    var top: CGFloat { contentView.bounds.origin.y }
}

@Suite struct MarkdownEditorLinks {
    @Test func cmdClickHandsALocalLinkToTheHostAndAWebLinkToOpen() async throws {
        let (file, editor) = try await openMarkdown("see [o](other.md#setup) and [w](https://example.com)\n", as: MarkdownEditor.self)
        var followed: [URL] = [], opened: [String] = []
        editor.onFollowLink = { followed.append($0) }
        editor.openLink = { opened.append($0) }
        #expect(editor.click(at: 6, command: true))
        #expect(followed.map(\.path) == [file.deletingLastPathComponent().appending(path: "other.md").path])
        #expect(followed.first?.fragment == "setup" && opened.isEmpty)
        #expect(editor.click(at: 30, command: true))
        #expect(opened == ["https://example.com"] && followed.count == 1)
    }

    @Test func aPlainClickOnALinkPlacesTheCursor() async throws {
        let (_, editor) = try await openMarkdown("see [o](other.md)\n", as: MarkdownEditor.self)
        var followed = 0
        editor.onFollowLink = { _ in followed += 1 }
        #expect(!editor.click(at: 6, command: false), "the text view places the cursor")
        #expect(followed == 0)
    }

    @Test func goingToAHeadingPutsTheCursorOnItsLine() async throws {
        let (_, editor) = try await openMarkdown("# Readme\n\(filler)## Install\nsteps\n", as: MarkdownEditor.self)
        let window = offscreenWindow(holding: editor.contentView, height: 300)
        defer { window.close() }
        let textView = try #require(editor.focusView as? NSTextView)
        #expect(await editor.go(to: "install") == "Install")
        let line = (editor.text as NSString).range(of: "## Install").location
        #expect(textView.selectedRange() == NSRange(location: line, length: 0))
        textView.setSelectedRange(NSRange(location: 2, length: 0))
        #expect(await editor.go(to: "missing") == nil)
        #expect(textView.selectedRange() == NSRange(location: 2, length: 0), "a missing heading moves nothing")
    }

    @Test func aLargeFileFindsAHeadingPastItsFirstParse() async throws {
        var text = "# Top\n"
        while text.utf8.count <= MarkdownLimits.quickBytes { text += "Some words of filler text to make the file large.\n" }
        text += "## Far down\nend\n"
        let (_, editor) = try await openMarkdown(text, as: MarkdownEditor.self)
        #expect(await editor.go(to: "far-down") == "Far down")
    }

    @Test func aPositionComesBackAfterScrollingElsewhere() async throws {
        let (_, editor) = try await openMarkdown("# Readme\n\(filler)\(filler)## End\n", as: MarkdownEditor.self)
        let window = offscreenWindow(holding: editor.contentView, height: 300)
        defer { window.close() }
        let textView = try #require(editor.focusView as? NSTextView), scrollView = try #require(editor.contentView as? NSScrollView)
        let line = (editor.text as NSString).range(of: "Line 20 ").location
        textView.setSelectedRange(NSRange(location: line, length: 4))
        textView.scrollRangeToVisible(NSRange(location: line, length: 0))
        let saved = editor.position, top = scrollView.top
        #expect(top > 0)
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.scroll(.zero)
        editor.restore(saved)
        #expect(textView.selectedRange() == NSRange(location: line, length: 4))
        #expect(abs(scrollView.top - top) < 20, "back to the same line")
    }

    @Test func aPositionPastTheEndIsClamped() async throws {
        let (_, editor) = try await openMarkdown("# Readme\n\(filler)\(filler)", as: MarkdownEditor.self)
        let window = offscreenWindow(holding: editor.contentView, height: 300)
        defer { window.close() }
        let textView = try #require(editor.focusView as? NSTextView)
        let end = (editor.text as NSString).length
        textView.setSelectedRange(NSRange(location: end - 5, length: 5))
        textView.scrollToEndOfDocument(nil)
        let saved = editor.position
        #expect(editor.restore(encoded: try JSONEncoder().encode(TextEdits(text: "short\n"))))
        editor.restore(saved)
        #expect(NSMaxRange(textView.selectedRange()) <= (editor.text as NSString).length)
    }
}

@Suite struct MarkdownPanelLinks {
    @Test func aClickHandsTheResolvedLinkToTheHost() async throws {
        let (file, document) = try await openMarkdown("see [o](notes/other.md#setup)\n", as: MarkdownDocument.self, editing: false)
        let textView = try #require(document.focusView as? NSTextView)
        var followed: [URL] = []
        document.onFollowLink = { followed.append($0) }
        #expect(document.textView(textView, clickedOnLink: try #require(URL(string: "notes/other.md#setup")), at: 4))
        #expect(followed.map(\.path) == [file.deletingLastPathComponent().appending(path: "notes/other.md").path])
        #expect(followed.first?.fragment == "setup")
    }

    @Test func goingToAHeadingScrollsToIt() async throws {
        let (_, document) = try await openMarkdown("# Readme\n\n\(paragraphs)## Install\n\nsteps\n", as: MarkdownDocument.self, editing: false)
        let window = offscreenWindow(holding: document.contentView, height: 300)
        defer { window.close() }
        let scrollView = try #require(document.contentView as? NSScrollView)
        #expect(await document.go(to: "install") == "Install")
        #expect(scrollView.top > 0)
        #expect(await document.go(to: "missing") == nil)
    }

    @Test func aPositionComesBack() async throws {
        let (_, document) = try await openMarkdown("# Readme\n\n\(paragraphs)", as: MarkdownDocument.self, editing: false)
        let window = offscreenWindow(holding: document.contentView, height: 300)
        defer { window.close() }
        let textView = try #require(document.focusView as? NSTextView), scrollView = try #require(document.contentView as? NSScrollView)
        let line = (document.renderedText as NSString).range(of: "Line 30 ").location
        textView.scrollRangeToVisible(NSRange(location: line, length: 0))
        let saved = document.position, top = scrollView.top
        #expect(top > 0)
        textView.scroll(.zero)
        document.restore(saved)
        #expect(abs(scrollView.top - top) < 40, "back to the same paragraph")
    }
}
