import Foundation
import PeekerKit
import UniformTypeIdentifiers

/// Structured data as a collapsible tree with an outline, the text one toggle away; JSON editable in the tree.
public enum DataPlugin: Plugin {
    public static let id = "data"
    public static let name = "Data"
    public static let symbol = "curlybraces"
    public static let defaultExtensions = ["json", "jsonc", "yaml", "yml", "toml", "xml", "plist"]
    public static let readableTypes = [UTType.json, .yaml, .xml, .propertyList] + [UTType(filenameExtension: "toml")].compactMap(\.self)
    public static let tools = [
        ToolSpec(id: "zoom-in", title: "Zoom In", symbol: "plus.magnifyingglass", shortcut: "cmd+=", showsInToolbar: false),
        ToolSpec(id: "zoom-out", title: "Zoom Out", symbol: "minus.magnifyingglass", shortcut: "cmd+-", showsInToolbar: false),
        ToolSpec(id: "zoom-actual", title: "Actual Size", symbol: "1.magnifyingglass", shortcut: "cmd+0", showsInToolbar: false),
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
        let text: String
        let textFormat: TextFormat
        let format: DataFormat
        /// Why the text can't be edited; nil when it can.
        let readOnlyReason: String?
        /// The text is only the file's first part, so there's no tree.
        let isPartial: Bool
        let info: [InfoRow]
        /// Nil for a partial text.
        let parsed: Result<DataNode, SyntaxError>?
        let colors: CodeColoring.Scan?
    }

    @concurrent static func load(_ url: URL) async throws(PluginError) -> Loaded {
        if try startsLikeBinaryPropertyList(url) { return try convertedPropertyList(url, kind: "Binary") }
        let file = try await TextFile.load(url)
        let format = DataFormat(fileExtension: url.pathExtension, text: file.text)
        // One that doesn't read as OpenStep either, such as an empty file, shows its text with the error.
        if format == .plist, !file.isPartial, !DataFormat.startsWithTag(file.text), let converted = try? convertedPropertyList(url, kind: "OpenStep") {
            return converted
        }
        return Loaded(text: file.text, textFormat: file.format, format: format,
                      readOnlyReason: file.editable ? nil : file.note ?? TextFile.readOnlyNote, isPartial: file.isPartial,
                      info: info(file), parsed: file.isPartial ? nil : format.parse(file.text),
                      colors: await CodeColoring.scan(url, text: file.text))
    }

    /// Whether a property list's XML stays within `budget` bytes, counted roughly before it's written. A binary list can
    /// point at one value many times, and the XML repeats it each time: a 3 KB file can come to a gigabyte.
    nonisolated static func fitsAsXML(_ value: Any, within budget: inout Int) -> Bool {
        budget -= 32
        switch value {
        case let string as String: budget -= string.utf8.count
        case let data as Data: budget -= data.count * 4 / 3
        case let array as [Any]:
            for item in array { guard fitsAsXML(item, within: &budget) else { return false } }
        case let dictionary as [String: Any]:
            for (key, item) in dictionary {
                budget -= key.utf8.count
                guard fitsAsXML(item, within: &budget) else { return false }
            }
        default: break
        }
        return budget >= 0
    }

    nonisolated static func info(_ file: TextFile.Loaded) -> [InfoRow] {
        [InfoRow(label: "Lines", value: file.lineCount.formatted()),
         InfoRow(label: "Encoding", value: String.localizedName(of: file.format.encoding) + (file.format.hasBOM ? " with BOM" : "")),
         InfoRow(label: "Size", value: ByteCountFormatter.string(fromByteCount: Int64(file.byteCount), countStyle: .file))]
    }

    private nonisolated static func startsLikeBinaryPropertyList(_ url: URL) throws(PluginError) -> Bool {
        let handle = try PluginError.catching { try FileHandle(forReadingFrom: url) }
        defer { try? handle.close() }
        return (try? handle.read(upToCount: 6)) == Data("bplist".utf8)
    }

    /// A property list that isn't XML text, binary or the old OpenStep form, shown and parsed as its XML form; it's
    /// never saved from that text, so it's read-only.
    private nonisolated static func convertedPropertyList(_ url: URL, kind: String) throws(PluginError) -> Loaded {
        let data = try PluginError.catching { try Data(contentsOf: url, options: .alwaysMapped) }
        let tooLarge = PluginError("This property list is too large to show.")
        guard data.count <= TextLimits.displayBytes else { throw tooLarge }
        guard let list = try? PropertyListSerialization.propertyList(from: data, format: nil) else { throw PluginError("This property list can't be read.") }
        var budget = TextLimits.displayBytes
        guard fitsAsXML(list, within: &budget) else { throw tooLarge }
        guard let xml = try? PropertyListSerialization.data(fromPropertyList: list, format: .xml, options: 0) else {
            throw PluginError("This property list can't be read.")
        }
        guard xml.count <= TextLimits.displayBytes else { throw tooLarge }
        let text = String(decoding: xml, as: UTF8.self)
        return Loaded(text: text, textFormat: TextFormat(encoding: .utf8, hasBOM: false, lineEnding: .lf), format: .plist,
                      readOnlyReason: "\(kind) property lists show as XML, read-only.", isPartial: false,
                      info: [InfoRow(label: "Format", value: "\(kind) property list"),
                             InfoRow(label: "Size", value: ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))],
                      parsed: XMLReader.parse(text), colors: nil)
    }
}
