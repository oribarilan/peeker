import Foundation
import Markdown
import PeekerKit

public enum MarkdownPlugin: Plugin {
    public static let id = "markdown"
    public static let name = "Markdown"
    public static let defaultExtensions = ["md", "markdown", "mdown"]
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

    /// Flips the task checkbox on a 1-based source line and saves the file, off the main thread.
    @concurrent nonisolated static func toggleTask(atLine line: Int, in url: URL) async throws(PluginError) {
        var lines = try PluginError.catching { try String(contentsOf: url, encoding: .utf8) }.components(separatedBy: "\n")
        guard lines.indices.contains(line - 1),
              let match = lines[line - 1].prefixMatch(of: /^(\s*(?:>\s*)*(?:[-*+]|\d+[.)])\s+)\[([ xX])\]/) else {
            throw PluginError("Line \(line) has no task to tick. The file may have changed.")
        }
        lines[line - 1].replaceSubrange(match.range, with: "\(match.1)[\(match.2 == " " ? "x" : " ")]")
        try FileReplacement.replaceContents(ofFileAt: url.path, with: Data(lines.joined(separator: "\n").utf8))
    }
}
