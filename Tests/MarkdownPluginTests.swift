import AppKit
import PeekerKit
@testable import PeekerMarkdown
import Testing
import UniformTypeIdentifiers

@Suite struct MarkdownTreeConversion {
    @Test func headingsListsAndTasksCarrySourceLines() {
        let blocks = MarkdownTree.blocks(from: "# Title\n\n- [ ] open\n- [x] done\n- plain\n")
        #expect(blocks.count == 2)
        #expect(blocks[0] == .heading(level: 1, spans: [Span(text: "Title", style: [], link: nil)], line: 1))
        guard case .list(ordered: false, start: _, let items) = blocks[1] else { Issue.record("expected a bullet list"); return }
        #expect(items.map(\.checked) == [false, true, nil])
        #expect(items.map(\.line) == [3, 4, 5])
        #expect(MarkdownTree.taskCounts(in: blocks) == (done: 1, total: 2))
    }

    @Test func outlineListsHeadingsWithTheirLines() {
        let blocks = MarkdownTree.blocks(from: "# One\n\ntext\n\n## Two *b*\n")
        #expect(MarkdownTree.outline(of: blocks) == [OutlineItem(title: "One", level: 1, line: 1), OutlineItem(title: "Two b", level: 2, line: 5)])
    }

    @Test func inlineStylesBecomeSpanBits() {
        let blocks = MarkdownTree.blocks(from: "Some **bold** and `code` with [a link](https://example.com).")
        guard case .paragraph(let spans) = blocks.first else { Issue.record("expected a paragraph"); return }
        #expect(spans.contains(Span(text: "bold", style: .strong, link: nil)))
        #expect(spans.contains(Span(text: "code", style: .code, link: nil)))
        #expect(spans.contains(Span(text: "a link", style: [], link: "https://example.com")))
    }

    @Test func togglingATaskEditsOnlyThatLine() async throws {
        let file = FileManager.default.temporaryDirectory.appending(path: "peeker-test-\(UUID().uuidString).md")
        try "# Plan\n- [ ] first\n- [ ] second\n".write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: file) }
        try await MarkdownPlugin.toggleTask(atLine: 3, in: file)
        #expect(try String(contentsOf: file, encoding: .utf8) == "# Plan\n- [ ] first\n- [x] second\n")
        await #expect(throws: PluginError.self) { try await MarkdownPlugin.toggleTask(atLine: 1, in: file) }
    }

    @Test func togglingATaskKeepsSymlinksAndPermissions() async throws {
        let target = try TempFile.make(Data("- [ ] task\n".utf8), name: "target.md")
        try FileManager.default.setAttributes([.posixPermissions: 0o640], ofItemAtPath: target.path)
        let link = target.deletingLastPathComponent().appending(path: "link.md")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        try await MarkdownPlugin.toggleTask(atLine: 1, in: link)
        #expect(try String(contentsOf: target, encoding: .utf8) == "- [x] task\n")
        #expect(try FileManager.default.attributesOfItem(atPath: link.path)[.type] as? FileAttributeType == .typeSymbolicLink)
        #expect(try FileManager.default.attributesOfItem(atPath: target.path)[.posixPermissions] as? Int == 0o640)
    }
}

@Suite struct MarkdownDocumentTests {
    private func open(_ text: String) async throws -> (URL, MarkdownDocument) {
        let file = try TempFile.make(Data(text.utf8), name: "f.md")
        let document = try await openDocument(file, with: MarkdownPlugin.self, as: MarkdownDocument.self)
        return (file, document)
    }

    @Test func rendersTheTextAndListsHeadingsAndTasksInTheSidebar() async throws {
        let (_, document) = try await open("# Plan\n\n- [ ] first\n- [x] second\n")
        #expect(document.renderedText.contains("Plan"))
        #expect(document.makeSidebar().count == 2)
        #expect(document.info.contains(PeekerKit.InfoRow(label: "Tasks", value: "1 of 2 done")))
    }

    @Test func tickingATaskWritesTheFileAtOnceAndIsNoEdit() async throws {
        let (file, document) = try await open("# Plan\n- [ ] first\n")
        try await document.toggleTask(atLine: 2)
        #expect(try String(contentsOf: file, encoding: .utf8) == "# Plan\n- [x] first\n")
        #expect(document.info.contains(PeekerKit.InfoRow(label: "Tasks", value: "1 of 1 done")))
        #expect(document.unsavedEdits() == nil)
    }

    @Test func reloadPicksUpChangesInPlace() async throws {
        let (file, document) = try await open("old words\n")
        let view = document.contentView
        try Data("new words\n".utf8).write(to: file)
        #expect(try await document.reload())
        #expect(document.contentView === view)
        #expect(document.renderedText.contains("new words"))
    }

    /// A long file draws its tail a frame after its head; a tail from an older render must not land on a newer one.
    @Test func twoQuickRendersOfALongFileShowItOnce() async throws {
        let (_, document) = try await open((1...300).map { "Paragraph \($0)." }.joined(separator: "\n\n"))
        try await Task.sleep(for: .milliseconds(100))
        let once = document.renderedText
        #expect(once.contains("Paragraph 300."))
        #expect(try await document.reload())
        #expect(try await document.reload())
        try await Task.sleep(for: .milliseconds(100))
        #expect(document.renderedText == once)
    }

    @Test func textThatIsNotUTF8IsRefused() async throws {
        let file = try TempFile.make(Data([0xFF, 0xFE, 0x00, 0xD8]), name: "f.md")
        await #expect(throws: PluginError.self) {
            _ = try await MarkdownPlugin.open(file, context: OpenContext(maxPixels: 0, allowsEditing: true))
        }
    }
}

@Suite(.serialized) struct MarkdownReloadIntegrationTests {
    @Test func aChangeOnDiskReloadsTheSameView() async throws {
        let file = try TempFile.make(Data("before\n".utf8), name: "f.md")
        let document = DocumentViewController(url: file, entry: PluginEntry(MarkdownPlugin.self), config: Config(),
                                              allowsEditing: true, recovery: nil)
        defer { document.close() }
        var ready = false
        document.onReady = { _, _ in ready = true }   // the file watcher starts right after this
        document.loadViewIfNeeded()
        await document.load()
        try await waitUntil(seconds: 2) { ready }
        let markdown = try #require(document.pluginDocument as? MarkdownDocument)
        try Data("after\n".utf8).write(to: file, options: .atomic)
        try await waitUntil(seconds: 3) { markdown.renderedText.contains("after") }
        #expect(document.pluginDocument === markdown)
    }
}
