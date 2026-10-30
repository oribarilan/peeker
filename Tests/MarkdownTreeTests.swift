import AppKit
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

    @Test func togglingATaskEditsOnlyThatLine() throws {
        let file = FileManager.default.temporaryDirectory.appending(path: "ppp-test-\(UUID().uuidString).md")
        try "# Plan\n- [ ] first\n- [ ] second\n".write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: file) }
        try MarkdownTree.toggleTask(atLine: 3, inFile: file.path)
        #expect(try String(contentsOf: file, encoding: .utf8) == "# Plan\n- [ ] first\n- [x] second\n")
        #expect(throws: PluginFailure.self) { try MarkdownTree.toggleTask(atLine: 1, inFile: file.path) }
    }

    @Test func togglingATaskKeepsSymlinksAndPermissions() throws {
        let target = try TempFile.make(Data("- [ ] task\n".utf8), name: "target.md")
        try FileManager.default.setAttributes([.posixPermissions: 0o640], ofItemAtPath: target.path)
        let link = target.deletingLastPathComponent().appending(path: "link.md")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        try MarkdownTree.toggleTask(atLine: 1, inFile: link.path)
        #expect(try String(contentsOf: target, encoding: .utf8) == "- [x] task\n")
        #expect(try FileManager.default.attributesOfItem(atPath: link.path)[.type] as? FileAttributeType == .typeSymbolicLink)
        #expect(try FileManager.default.attributesOfItem(atPath: target.path)[.posixPermissions] as? Int == 0o640)
    }
}
