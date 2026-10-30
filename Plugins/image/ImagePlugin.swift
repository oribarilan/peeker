import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Decodes in this process and hands the host finished pixels, so a malformed image can only crash the plugin.
final class ImagePlugin: PluginHandler {
    func open(_ doc: DocumentID, path: String, maxPixels: Int) throws(PluginFailure) -> Reply {
        let url = URL(filePath: path)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(source) > 0 else { throw PluginFailure("This file isn't a readable image.") }
        let maxPixels = min(maxPixels, SharedBitmap.maxDimension)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw PluginFailure("This image couldn't be decoded.")
        }
        return Reply(view: .bitmap(try SharedBitmap.write(image)), sidebar: [.info(info(source, url))], commands: [
            CommandSpec(id: "zoom-in", title: "Zoom In", symbol: "plus.magnifyingglass", shortcut: "cmd+=", verb: "zoom-in"),
            CommandSpec(id: "zoom-out", title: "Zoom Out", symbol: "minus.magnifyingglass", shortcut: "cmd+-", verb: "zoom-out"),
            CommandSpec(id: "zoom-fit", title: "Zoom to Fit", symbol: "arrow.up.left.and.down.right.magnifyingglass", shortcut: "cmd+9", verb: "zoom-fit"),
        ])
    }

    private func info(_ source: CGImageSource, _ url: URL) -> [InfoRow] {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
        var rows: [InfoRow] = []
        if let width = properties[kCGImagePropertyPixelWidth] as? Int, let height = properties[kCGImagePropertyPixelHeight] as? Int {
            rows.append(InfoRow(label: "Dimensions", value: "\(width) × \(height)"))
        }
        if let type = CGImageSourceGetType(source).flatMap({ UTType($0 as String) }) {
            rows.append(InfoRow(label: "Kind", value: type.localizedDescription ?? type.identifier))
        }
        if let model = properties[kCGImagePropertyColorModel] as? String { rows.append(InfoRow(label: "Color", value: model)) }
        if let profile = properties[kCGImagePropertyProfileName] as? String { rows.append(InfoRow(label: "Profile", value: profile)) }
        if let dpi = properties[kCGImagePropertyDPIWidth] as? Double { rows.append(InfoRow(label: "Resolution", value: "\(Int(dpi)) dpi")) }
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        if let camera = tiff[kCGImagePropertyTIFFModel] as? String { rows.append(InfoRow(label: "Camera", value: camera)) }
        if let lens = exif[kCGImagePropertyExifLensModel] as? String { rows.append(InfoRow(label: "Lens", value: lens)) }
        if let taken = exif[kCGImagePropertyExifDateTimeOriginal] as? String { rows.append(InfoRow(label: "Taken", value: taken)) }
        if let bytes = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
            rows.append(InfoRow(label: "File size", value: ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)))
        }
        return rows
    }
}
