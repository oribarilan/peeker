import AppKit
import PeekerKit
@testable import PeekerMarkdown
@testable import PeekerText
import os
import Testing

/// These change the one current theme, so they nest in `ThemeState` and put System back.
extension ThemeState { @Suite struct ThemedViews {
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

    /// The view's background as drawn: resolved in the view's own effective appearance.
    private func drawnBackground(_ view: NSTextView) -> UInt32 {
        hex(view.backgroundColor, in: view.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) ?? .aqua)
    }

    @Test func textAreasTakeTheTextAppearance() async throws {
        let app = NSApplication.shared.appearance
        defer { TextTheme.current = .system; TextTheme.appearance = nil; NSApplication.shared.appearance = app }
        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        TextTheme.current = paper
        TextTheme.appearance = NSAppearance(named: .aqua)
        let text = try await openDocument(try TempFile.make(Data("hello\n".utf8)), with: TextPlugin.self, as: TextDocument.self)
        let md = try TempFile.make(Data("# Title\n".utf8), name: "f.md")
        let editor = try await openDocument(md, with: MarkdownPlugin.self, as: MarkdownEditor.self)
        let peek = try await openDocument(md, with: MarkdownPlugin.self, as: MarkdownDocument.self, editing: false)
        let windows = [text.contentView, editor.contentView, peek.contentView].map { offscreenWindow(holding: $0) }
        defer { windows.forEach { $0.close() } }
        let views = [try textView(text), try textView(editor), try textView(peek)]
        for view in views { #expect(drawnBackground(view) == 0xF7F3EA, "Paper's light page in a dark app") }
        views[0].insertText("typed ", replacementRange: NSRange(location: 0, length: 0))
        TextTheme.appearance = NSAppearance(named: .darkAqua)
        for view in views { #expect(drawnBackground(view) == 0x23211D, "Paper's dark page") }
        NSApplication.shared.appearance = NSAppearance(named: .aqua)
        TextTheme.appearance = nil
        for view in views { #expect(drawnBackground(view) == 0xF7F3EA, "Match App: the app is light") }
        #expect(text.text == "typed hello\n", "the edit stays")
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

    // MARK: Find

    @Test func findInATextDocumentMarksMatchesInTheThemeColor() async throws {
        defer { TextTheme.current = .system }
        TextTheme.current = paper
        let file = try TempFile.make(Data("apple banana Apple cherry apple pie\n".utf8))
        let document = try await openDocument(file, with: TextPlugin.self, as: TextDocument.self)
        let view = try textView(document)
        try await checkFind(in: view, holder: document.contentView)

        TextTheme.current = paper
        let window = offscreenWindow(holding: document.contentView)
        defer { window.close() }
        try await runFindSteps {
            #expect(find(view, .showFindInterface))
            try search(view, for: "apple")
            try await waitUntil(seconds: 5) { marks(view).count == 3 }
            view.insertText("x", replacementRange: NSRange(location: 0, length: 0))
            #expect(marks(view).isEmpty, "an edit ends the search, as with the system find bar")
            try search(view, for: "banana")
            try await waitUntil(seconds: 5) { marks(view) == [7: 0xF2D27A] }
            document.revertEdits()
            try await waitUntil(seconds: 5) { marks(view).isEmpty }
        }
    }

    @Test func findMarksOnlyTheMatchesNearTheVisibleText() async throws {
        defer { TextTheme.current = .system }
        TextTheme.current = paper
        let text = (1...3000).map { "apple \($0)\n" }.joined()
        let document = try await openDocument(try TempFile.make(Data(text.utf8)), with: TextPlugin.self, as: TextDocument.self)
        let view = try textView(document)
        let window = offscreenWindow(holding: document.contentView)
        defer { window.close() }
        try await runFindSteps {
            #expect(find(view, .showFindInterface))
            try search(view, for: "apple")
            try await waitUntil(seconds: 5) { !marks(view).isEmpty }
            #expect(marks(view).count < 500, "a screen either side of the visible text, not all 3000")
            let last = (text as NSString).range(of: "apple", options: .backwards).location
            view.scrollRangeToVisible(NSRange(location: last, length: 0))
            #expect(marks(view)[last] == 0xF2D27A, "scrolling marks the matches that come into view")
        }
    }

    @Test func findInTheMarkdownEditorMarksMatchesInTheThemeColor() async throws {
        defer { TextTheme.current = .system }
        TextTheme.current = paper
        let file = try TempFile.make(Data("apple banana Apple cherry apple pie\n".utf8), name: "f.md")
        let editor = try await openDocument(file, with: MarkdownPlugin.self, as: MarkdownEditor.self)
        try await checkFind(in: try textView(editor), holder: editor.contentView)
    }

    @Test func findInThePeekPanelMarksMatchesInTheThemeColor() async throws {
        defer { TextTheme.current = .system }
        TextTheme.current = paper
        let file = try TempFile.make(Data("apple banana Apple cherry apple pie\n".utf8), name: "f.md")
        let document = try await openDocument(file, with: MarkdownPlugin.self, as: MarkdownDocument.self, editing: false)
        try await checkFind(in: try textView(document), holder: document.contentView, themeEndsSearch: true)
    }

    /// In a view holding "apple banana Apple cherry apple pie": a search for "apple" finds all three, Find Next moves
    /// on, and the matches take the theme's find color, follow a theme change and go when the find bar closes. The Peek
    /// panel renders its text again for a new theme, which ends the search, so there the next search takes the colors.
    private func checkFind(in view: NSTextView, holder: NSView, themeEndsSearch: Bool = false) async throws {
        let window = offscreenWindow(holding: holder)
        defer { window.close() }
        try await runFindSteps {
            view.setSelectedRange(NSRange(location: 0, length: 0))
            #expect(find(view, .showFindInterface))
            #expect(view.enclosingScrollView?.isFindBarVisible == true)
            try search(view, for: "apple")
            try await waitUntil(seconds: 5) { marks(view).count == 3 }
            #expect(marks(view) == [0: 0xF2D27A, 13: 0xF2D27A, 26: 0xF2D27A], "paper's find color, ignoring case")
            #expect(find(view, .nextMatch))
            TextTheme.current = tokyo
            if themeEndsSearch {
                #expect(marks(view).isEmpty)
                try search(view, for: "apple")
                try await waitUntil(seconds: 5) { marks(view).count == 3 }
                #expect(find(view, .nextMatch))
            }
            #expect(marks(view, in: .darkAqua) == [0: 0x6B5A2F, 13: 0x6B5A2F, 26: 0x6B5A2F])
            #expect(find(view, .hideFindInterface))
            #expect(marks(view).isEmpty)
            #expect(view.selectedRange() == NSRange(location: 13, length: 5), "closing the bar selects the match Find Next moved to")
        }
    }

    /// Sends a find action as the Edit menu does, if the view enables it.
    private func find(_ view: NSTextView, _ action: NSTextFinder.Action) -> Bool {
        let item = NSMenuItem(title: "", action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: "")
        item.tag = action.rawValue
        guard view.validateUserInterfaceItem(item) else { return false }
        view.performFindPanelAction(item)
        return true
    }

    /// Types `text` over whatever is in the find bar's search field, as the user would.
    private func search(_ view: NSTextView, for text: String) throws {
        func field(in view: NSView) -> NSSearchField? { (view as? NSSearchField) ?? view.subviews.lazy.compactMap(field).first }
        let searchField = try #require(view.enclosingScrollView?.findBarView.flatMap(field))
        try #require(view.window).makeFirstResponder(searchField)
        let editor = try #require(searchField.currentEditor() as? NSTextView)
        editor.selectAll(nil)
        editor.insertText(text, replacementRange: editor.selectedRange())
    }

    /// Where the view marks text with a background that isn't part of the text, by start, as hex colors.
    private func marks(_ view: NSTextView, in appearance: NSAppearance.Name = .aqua) -> [Int: UInt32] {
        var found: [Int: UInt32] = [:]
        if let layout = view.textLayoutManager, let content = layout.textContentManager {
            layout.enumerateRenderingAttributes(from: content.documentRange.location, reverse: false) { _, attributes, range in
                if let color = attributes[.backgroundColor] as? NSColor {
                    found[content.offset(from: content.documentRange.location, to: range.location)] = hex(color, in: appearance)
                }
                return true
            }
            return found
        }
        guard let layout = view.layoutManager else { return found }
        let length = view.textStorage?.length ?? 0
        var index = 0
        while index < length {
            var run = NSRange()
            let color = layout.temporaryAttribute(.backgroundColor, atCharacterIndex: index, longestEffectiveRange: &run,
                                                  in: NSRange(location: 0, length: length)) as? NSColor
            if let color { found[run.location] = hex(color, in: appearance) }
            index = NSMaxRange(run)
        }
        return found
    }

    /// Runs a find test's steps with the find pasteboard empty, so the find bar opens blank, and then puts back what was
    /// on it, since every app shares it.
    ///
    /// NSTextFinder searches on a global dispatch queue. Late in a full test run, the PDF suites' views can leave every
    /// worker thread blocked in PDFKit's form detection (Vision document analysis waiting on itself), and a search then
    /// never starts. In that case the steps are skipped and reported as a known issue rather than as a failure.
    private func runFindSteps(_ body: () async throws -> Void) async throws {
        let ran = OSAllocatedUnfairLock(initialState: false)
        DispatchQueue.global(qos: .userInitiated).async { ran.withLock { $0 = true } }
        let deadline = ContinuousClock.now + .seconds(1)
        while !ran.withLock({ $0 }), ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(20)) }
        guard ran.withLock({ $0 }) else {
            withKnownIssue("No dispatch worker thread is free for NSTextFinder's search") { Issue.record("find steps skipped") }
            return
        }
        let board = NSPasteboard(name: .find)
        let saved = (board.pasteboardItems ?? []).map { item in item.types.compactMap { type in item.data(forType: type).map { (type, $0) } } }
        defer {
            board.clearContents()
            board.writeObjects(saved.map { pairs in
                let item = NSPasteboardItem()
                for (type, data) in pairs { item.setData(data, forType: type) }
                return item
            })
        }
        board.clearContents()
        try await body()
    }
}}

/// A view that reports the find bar off whatever it's told: NSTextView then tells a finder to show nothing, the failure
/// a future macOS could bring back.
private final class FindBarOffTextView: ThemedFindTextView {
    override var usesFindBar: Bool {
        get { false }
        set {}
    }
}

@Suite @MainActor struct ThemedFindFallback {
    @Test func aFinderThatWontShowFallsBackToTheSystemFindBar() {
        let scroll = NSScrollView()
        let view = FindBarOffTextView(frame: .zero)
        scroll.documentView = view
        let item = NSMenuItem(title: "", action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: "")
        item.tag = NSTextFinder.Action.showFindInterface.rawValue
        _ = view.validateUserInterfaceItem(item)
        #expect(view.usesSystemFind)
        #expect(view.isIncrementalSearchingEnabled, "the built-in find bar is set up to take over")

        let working = ThemedFindTextView(frame: .zero)
        NSScrollView().documentView = working
        _ = working.validateUserInterfaceItem(item)
        #expect(!working.usesSystemFind)
    }
}
