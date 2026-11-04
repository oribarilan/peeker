import Foundation
import Markdown
import PeekerKit

public enum MarkdownPlugin: Plugin {
    public static let id = "markdown"
    public static let name = "Markdown"
    public static let symbol = "number"
    public static let defaultExtensions = ["md", "markdown", "mdown"]
    public static let tools = [
        ToolSpec(id: "zoom-in", title: "Zoom In", symbol: "plus.magnifyingglass", shortcut: "cmd+=", showsInToolbar: false),
        ToolSpec(id: "zoom-out", title: "Zoom Out", symbol: "minus.magnifyingglass", shortcut: "cmd+-", showsInToolbar: false),
        ToolSpec(id: "zoom-actual", title: "Actual Size", symbol: "1.magnifyingglass", shortcut: "cmd+0", showsInToolbar: false),
    ]

    public static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument {
        guard context.allowsEditing else { return MarkdownDocument(url: url, parsed: try await parse(url)) }
        return MarkdownEditor(url: url, source: try await load(url))
    }

    public static func recoveryText(from edits: Data) -> String? {
        (try? JSONDecoder().decode(TextEdits.self, from: edits))?.text
    }

    /// A file for the Editor: its text, and the parse that styles it and fills the sidebar.
    struct Source: Sendable {
        let file: TextFile.Loaded
        let style: MarkdownStyle
        /// Small enough to style while typing.
        let styled: Bool
        /// `style` covers only the first part of the file, so the Editor shows sooner; it parses the rest once shown.
        var partial = false
    }

    /// Reads, decodes and parses the file off the main thread.
    @concurrent nonisolated static func load(_ url: URL) async throws(PluginError) -> Source {
        let file = try await TextFile.load(url)
        let size = file.text.utf8.count
        let partial = size > MarkdownLimits.quickBytes && size <= MarkdownLimits.styledBytes
        let parsed = partial ? MarkdownStyler.prefix(of: file.text, bytes: MarkdownLimits.quickBytes) : file.text
        return Source(file: file, style: MarkdownStyler.style(parsed), styled: size <= MarkdownLimits.styledBytes, partial: partial)
    }

    nonisolated static func info(words: Int, tasks: (done: Int, total: Int)) -> [InfoRow] {
        var info = [InfoRow(label: "Words", value: words.formatted())]
        if tasks.total > 0 { info.append(InfoRow(label: "Tasks", value: "\(tasks.done) of \(tasks.total) done")) }
        return info
    }

    struct Parsed: Sendable {
        let blocks: [MarkdownBlock]
        let outline: [OutlineItem]
        let info: [InfoRow]
    }

    /// Reads and parses the file off the main thread.
    @concurrent nonisolated static func parse(_ url: URL) async throws(PluginError) -> Parsed {
        let source = try TextCodec.decode(try PluginError.catching { try Data(contentsOf: url, options: .alwaysMapped) }).text
        let blocks = MarkdownTree.blocks(from: source)
        let info = info(words: source.split { $0.isWhitespace }.count, tasks: MarkdownTree.taskCounts(in: blocks))
        return Parsed(blocks: blocks, outline: MarkdownTree.outline(of: blocks), info: info)
    }
}

nonisolated enum MarkdownLimits {
    /// Larger files open unstyled in the Editor, so typing never waits on parsing them.
    static let styledBytes = 1_048_576
    /// Larger styled files open from a parse of about this much of their start, and the rest is parsed once they show.
    static let quickBytes = 65_536
}
