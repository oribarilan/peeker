import Foundation
import PeekerKit
import UniformTypeIdentifiers

/// Structured data as a collapsible tree with an outline, the text one toggle away; JSON editable in the tree.
public enum DataPlugin: Plugin {
    public static let id = "data"
    public static let name = "Data"
    public static let symbol = "curlybraces"
    public static let defaultExtensions = ["json", "jsonc"]
    public static let readableTypes = [UTType.json]
    public static let tools = [
        ToolSpec(id: "show-text", title: "Show Text", showsInToolbar: false),
        ToolSpec(id: "add-item", title: "Add Item", symbol: "plus", isEditTool: true),
        ToolSpec(id: "add-child", title: "Add Child", isEditTool: true, showsInToolbar: false),
        ToolSpec(id: "delete-item", title: "Delete Item", isEditTool: true, showsInToolbar: false),
    ]

    public static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument {
        let loaded = try await load(url)
        if Task.isCancelled { throw PluginError.cancelled }
        return DataDocument(url: url, loaded: loaded, allowsEditing: context.allowsEditing, preferences: context.preferences)
    }

    public static func recoveryText(from edits: Data) -> String? {
        (try? JSONDecoder().decode(TextEdits.self, from: edits))?.text
    }

    /// A file read, decoded, parsed and its syntax colors found, off the main thread.
    struct Loaded: Sendable {
        let file: TextFile.Loaded
        let parsed: Result<JSONNode, JSONError>
        let colors: CodeColoring.Scan?
    }

    @concurrent static func load(_ url: URL) async throws(PluginError) -> Loaded {
        let file = try await TextFile.load(url)
        // A file shown only in part gets no tree, so there's nothing to parse.
        let parsed = file.isPartial ? .failure(JSONError(message: "", offset: 0, line: 0, column: 0)) : JSONParser.parse(file.text)
        return Loaded(file: file, parsed: parsed, colors: await CodeColoring.scan(url, text: file.text))
    }
}
