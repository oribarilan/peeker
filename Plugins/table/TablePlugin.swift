import Foundation
import PeekerKit
import UniformTypeIdentifiers

/// CSV and TSV files as a table, editable in the Editor.
public enum TablePlugin: Plugin {
    public static let id = "table"
    public static let name = "Table"
    public static let symbol = "tablecells"
    public static let defaultExtensions = ["csv", "tsv"]
    public static let readableTypes = [UTType.commaSeparatedText, .tabSeparatedText]
    public static let tools = [
        ToolSpec(id: "zoom-in", title: "Zoom In", symbol: "plus.magnifyingglass", shortcut: "cmd+=", showsInToolbar: false),
        ToolSpec(id: "zoom-out", title: "Zoom Out", symbol: "minus.magnifyingglass", shortcut: "cmd+-", showsInToolbar: false),
        ToolSpec(id: "zoom-actual", title: "Actual Size", symbol: "1.magnifyingglass", shortcut: "cmd+0", showsInToolbar: false),
        ToolSpec(id: "header-row", title: "Header Row", showsInToolbar: false),
        ToolSpec(id: "delimiter-comma", title: "Commas", showsInToolbar: false),
        ToolSpec(id: "delimiter-semicolon", title: "Semicolons", showsInToolbar: false),
        ToolSpec(id: "delimiter-tab", title: "Tabs", showsInToolbar: false),
        ToolSpec(id: "delimiter-pipe", title: "Pipes", showsInToolbar: false),
        ToolSpec(id: "add-row-above", title: "Add Row Above", isEditTool: true, showsInToolbar: false),
        ToolSpec(id: "add-row-below", title: "Add Row Below", symbol: "plus.rectangle", isEditTool: true),
        ToolSpec(id: "add-column-before", title: "Add Column Before", isEditTool: true, showsInToolbar: false),
        ToolSpec(id: "add-column-after", title: "Add Column After", symbol: "plus.rectangle.portrait", isEditTool: true),
        ToolSpec(id: "delete-rows", title: "Delete Rows", isEditTool: true, showsInToolbar: false),
        ToolSpec(id: "delete-columns", title: "Delete Columns", isEditTool: true, showsInToolbar: false),
        ToolSpec(id: "sort-ascending", title: "Sort Ascending", showsInToolbar: false, menu: .tools),
        ToolSpec(id: "sort-descending", title: "Sort Descending", showsInToolbar: false, menu: .tools),
        ToolSpec(id: "sort-none", title: "Original Order", showsInToolbar: false, menu: .tools),
    ]

    /// Files over this open as a read-only table.
    static let editableBytes = 50 * 1_048_576
    static let readOnlyReason = "Files over 50 MB open as a read-only table."

    public static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument {
        let remembered = FileChoices(context.preferences).choice(for: url)
        let isTSV = url.pathExtension.lowercased() == "tsv"
        let loaded = try await load(url, delimiter: isTSV ? .tab : remembered?.delimiter, header: remembered?.header)
        if Task.isCancelled { throw PluginError.cancelled }
        return TableDocument(url: url, loaded: loaded, allowsEditing: context.allowsEditing, preferences: context.preferences)
    }

    public static func recoveryText(from edits: Data) -> String? {
        (try? JSONDecoder().decode(TextEdits.self, from: edits))?.text
    }

    /// A file read, decoded, split into records and with its header row guessed, all off the main thread.
    struct Loaded: Sendable {
        let table: CSVTable
        let header: Bool
        /// Each column's sample for its width and alignment, taken here so the main thread needn't.
        let columns: [ColumnSample]
        let format: TextFormat
        let byteCount: Int
    }

    /// Reads `url` as a table, at `delimiter` or the one guessed, with the header row given or guessed.
    @concurrent static func load(_ url: URL, delimiter: Delimiter? = nil, header: Bool? = nil) async throws(PluginError) -> Loaded {
        let data: Data
        do { data = try Data(contentsOf: url, options: .alwaysMapped) } catch { throw PluginError("Couldn't read “\(url.lastPathComponent)”.") }
        var (text, format) = try TextCodec.decode(data)
        text.makeContiguousUTF8()  // a legacy encoding decodes to a bridged string, many times slower to index
        let table = CSVTable(text: text, delimiter: delimiter ?? CSVTable.guessDelimiter(in: text))
        let hasHeader = header ?? table.guessHeader()
        return Loaded(table: table, header: hasHeader, columns: ColumnSample.sample(table, hasHeader: hasHeader),
                      format: format, byteCount: data.count)
    }
}
