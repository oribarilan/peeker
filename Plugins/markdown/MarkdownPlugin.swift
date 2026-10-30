import Foundation
import Markdown
import PeekerKit
import UniformTypeIdentifiers

public enum MarkdownPlugin: Plugin {
    public static let id = "markdown"
    public static let name = "Markdown"
    public static let fileTypes = [UTType("net.daringfireball.markdown") ?? UTType(importedAs: "net.daringfireball.markdown")]
    public static let commands: [CommandSpec] = []

    public static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument {
        MarkdownDocument(url: url, parsed: try await parse(url))
    }

    struct Parsed: Sendable {
        let blocks: [MarkdownBlock]
        let outline: [OutlineItem]
        let info: [InfoRow]
    }

    /// Reads and parses the file off the main thread.
    @concurrent nonisolated static func parse(_ url: URL) async throws(PluginError) -> Parsed {
        let source = try PluginError.catching { try String(contentsOf: url, encoding: .utf8) }
        let blocks = MarkdownTree.blocks(from: source)
        let tasks = MarkdownTree.taskCounts(in: blocks)
        var info = [InfoRow(label: "Words", value: source.split { $0.isWhitespace }.count.formatted())]
        if tasks.total > 0 { info.append(InfoRow(label: "Tasks", value: "\(tasks.done) of \(tasks.total) done")) }
        return Parsed(blocks: blocks, outline: MarkdownTree.outline(of: blocks), info: info)
    }

    @concurrent nonisolated static func toggleTask(atLine line: Int, in url: URL) async throws(PluginError) {
        try MarkdownTree.toggleTask(atLine: line, inFile: url.path)
    }
}
