import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Decodes in this process and hands the host finished pixels, so a malformed image can only crash the plugin.
final class ImagePlugin: PluginHandler {
    func open(doc: String, path: String, params: [String: Any]) throws -> [String: Any] {
        let url = URL(filePath: path)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(source) > 0 else { throw PluginFailure("This file isn't a readable image.") }
        let maxPixels = min(params["maxPixels"] as? Int ?? 2048, SharedBitmapFormat.maxDimension)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw PluginFailure("This image couldn't be decoded.")
        }
        return [
            "view": try SharedBitmap.write(image),
            "sidebar": [["type": "info", "rows": info(source, url)]],
            "commands": [
                ["id": "zoom-in", "title": "Zoom In", "symbol": "plus.magnifyingglass", "shortcut": "cmd+=", "verb": "zoom-in"],
                ["id": "zoom-out", "title": "Zoom Out", "symbol": "minus.magnifyingglass", "shortcut": "cmd+-", "verb": "zoom-out"],
                ["id": "zoom-fit", "title": "Zoom to Fit", "symbol": "arrow.up.left.and.down.right.magnifyingglass", "shortcut": "cmd+9", "verb": "zoom-fit"],
            ],
        ]
    }

    func command(doc: String, id: String, args: [String: Any]) throws -> [String: Any] {
        throw PluginFailure("unknown command \(id)")
    }

    func close(doc: String) {}

    private func info(_ source: CGImageSource, _ url: URL) -> [[String]] {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
        var rows: [[String]] = []
        if let width = properties[kCGImagePropertyPixelWidth] as? Int, let height = properties[kCGImagePropertyPixelHeight] as? Int {
            rows.append(["Dimensions", "\(width) × \(height)"])
        }
        if let type = CGImageSourceGetType(source).flatMap({ UTType($0 as String) }) {
            rows.append(["Kind", type.localizedDescription ?? type.identifier])
        }
        if let model = properties[kCGImagePropertyColorModel] as? String { rows.append(["Color", model]) }
        if let profile = properties[kCGImagePropertyProfileName] as? String { rows.append(["Profile", profile]) }
        if let dpi = properties[kCGImagePropertyDPIWidth] as? Double { rows.append(["Resolution", "\(Int(dpi)) dpi"]) }
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        if let camera = tiff[kCGImagePropertyTIFFModel] as? String { rows.append(["Camera", camera]) }
        if let lens = exif[kCGImagePropertyExifLensModel] as? String { rows.append(["Lens", lens]) }
        if let taken = exif[kCGImagePropertyExifDateTimeOriginal] as? String { rows.append(["Taken", taken]) }
        if let bytes = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
            rows.append(["File size", ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)])
        }
        return rows
    }
}

PluginMain.run(ImagePlugin())
