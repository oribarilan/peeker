import Foundation
import PeekerKit

public enum TextPlugin: Plugin {
    public static let id = "text"
    public static let name = "Plain Text"
    public static let symbol = "doc.plaintext"
    /// Text, data and config formats, common source code, and files with no extension (dotfiles, `Makefile`).
    public static let defaultExtensions = [
        "txt", "text", "log", "csv", "tsv", "json", "jsonc", "xml", "yaml", "yml", "toml",
        "ini", "conf", "cfg", "env", "properties",
        "sh", "bash", "zsh", "fish", "py", "rb", "pl", "js", "mjs", "cjs", "ts", "tsx", "jsx", "swift",
        "c", "h", "m", "mm", "cc", "cpp", "hpp", "go", "rs", "java", "kt", "sql", "css", "scss", "diff", "patch",
        noExtension,
    ]
    public static let tools = [
        ToolSpec(id: "zoom-in", title: "Zoom In", symbol: "plus.magnifyingglass", shortcut: "cmd+=", showsInToolbar: false),
        ToolSpec(id: "zoom-out", title: "Zoom Out", symbol: "minus.magnifyingglass", shortcut: "cmd+-", showsInToolbar: false),
        ToolSpec(id: "toggle-wrap", title: "Wrap Lines", symbol: "arrow.turn.down.left", shortcut: "opt+cmd+w"),
    ]

    public static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument {
        TextDocument(url: url, loaded: try await TextFile.load(url), allowsEditing: context.allowsEditing)
    }

    public static func recoveryText(from edits: Data) -> String? {
        (try? JSONDecoder().decode(TextEdits.self, from: edits))?.text
    }

    private nonisolated static func size(_ byteCount: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
    }

    nonisolated static func info(lineCount: Int, format: TextFormat, byteCount: Int) -> [InfoRow] {
        [InfoRow(label: "Lines", value: lineCount.formatted()),
         InfoRow(label: "Encoding", value: String.localizedName(of: format.encoding) + (format.hasBOM ? " with BOM" : "")),
         InfoRow(label: "Line endings", value: format.lineEnding.rawValue),
         InfoRow(label: "Size", value: size(byteCount))]
    }
}
