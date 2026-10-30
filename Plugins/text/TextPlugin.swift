import Foundation

final class TextPlugin: PluginHandler {
    static let readOnlyNote = "Read-only: files over 10 MB open for viewing only."

    private struct Document {
        let path: String
        var format: TextFormat
        /// The text as last loaded or saved, kept only for editable files.
        var savedUTF8: Data?
        var info: [InfoRow]
        /// Why the document is read-only (over the edit limit, or only partly shown); nil when editable.
        let readOnlyReason: String?
    }

    private var documents: [DocumentID: Document] = [:]

    init() {}

    func open(_ doc: DocumentID, path: String, maxPixels: Int) throws(PluginFailure) -> Reply {
        let data = try PluginFailure.catching { try Data(contentsOf: URL(filePath: path), options: .alwaysMapped) }
        let (text, format) = try TextCodec.decode(data)
        let utf8 = text.utf8
        let (shownCount, limit) = Self.displayedByteCount(text)
        let shown = utf8.prefix(shownCount)
        let file = try SharedFile.create(byteCount: shown.count) { buffer in buffer.copyBytes(from: shown) }
        // Both limits: legacy bytes can grow to three UTF-8 bytes each, so a file within the edit limit on disk can
        // still be cut for display, and saving that part would cut the file.
        let truncated = shown.count < utf8.count
        let editable = data.count <= TextLimits.editableBytes && !truncated
        let note = truncated ? "Showing the first \(limit / 1_048_576) MB of \(Self.size(data.count)). Read-only." : editable ? nil : Self.readOnlyNote
        let info = Self.info(text: text, format: format, byteCount: data.count)
        documents[doc] = Document(path: path, format: format, savedUTF8: editable ? Data(utf8) : nil, info: info, readOnlyReason: note)
        return Reply(view: .text(SharedText(file: file, editable: editable, note: note)), sidebar: [.info(info)], commands: Self.commands)
    }

    func save(_ doc: DocumentID, _ payload: SavePayload) throws(PluginFailure) -> Reply {
        guard case .text(let ref, let convertToUTF8) = payload else { throw PluginFailure("The text plugin can only save text.") }
        let edited = try SharedFile.withMapped(ref) { Data($0) }  // first, so the shared file is always unlinked
        guard var document = documents[doc] else { throw PluginFailure("unknown document") }
        guard document.readOnlyReason == nil, let saved = document.savedUTF8 else { throw PluginFailure(document.readOnlyReason ?? Self.readOnlyNote) }
        let format = convertToUTF8 ? TextFormat(encoding: .utf8, hasBOM: false, lineEnding: document.format.lineEnding) : document.format
        // Bytes, not String ==, which treats canonically equivalent text as equal.
        if format == document.format && edited == saved { return Reply(sidebar: [.info(document.info)]) }

        guard let text = String(validating: edited, as: UTF8.self) else { throw PluginFailure("The edited text isn't valid UTF-8.") }
        let name = URL(filePath: document.path).lastPathComponent
        let data: Data
        do throws(PluginFailure) {
            data = try TextCodec.encode(text, as: format)
        } catch {
            throw PluginFailure("“\(name)” can't be saved as \(String.localizedName(of: format.encoding)).", code: error.code)
        }
        try FileReplacement.replaceContents(ofFileAt: document.path, with: data)
        document.format = format
        document.savedUTF8 = edited
        document.info = Self.info(text: text, format: format, byteCount: data.count)
        documents[doc] = document
        return Reply(sidebar: [.info(document.info)])
    }

    func close(_ doc: DocumentID) {
        documents[doc] = nil
    }

    static let commands = [
        CommandSpec(id: "zoom-in", title: "Zoom In", symbol: "plus.magnifyingglass", shortcut: "cmd+=", verb: "zoom-in"),
        CommandSpec(id: "zoom-out", title: "Zoom Out", symbol: "minus.magnifyingglass", shortcut: "cmd+-", verb: "zoom-out"),
        CommandSpec(id: "toggle-wrap", title: "Wrap Lines", symbol: "arrow.turn.down.left", shortcut: "opt+cmd+w", verb: "toggle-wrap"),
    ]

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

    private static func info(text: String, format: TextFormat, byteCount: Int) -> [InfoRow] {
        [InfoRow(label: "Lines", value: TextCodec.lineCount(of: text).formatted()),
         InfoRow(label: "Encoding", value: String.localizedName(of: format.encoding) + (format.hasBOM ? " with BOM" : "")),
         InfoRow(label: "Line endings", value: format.lineEnding.rawValue),
         InfoRow(label: "Size", value: size(byteCount))]
    }
}
