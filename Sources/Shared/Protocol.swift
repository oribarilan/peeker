import CoreGraphics
import Foundation

// The contract between the host and plugin processes, compiled into both.
//
// Transport: one JSON-encoded `Request` per line on the plugin's stdin, one `Response` per line on its stdout,
// matched by id. `close` gets no reply. A plugin never draws: its `Reply` names a host component (`View`), sidebar
// panels and commands. A command with a `verb` is handled by the host component directly (zoom, highlight); one without
// is sent back to the plugin. Large payloads (pixels, text) travel through shared files, not the pipe.

/// `manifest.json` in each `<id>.ppp` folder. The host reads it without starting the plugin.
nonisolated struct PluginManifest: Codable, Equatable {
    let id: String
    let name: String
    /// UTType identifiers. Files conforming to any of them can be routed to this plugin.
    let types: [String]
    /// Executable inside the plugin folder.
    let executable: String
}

/// Style bits for Markdown spans.
nonisolated struct SpanStyle: OptionSet, Codable, Sendable, Hashable {
    let rawValue: Int
    static let strong = SpanStyle(rawValue: 1)
    static let emphasis = SpanStyle(rawValue: 2)
    static let code = SpanStyle(rawValue: 4)
    static let strikethrough = SpanStyle(rawValue: 8)
    static let image = SpanStyle(rawValue: 16)
}

typealias DocumentID = String

nonisolated struct Request: Codable, Sendable {
    let id: Int
    let doc: DocumentID
    let call: Call
}

nonisolated enum Call: Codable, Sendable {
    case open(path: String, maxPixels: Int)
    case command(id: String, args: [String: Int])
    case save(SavePayload)
    /// No reply.
    case close
}

nonisolated enum SavePayload: Codable, Sendable, Equatable {
    case text(SharedFileRef, convertToUTF8: Bool)
    case pdfHighlights([Highlight])
}

/// `page` is 0-based; `rect` is in page space.
nonisolated struct Highlight: Codable, Sendable, Equatable {
    let page: Int
    let rect: CGRect
    let color: RGBA
}

extension Highlight {
    /// What the PDF plugin will save: a finite rect of non-negative size that touches the page, in a color within 0...1.
    nonisolated func isSavable(onPageWithMediaBox mediaBox: CGRect) -> Bool {
        [rect.origin.x, rect.origin.y, rect.size.width, rect.size.height].allSatisfy(\.isFinite)
            && rect.size.width >= 0 && rect.size.height >= 0 && rect.intersects(mediaBox)
            && [color.red, color.green, color.blue, color.alpha].allSatisfy { (0...1).contains($0) }
    }
}

nonisolated struct RGBA: Codable, Sendable, Equatable {
    let red, green, blue, alpha: Double
}

nonisolated struct Response: Codable, Sendable {
    let id: Int
    let outcome: Outcome
}

nonisolated enum Outcome: Codable, Sendable {
    case reply(Reply)
    case failure(PluginFailure)
}

nonisolated struct PluginFailure: Error, Codable, Sendable, Equatable {
    enum Code: String, Codable, Sendable { case general, notText, notWritable, cannotEncode }
    let message: String
    let code: Code
    init(_ message: String, code: Code = .general) {
        self.message = message
        self.code = code
    }
}

nonisolated struct Reply: Codable, Sendable {
    var view: View? = nil
    var sidebar: [Panel]? = nil
    var commands: [CommandSpec]? = nil
}

nonisolated enum View: Codable, Sendable {
    case markdown([MarkdownBlock])
    case pdf(path: String)
    case bitmap(SharedBitmap)
    case text(SharedText)
}

/// Premultiplied BGRA, sRGB.
nonisolated struct SharedBitmap: Codable, Sendable {
    static let maxDimension = 16_384
    let file: SharedFileRef
    let width: Int
    let height: Int
    let bytesPerRow: Int
}

/// UTF-8 bytes.
nonisolated struct SharedText: Codable, Sendable {
    let file: SharedFileRef
    let editable: Bool
    let note: String?
}

nonisolated enum Panel: Codable, Sendable {
    case outline([OutlineItem])
    case thumbnails
    case info([InfoRow])
}

nonisolated struct OutlineItem: Codable, Sendable, Equatable {
    let title: String
    let level: Int
    let line: Int
}

nonisolated struct InfoRow: Codable, Sendable, Equatable {
    let label: String
    let value: String
}

nonisolated struct CommandSpec: Codable, Sendable, Equatable {
    let id: String
    let title: String
    var symbol: String? = nil
    var shortcut: String? = nil
    var verb: String? = nil
}
