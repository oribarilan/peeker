import Foundation
import PeekerKit
import UniformTypeIdentifiers

public enum TextPlugin: Plugin {
    public static let id = "text"
    public static let name = "Plain Text"
    /// JSON, XML, YAML and TOML don't conform to plain text on macOS, so they're listed on their own.
    public static let fileTypes: [UTType] = [.plainText, .json, .xml, .yaml, UTType("public.toml") ?? UTType(importedAs: "public.toml")]
    public static let commands = [
        CommandSpec(id: "zoom-in", title: "Zoom In", symbol: "plus.magnifyingglass", shortcut: "cmd+="),
        CommandSpec(id: "zoom-out", title: "Zoom Out", symbol: "minus.magnifyingglass", shortcut: "cmd+-"),
        CommandSpec(id: "toggle-wrap", title: "Wrap Lines", symbol: "arrow.turn.down.left", shortcut: "opt+cmd+w"),
    ]

    nonisolated static let readOnlyNote = "Read-only: files over 10 MB open for viewing only."
    nonisolated static let saveAsUTF8 = SaveOffer(id: "utf8", button: "Save as UTF-8", detail: "Some characters can't be represented in the file's encoding.")

    public static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument {
        TextDocument(url: url, loaded: try await load(url), allowsEditing: context.allowsEditing)
    }

    public static func recoveryText(from edits: Data) -> String? {
        (try? JSONDecoder().decode(TextEdits.self, from: edits))?.text
    }

    struct Loaded: Sendable {
        /// What the view shows: all of the text, or its first part when the file is too big.
        let text: String
        let format: TextFormat
        /// Small enough to edit, and shown in full.
        let editable: Bool
        /// Why the file is read-only or only partly shown; nil when it's editable.
        let note: String?
        let info: [InfoRow]
    }

    /// Reads and decodes the file off the main thread, cutting it to what the view can lay out quickly.
    @concurrent nonisolated static func load(_ url: URL) async throws(PluginError) -> Loaded {
        let data = try PluginError.catching { try Data(contentsOf: url, options: .alwaysMapped) }
        let (text, format) = try TextCodec.decode(data)
        let utf8 = text.utf8
        let (shownCount, limit) = displayedByteCount(text)
        // Both limits: legacy bytes can grow to three UTF-8 bytes each, so a file within the edit limit on disk can
        // still be cut for display, and saving that part would cut the file.
        let truncated = shownCount < utf8.count
        let editable = data.count <= TextLimits.editableBytes && !truncated
        let note = truncated ? "Showing the first \(limit / 1_048_576) MB of \(size(data.count)). Read-only." : editable ? nil : readOnlyNote
        let shown = truncated ? String(decoding: utf8.prefix(shownCount), as: UTF8.self) : text
        return Loaded(text: shown, format: format, editable: editable, note: note, info: info(text: text, format: format, byteCount: data.count))
    }

    /// Writes `text` to `path` as `format`, off the main thread, and returns the info rows for the result. Never
    /// substitutes characters: text the encoding can't hold fails with an offer to save as UTF-8.
    @concurrent nonisolated static func write(_ text: String, as format: TextFormat, to path: String) async throws(PluginError) -> [InfoRow] {
        let data: Data
        do throws(PluginError) {
            data = try TextCodec.encode(text, as: format)
        } catch {
            let name = URL(filePath: path).lastPathComponent
            throw PluginError("“\(name)” can't be saved as \(String.localizedName(of: format.encoding)).", code: error.code,
                              offer: error.code == .cannotEncode ? saveAsUTF8 : nil)
        }
        try FileReplacement.replaceContents(ofFileAt: path, with: data)
        return info(text: text, format: format, byteCount: data.count)
    }

    /// How much of `text`'s UTF-8 to show, and the limit that applied: all of it, or the first `TextLimits.displayBytes`
    /// (`longLineDisplayBytes` when a line in them is very long) cut after the last line break, or, in one huge line,
    /// before the character the limit would split.
    private nonisolated static func displayedByteCount(_ text: String) -> (count: Int, limit: Int) {
        var text = text  // `withUTF8` is mutating; a native string is used in place, a bridged one (legacy encodings) is copied
        return text.withUTF8 { bytes in
            let head = scanBreaks(UnsafeBufferPointer(rebasing: bytes.prefix(TextLimits.displayBytes)))
            let limit = head.hasLongLine ? TextLimits.longLineDisplayBytes : TextLimits.displayBytes
            guard bytes.count > limit else { return (bytes.count, limit) }
            if let cut = head.hasLongLine ? head.lastBreakEndWithinLongLineLimit : head.lastBreakEnd { return (cut, limit) }
            var end = limit
            while end > 0 && bytes[end] & 0xC0 == 0x80 { end -= 1 }
            return (end, limit)
        }
    }

    /// One pass over the line breaks (LF or CR) in `head`: whether a line is longer than `TextLimits.longLineBytes`, and
    /// where the last break ends overall and within `longLineDisplayBytes`. Follows the next LF and the next CR with
    /// memchr, each searched for again only once passed, so 16 MB take about 2 ms.
    private nonisolated static func scanBreaks(_ head: UnsafeBufferPointer<UInt8>) -> (hasLongLine: Bool, lastBreakEnd: Int?, lastBreakEndWithinLongLineLimit: Int?) {
        guard let base = head.baseAddress else { return (false, nil, nil) }
        func next(_ byte: UInt8, from start: Int) -> Int {
            guard start < head.count, let found = memchr(base + start, Int32(byte), head.count - start) else { return head.count }
            return UnsafeRawPointer(found) - UnsafeRawPointer(base)
        }
        var hasLongLine = false, lastBreakEnd: Int?, lastBreakEndWithinLongLineLimit: Int?
        var lineStart = 0, nextLF = next(0x0A, from: 0), nextCR = next(0x0D, from: 0)
        while true {
            let lineEnd = min(nextLF, nextCR)
            if lineEnd - lineStart > TextLimits.longLineBytes { hasLongLine = true }
            if lineEnd == head.count { return (hasLongLine, lastBreakEnd, lastBreakEndWithinLongLineLimit) }
            lineStart = lineEnd + 1
            lastBreakEnd = lineStart
            if lineStart <= TextLimits.longLineDisplayBytes { lastBreakEndWithinLongLineLimit = lineStart }
            if nextLF < lineStart { nextLF = next(0x0A, from: lineStart) }
            if nextCR < lineStart { nextCR = next(0x0D, from: lineStart) }
        }
    }

    private nonisolated static func size(_ byteCount: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
    }

    nonisolated static func info(text: String, format: TextFormat, byteCount: Int) -> [InfoRow] {
        [InfoRow(label: "Lines", value: TextCodec.lineCount(of: text).formatted()),
         InfoRow(label: "Encoding", value: String.localizedName(of: format.encoding) + (format.hasBOM ? " with BOM" : "")),
         InfoRow(label: "Line endings", value: format.lineEnding.rawValue),
         InfoRow(label: "Size", value: size(byteCount))]
    }
}

/// A document's unsaved text. Encoded as `{"text":{"_0":…}}`, the shape recovery records had before plugins
/// moved into the app, so those records still restore.
nonisolated enum TextEdits: Codable, Sendable {
    case text(String)

    var text: String {
        switch self {
        case .text(let text): text
        }
    }
}
