import Foundation

// The contract between the host and plugin processes, compiled into both.
//
// Transport: one JSON object per line on the plugin's stdin and stdout.
//
//     host   -> {"id": 1, "method": "open", "params": {"doc": "…", "path": "/a.md", "maxPixels": 3024}}
//     plugin -> {"id": 1, "result": {"view": {…}, "sidebar": [{…}], "commands": [{…}]}}
//     host   -> {"id": 2, "method": "command", "params": {"doc": "…", "command": "toggle-task", "args": {"line": 4}}}
//     host   -> {"method": "close", "params": {"doc": "…"}}          (no reply)
//
// A plugin never draws. "view" names a host component and its data:
//
//     {"type": "markdown", "blocks": [...]}     host lays out the block tree
//     {"type": "pdf", "path": "/a.pdf"}         host shows PDFKit (path must be the opened file)
//     {"type": "bitmap", "file": …, "width": …, "height": …, "bytesPerRow": …}
//                                               pixels the plugin decoded, shared through a mapped file
//
// "sidebar" panels: {"type": "outline", "items": [{"title", "level", "anchor"}]},
// {"type": "thumbnails"}, {"type": "info", "rows": [["Pages", "12"], …]}.
//
// "commands": [{"id", "title", "symbol"?, "shortcut"?, "verb"?}]. A command with a "verb" is handled by
// the host component directly (zoom, save); one without is sent back to the plugin.

/// `manifest.json` in each `<id>.ppp` folder. The host reads it without starting the plugin.
struct PluginManifest: Codable, Equatable {
    let id: String
    let name: String
    /// UTType identifiers. Files conforming to any of them can be routed to this plugin.
    let types: [String]
    /// Executable inside the plugin folder.
    let executable: String
}

/// Style bits for Markdown spans: `[text, styleBits, link?]`.
struct SpanStyle: OptionSet {
    let rawValue: Int
    static let strong = SpanStyle(rawValue: 1)
    static let emphasis = SpanStyle(rawValue: 2)
    static let code = SpanStyle(rawValue: 4)
    static let strikethrough = SpanStyle(rawValue: 8)
    static let image = SpanStyle(rawValue: 16)
}

/// Shared-memory bitmaps: premultiplied BGRA, sRGB, in a file under the user's temporary directory.
enum SharedBitmapFormat {
    static let prefix = "ppp-bitmap-"
    static let maxDimension = 16_384
}
