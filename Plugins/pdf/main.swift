import CoreGraphics
import Foundation

/// Validates with CoreGraphics rather than PDFKit, so a cold start doesn't load AppKit.
final class PDFPlugin: PluginHandler {
    func open(doc: String, path: String, params: [String: Any]) throws -> [String: Any] {
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
        var info = [["Pages", document.numberOfPages.formatted()], ["PDF version", "\(major).\(minor)"]]
        for (key, label) in [("Title", "Title"), ("Author", "Author"), ("Creator", "Created with")] {
            if let value = Self.string(document.info, key), !value.isEmpty { info.append([label, value]) }
        }
        if document.isEncrypted { info.append(["Encrypted", "Yes"]) }
        return [
            "view": ["type": "pdf", "path": path],
            "sidebar": [["type": "thumbnails"], ["type": "info", "rows": info]],
            "commands": [
                ["id": "zoom-in", "title": "Zoom In", "symbol": "plus.magnifyingglass", "shortcut": "cmd+=", "verb": "zoom-in"],
                ["id": "zoom-out", "title": "Zoom Out", "symbol": "minus.magnifyingglass", "shortcut": "cmd+-", "verb": "zoom-out"],
                ["id": "highlight", "title": "Highlight Selection", "symbol": "highlighter", "shortcut": "ctrl+cmd+h", "verb": "highlight"],
                ["id": "save", "title": "Save", "symbol": "square.and.arrow.down", "shortcut": "cmd+s", "verb": "save"],
            ],
        ]
    }

    func command(doc: String, id: String, args: [String: Any]) throws -> [String: Any] {
        throw PluginFailure("unknown command \(id)")
    }

    func close(doc: String) {}

    private static func string(_ dictionary: CGPDFDictionaryRef?, _ key: String) -> String? {
        guard let dictionary else { return nil }
        var value: CGPDFStringRef?
        guard CGPDFDictionaryGetString(dictionary, key, &value), let value else { return nil }
        return CGPDFStringCopyTextString(value) as String?
    }
}

PluginMain.run(PDFPlugin())
