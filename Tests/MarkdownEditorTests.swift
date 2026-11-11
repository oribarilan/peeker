import AppKit
import PeekerKit
@testable import PeekerMarkdown
import Testing

/// Opens `text`, written as `name`, in the Editor.
private func edit(_ text: String, name: String = "f.md") async throws -> (URL, MarkdownEditor) {
    let file = try TempFile.make(Data(text.utf8), name: name)
    return (file, try await openDocument(file, with: MarkdownPlugin.self, as: MarkdownEditor.self))
}

private func open(_ bytes: Data) async throws -> (URL, MarkdownEditor) {
    let file = try TempFile.make(bytes, name: "f.md")
    return (file, try await openDocument(file, with: MarkdownPlugin.self, as: MarkdownEditor.self))
}

@MainActor private extension MarkdownEditor {
    var textView: NSTextView { focusView as! NSTextView }

    /// Types `text` at the end, as the keyboard would.
    func type(_ text: String) {
        textView.insertText(text, replacementRange: NSRange(location: (textView.string as NSString).length, length: 0))
    }

    func save() async throws { try await save(try #require(unsavedEdits()), accepting: nil) }

    func fontSize(at location: Int) -> CGFloat { (attributes(at: location)[.font] as? NSFont)?.pointSize ?? 0 }
}

/// A file of `size` bytes or more: a heading, then a task, then lines of filler.
private func large(_ size: Int) -> Data {
    var data = Data("# Heading\n- [ ] task\n".utf8)
    let line = Data("Some words of filler text to make the file large.\n".utf8)
    data.reserveCapacity(size + line.count)
    while data.count < size { data.append(line) }
    return data
}

@Suite struct MarkdownEditorOpening {
    @Test func theEditorShowsTheExactSourceAndThePeekPanelRenders() async throws {
        let source = "# Title\n\nSome **bold** text.\n"
        let (file, editor) = try await edit(source)
        #expect(editor.text == source)
        #expect(editor.editability == .editable)
        #expect(try await openDocument(file, with: MarkdownPlugin.self, as: MarkdownDocument.self, editing: false).renderedText.contains("Title"))
    }

    @Test func aFileOpensWithTheCursorAtTheStart() async throws {
        let (_, editor) = try await edit("# One\ntext\n## Two\nmore\n")
        #expect(editor.textView.selectedRange() == NSRange(location: 0, length: 0))
        #expect(editor.currentSection == 0, "so the outline marks the first heading, not the last")
    }

    @Test func typingMarksItEdited() async throws {
        let (_, editor) = try await edit("hello\n")
        var edits = 0
        editor.onEdit = { edits += 1 }
        editor.type("x")
        #expect(edits == 1)
        #expect(editor.unsavedEdits() != nil)
    }

    @Test func savingWritesTheText() async throws {
        let (file, editor) = try await edit("# Plan\n")
        editor.type("more\n")
        try await editor.save()
        #expect(try Data(contentsOf: file) == Data("# Plan\nmore\n".utf8))
        #expect(editor.unsavedEdits() == nil)
    }

    @Test func aSaveWithUnchangedTextWritesNothing() async throws {
        let bytes = Data("a\nb\r\nc\n".utf8)
        let (file, editor) = try await open(bytes)
        try await editor.save(UnsavedEdits(TextEdits(text: editor.text)), accepting: nil)
        #expect(try Data(contentsOf: file) == bytes)
    }

    @Test func aWindows1252FileKeepsItsEncodingAndLineEndings() async throws {
        let (file, editor) = try await open(Data([0x63, 0x61, 0x66, 0xE9, 0x0D, 0x0A]))  // "café\r\n" in Windows-1252
        #expect(editor.text.hasPrefix("café"))
        editor.type("# T\r\n")
        try await editor.save()
        #expect(try Data(contentsOf: file) == Data([0x63, 0x61, 0x66, 0xE9, 0x0D, 0x0A, 0x23, 0x20, 0x54, 0x0D, 0x0A]))
    }

    @Test func textTheEncodingCantHoldOffersUTF8() async throws {
        let (file, editor) = try await open(Data([0x63, 0x61, 0x66, 0xE9]))
        editor.type("🙂")
        let edits = try #require(editor.unsavedEdits())
        await #expect { try await editor.save(edits, accepting: nil) } throws: { ($0 as? PluginError)?.offer == TextFile.saveAsUTF8 }
        try await editor.save(edits, accepting: TextFile.saveAsUTF8)
        #expect(try Data(contentsOf: file) == Data("café🙂".utf8))
    }

    @Test func recoveredTextComesBack() async throws {
        let (_, editor) = try await edit("saved\n")
        let edits = try JSONEncoder().encode(TextEdits(text: "unsaved\n"))
        #expect(editor.restore(encoded: edits))
        #expect(editor.text == "unsaved\n")
        #expect(MarkdownPlugin.recoveryText(from: edits) == "unsaved\n")
    }

    @Test func aReloadDoesntReplaceUnsavedTyping() async throws {
        let (file, editor) = try await edit("one\n")
        editor.type("two\n")
        try Data("changed\n".utf8).write(to: file)
        #expect(try await editor.reload())
        #expect(editor.text == "one\ntwo\n")
    }

    @Test func aReloadShowsTheFileOnDisk() async throws {
        let (file, editor) = try await edit("one\n")
        try Data("# changed\n".utf8).write(to: file)
        #expect(try await editor.reload())
        #expect(editor.text == "# changed\n")
        #expect(editor.outline.map(\.title) == ["changed"])
    }
}

@Suite struct MarkdownEditorStyling {
    @Test func aNewHeadingTakesTheHeadingStyle() async throws {
        let (_, editor) = try await edit("plain\n")
        let body = editor.fontSize(at: 0)
        editor.type("## Notes\n")
        await editor.restyle()
        #expect(editor.fontSize(at: 8) > body)
    }

    @Test func aParseOfOlderTextIsDropped() async throws {
        let (_, editor) = try await edit("plain\n")
        let before = editor.generation
        editor.type("## Notes\n")
        editor.apply(MarkdownStyler.style("# Stale\n"), parsedAt: before)
        #expect(editor.outline.isEmpty)
    }

    @Test func zoomScalesBodyAndHeadingsTogether() async throws {
        let (_, editor) = try await edit("# Big\nbody\n")
        let heading = editor.fontSize(at: 2), body = editor.fontSize(at: 7)
        #expect(editor.perform("zoom-in"))
        #expect(editor.fontSize(at: 7) > body)
        #expect(editor.fontSize(at: 2) > heading)
        #expect(editor.fontSize(at: 2) > editor.fontSize(at: 7))
    }

    @Test func aLargeFileStylesTheFirstScreenThenTheRest() async throws {
        let text = "# Top\n" + String(repeating: "Some plain words here.\n", count: 1500) + "## Late\n"
        let (_, editor) = try await edit(text)
        let late = (editor.text as NSString).range(of: "Late").location
        let body = editor.fontSize(at: 8)
        #expect(editor.fontSize(at: 2) > body, "the first screen is styled at once")
        #expect(editor.fontSize(at: late) == body, "the rest waits for the next turn of the run loop")
        try await waitUntil(seconds: 2) { editor.fontSize(at: late) > body }
    }

    @Test func aFileOver64KBShowsFromAQuickParseThenTheFullOne() async throws {
        let text = "# Top\n\n" + String(repeating: "Some plain words here, enough to pass the quick parse.\n\n", count: 1500) + "## Late\n"
        let (_, editor) = try await edit(text)
        #expect(editor.outline.map(\.title) == ["Top"], "the window shows from a parse of the first part")
        let late = (editor.text as NSString).range(of: "Late").location
        let body = editor.fontSize(at: 10)
        try await waitUntil(seconds: 3) { editor.outline.map(\.title) == ["Top", "Late"] }
        #expect(editor.fontSize(at: late) > body, "the full parse styles the rest")
    }

    @Test func actualSizeGoesBackToTheDefaultSize() async throws {
        let (_, editor) = try await edit("# Big\nbody\n")
        let heading = editor.fontSize(at: 2)
        #expect(editor.perform("zoom-in") && editor.perform("zoom-in"))
        #expect(editor.perform("zoom-actual"))
        #expect(editor.fontSize(at: 7) == 14)
        #expect(editor.fontSize(at: 2) == heading)
        #expect(editor.perform("zoom-actual"), "at the default size it does nothing, without failing")
        #expect(editor.fontSize(at: 7) == 14)
    }

    @Test func offersActualSizeButNotZoomToFit() {
        let zoom = MarkdownPlugin.tools.filter { $0.id.hasPrefix("zoom-") }
        #expect(zoom.map(\.id) == ["zoom-in", "zoom-out", "zoom-actual"])
        #expect(zoom.last.map { [$0.title, $0.symbol, $0.shortcut] } == ["Actual Size", "1.magnifyingglass", "cmd+0"])
        #expect(zoom.last?.showsInToolbar == false)
    }

    @Test func aFileOver1MBOpensUnstyledAndEditable() async throws {
        let (_, editor) = try await open(large(3 * 1_048_576))
        #expect(editor.editability == .editable)
        #expect(editor.fontSize(at: 2) == editor.fontSize(at: 30), "the heading has the body font")
        #expect(editor.outline.map(\.title) == ["Heading"])
        editor.type("x")
        #expect(editor.unsavedEdits() != nil)
    }

    @Test func aFileOver10MBIsReadOnly() async throws {
        let (_, editor) = try await open(large(TextLimits.editableBytes + 1))
        #expect(editor.editability == .readOnly(TextFile.readOnlyNote))
        #expect(!editor.textView.isEditable)
        #expect(!editor.click(at: 12, command: false), "a task box in a read-only file doesn't flip")
        #expect(editor.text.hasPrefix("# Heading\n- [ ] task"))
    }
}

@Suite struct MarkdownEditorClicks {
    @Test func clickingATaskBoxFlipsItAsAnUndoableEdit() async throws {
        let (file, editor) = try await edit("- [ ] buy milk\n")
        let window = offscreenWindow(holding: editor.contentView)
        defer { window.close() }
        #expect(editor.click(at: 3, command: false))
        #expect(editor.text == "- [x] buy milk\n")
        #expect(editor.unsavedEdits() != nil)
        #expect(try String(contentsOf: file, encoding: .utf8) == "- [ ] buy milk\n", "nothing is written before Cmd+S")
        editor.textView.undoManager?.undo()
        #expect(editor.text == "- [ ] buy milk\n")
    }

    @Test func cmdClickOpensALinkAndAPlainClickDoesnt() async throws {
        let (_, editor) = try await edit("see [site](https://example.com)\n")
        var opened: [String] = []
        editor.openLink = { opened.append($0) }
        #expect(!editor.click(at: 6, command: false))
        #expect(opened.isEmpty)
        #expect(editor.click(at: 6, command: true))
        #expect(opened == ["https://example.com"])
    }
}

@Suite struct MarkdownEditorSidebarAndPrint {
    @Test func theOutlineAndCountsFollowTyping() async throws {
        let (_, editor) = try await edit("# One\n")
        var changes = 0
        editor.onSidebarChange = { changes += 1 }
        editor.type("## Notes\n- [x] done\n")
        await editor.restyle()
        #expect(editor.outline.map(\.title) == ["One", "Notes"])
        #expect(editor.info.contains(InfoRow(label: "Tasks", value: "1 of 1 done")))
        #expect(changes == 1)
    }

    @Test func anOutlineClickPutsTheCursorOnTheHeading() async throws {
        let (_, editor) = try await edit("a\n\n## Two\nb\n")
        let window = offscreenWindow(holding: editor.contentView)
        defer { window.close() }
        editor.jump(toLine: 3)
        #expect(editor.textView.selectedRange() == NSRange(location: 3, length: 0))
    }

    private func outline(_ editor: MarkdownEditor) throws -> OutlineList {
        try #require(editor.makeSidebar().lazy.compactMap { $0.view as? OutlineList }.first)
    }

    private func moveCursor(_ editor: MarkdownEditor, to text: String) {
        editor.textView.setSelectedRange(NSRange(location: (editor.text as NSString).range(of: text).location, length: 0))
    }

    @Test func theOutlineMarksTheSectionTheCursorIsIn() async throws {
        let (_, editor) = try await edit("intro\n# One\nfirst\n## Two\nsecond\n")
        let window = offscreenWindow(holding: editor.contentView)
        defer { window.close() }
        let list = try outline(editor)
        moveCursor(editor, to: "intro")
        #expect(list.table.selectedRow == -1, "above the first heading nothing is marked")
        moveCursor(editor, to: "first")
        #expect(list.table.selectedRow == 0)
        moveCursor(editor, to: "second")
        #expect(list.table.selectedRow == 1)
        moveCursor(editor, to: "One")
        #expect(list.table.selectedRow == 0, "the heading's own line is its section")
        editor.jump(toLine: 4)
        #expect(list.table.selectedRow == 1, "a click on Two jumps there and marks it")
    }

    @Test func aNewHeadingIsMarkedOnceTheOutlineRefreshes() async throws {
        let (_, editor) = try await edit("# One\nfirst\n")
        let window = offscreenWindow(holding: editor.contentView)
        defer { window.close() }
        editor.type("## Fresh\nlast\n")
        await editor.restyle()
        let list = try outline(editor)  // the host rebuilds the sidebar when the outline changes
        moveCursor(editor, to: "last")
        #expect(list.table.selectedRow == 1)
    }

    @Test func printingRendersTheCurrentText() async throws {
        let (_, editor) = try await edit("# Title\n")
        editor.type("\n## Fresh\n")
        let printed = editor.printText(for: NSPrintInfo()).string
        #expect(printed.contains("Fresh") && printed.contains("Title"))
        #expect(!printed.contains("#"))
    }
}
