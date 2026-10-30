import CoreGraphics
import Foundation
import PDFKit

/// Opens with CoreGraphics, which is faster to start than PDFKit. PDFKit only writes highlights when saving.
final class PDFPlugin: PluginHandler {
    private var paths: [DocumentID: String] = [:]

    func open(_ doc: DocumentID, path: String, maxPixels: Int) throws(PluginFailure) -> Reply {
        guard let document = CGPDFDocument(URL(filePath: path) as CFURL) else { throw PluginFailure("This file isn't a readable PDF.") }
        guard document.isUnlocked else { throw PluginFailure("This PDF is password protected.") }
        // Parse the first page here, so a file that crashes the PDF parser takes down this process before the host opens it.
        if let page = document.page(at: 1),
           let context = CGContext(data: nil, width: 48, height: 48, bitsPerComponent: 8, bytesPerRow: 0,
                                   space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) {
            context.concatenate(page.getDrawingTransform(.cropBox, rect: CGRect(x: 0, y: 0, width: 48, height: 48), rotate: 0, preserveAspectRatio: true))
            context.drawPDFPage(page)
        }

        var major: Int32 = 0, minor: Int32 = 0
        document.getVersion(majorVersion: &major, minorVersion: &minor)
        var info = [InfoRow(label: "Pages", value: document.numberOfPages.formatted()), InfoRow(label: "PDF version", value: "\(major).\(minor)")]
        for (key, label) in [("Title", "Title"), ("Author", "Author"), ("Creator", "Created with")] {
            if let value = Self.string(document.info, key), !value.isEmpty { info.append(InfoRow(label: label, value: value)) }
        }
        if document.isEncrypted { info.append(InfoRow(label: "Encrypted", value: "Yes")) }
        paths[doc] = path
        return Reply(view: .pdf(path: path), sidebar: [.thumbnails, .info(info)], commands: [
            CommandSpec(id: "zoom-in", title: "Zoom In", symbol: "plus.magnifyingglass", shortcut: "cmd+=", verb: "zoom-in"),
            CommandSpec(id: "zoom-out", title: "Zoom Out", symbol: "minus.magnifyingglass", shortcut: "cmd+-", verb: "zoom-out"),
            CommandSpec(id: "highlight", title: "Highlight Selection", symbol: "highlighter", shortcut: "ctrl+cmd+h", verb: "highlight"),
        ])
    }

    /// Adds the highlights the host sends to the file on disk.
    func save(_ doc: DocumentID, _ payload: SavePayload) throws(PluginFailure) -> Reply {
        guard case .pdfHighlights(let highlights) = payload else { throw PluginFailure("The PDF plugin can only save highlights.") }
        guard let path = paths[doc] else { throw PluginFailure("unknown document") }
        let name = URL(filePath: path).lastPathComponent
        guard let document = PDFDocument(url: URL(filePath: path)) else { throw PluginFailure("“\(name)” is no longer a readable PDF.") }
        guard !document.isLocked else { throw PluginFailure("This PDF is password protected.") }
        for highlight in highlights {
            guard (0..<document.pageCount).contains(highlight.page), let page = document.page(at: highlight.page) else {
                throw PluginFailure("Can't save a highlight on page \(highlight.page + 1): “\(name)” has \(document.pageCount) pages.")
            }
            guard highlight.isSavable(onPageWithMediaBox: page.bounds(for: .mediaBox)) else {
                throw PluginFailure("Can't save a highlight on page \(highlight.page + 1): its position or color is invalid.")
            }
            let color = highlight.color
            let annotation = PDFAnnotation(bounds: highlight.rect, forType: .highlight, withProperties: nil)
            annotation.color = NSColor(srgbRed: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
            page.addAnnotation(annotation)
        }
        guard let data = document.dataRepresentation() else { throw PluginFailure("“\(name)” couldn't be written as a PDF.") }
        try FileReplacement.replaceContents(ofFileAt: path, with: data)
        return Reply()
    }

    func close(_ doc: DocumentID) {
        paths[doc] = nil
    }

    private static func string(_ dictionary: CGPDFDictionaryRef?, _ key: String) -> String? {
        guard let dictionary else { return nil }
        var value: CGPDFStringRef?
        guard CGPDFDictionaryGetString(dictionary, key, &value), let value else { return nil }
        return CGPDFStringCopyTextString(value) as String?
    }
}
