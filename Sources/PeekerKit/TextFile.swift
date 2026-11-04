import Foundation

/// A document's unsaved text, encoded as `{"text": …}`.
public nonisolated struct TextEdits: Codable, Sendable {
    public let text: String

    public init(text: String) {
        self.text = text
    }
}

/// Reads and writes text files for the plugins that show them as text.
public nonisolated enum TextFile {
    public static let readOnlyNote = "Read-only: files over 10 MB open for viewing only."
    public static let saveAsUTF8 = SaveOffer(id: "utf8", button: "Save as UTF-8", detail: "Some characters can't be represented in the file's encoding.")

    public struct Loaded: Sendable {
        /// What the view shows: all of the text, or its first part when the file is too big.
        public let text: String
        public let format: TextFormat
        /// Small enough to edit, and shown in full.
        public let editable: Bool
        /// Why the file is read-only or only partly shown; nil when it's editable.
        public let note: String?
        /// The file's size on disk.
        public let byteCount: Int
        /// Lines in the whole file, not just the part shown.
        public let lineCount: Int
    }

    /// Reads and decodes the file off the main thread, cutting it to what the view can lay out quickly.
    @concurrent public static func load(_ url: URL) async throws(PluginError) -> Loaded {
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
        return Loaded(text: shown, format: format, editable: editable, note: note, byteCount: data.count, lineCount: TextCodec.lineCount(of: text))
    }

    /// Writes `text` to `path` as `format`, off the main thread, and returns the bytes written. Never substitutes
    /// characters: text the encoding can't hold fails with an offer to save as UTF-8.
    @concurrent public static func write(_ text: String, as format: TextFormat, to path: String) async throws(PluginError) -> Int {
        let data: Data
        do throws(PluginError) {
            data = try TextCodec.encode(text, as: format)
        } catch {
            let name = URL(filePath: path).lastPathComponent
            throw PluginError("“\(name)” can't be saved as \(String.localizedName(of: format.encoding)).", code: error.code,
                              offer: error.code == .cannotEncode ? saveAsUTF8 : nil)
        }
        try FileReplacement.replaceContents(ofFileAt: path, with: data)
        return data.count
    }

    /// How much of `text`'s UTF-8 to show, and the limit that applied: all of it, or the first `TextLimits.displayBytes`
    /// (`longLineDisplayBytes` when a line in them is very long) cut after the last line break, or, in one huge line,
    /// before the character the limit would split.
    private static func displayedByteCount(_ text: String) -> (count: Int, limit: Int) {
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
    private static func scanBreaks(_ head: UnsafeBufferPointer<UInt8>) -> (hasLongLine: Bool, lastBreakEnd: Int?, lastBreakEndWithinLongLineLimit: Int?) {
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

    private static func size(_ byteCount: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
    }
}
