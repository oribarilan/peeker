import AppKit
import CoreGraphics
import PDFKit
import PeekerKit
import UniformTypeIdentifiers

public enum PDFPlugin: Plugin {
    public static let id = "pdf"
    public static let name = "PDF"
    public static let fileTypes: [UTType] = [.pdf]
    public static let commands = [
        CommandSpec(id: "zoom-in", title: "Zoom In", symbol: "plus.magnifyingglass", shortcut: "cmd+="),
        CommandSpec(id: "zoom-out", title: "Zoom Out", symbol: "minus.magnifyingglass", shortcut: "cmd+-"),
        CommandSpec(id: "highlight", title: "Highlight Selection", symbol: "highlighter", shortcut: "ctrl+cmd+h"),
    ]

    public static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument {
        let info = try await check(url)
        guard let document = PDFDocument(url: url) else { throw PluginError("This file isn't a readable PDF.") }
        return PDFPluginDocument(url: url, document: document, info: info, editable: context.allowsEditing)
    }

    /// Checks with CoreGraphics, which starts faster than PDFKit, that `url` is a readable, unlocked PDF, and reads
    /// what the info panel shows.
    @concurrent nonisolated static func check(_ url: URL) async throws(PluginError) -> [InfoRow] {
        guard let document = CGPDFDocument(url as CFURL) else { throw PluginError("This file isn't a readable PDF.") }
        guard document.isUnlocked else { throw PluginError("This PDF is password protected.") }
        var major: Int32 = 0, minor: Int32 = 0
        document.getVersion(majorVersion: &major, minorVersion: &minor)
        var info = [InfoRow(label: "Pages", value: document.numberOfPages.formatted()), InfoRow(label: "PDF version", value: "\(major).\(minor)")]
        for (key, label) in [("Title", "Title"), ("Author", "Author"), ("Creator", "Created with")] {
            if let value = string(document.info, key), !value.isEmpty { info.append(InfoRow(label: label, value: value)) }
        }
        if document.isEncrypted { info.append(InfoRow(label: "Encrypted", value: "Yes")) }
        return info
    }

    /// Adds `highlights` to the file at `path` as standard highlight annotations. Writes nothing if any of them
    /// can't be saved. Loads its own copy of the file, so it's safe off the main thread.
    @concurrent nonisolated static func write(_ highlights: [Highlight], to path: String) async throws(PluginError) {
        let name = URL(filePath: path).lastPathComponent
        guard let document = PDFDocument(url: URL(filePath: path)) else { throw PluginError("“\(name)” is no longer a readable PDF.") }
        guard !document.isLocked else { throw PluginError("This PDF is password protected.") }
        for highlight in highlights {
            guard (0..<document.pageCount).contains(highlight.page), let page = document.page(at: highlight.page) else {
                throw PluginError("Can't save a highlight on page \(highlight.page + 1): “\(name)” has \(document.pageCount) pages.")
            }
            guard highlight.isSavable(onPageWithMediaBox: page.bounds(for: .mediaBox)) else {
                throw PluginError("Can't save a highlight on page \(highlight.page + 1): its position or color is invalid.")
            }
            page.addAnnotation(annotation(for: highlight))
        }
        guard let data = document.dataRepresentation() else { throw PluginError("“\(name)” couldn't be written as a PDF.") }
        try FileReplacement.replaceContents(ofFileAt: path, with: data)
    }

    nonisolated static func annotation(for highlight: Highlight) -> PDFAnnotation {
        let annotation = PDFAnnotation(bounds: highlight.rect, forType: .highlight, withProperties: nil)
        let color = highlight.color
        annotation.color = NSColor(srgbRed: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
        return annotation
    }

    private nonisolated static func string(_ dictionary: CGPDFDictionaryRef?, _ key: String) -> String? {
        guard let dictionary else { return nil }
        var value: CGPDFStringRef?
        guard CGPDFDictionaryGetString(dictionary, key, &value), let value else { return nil }
        return CGPDFStringCopyTextString(value) as String?
    }
}
