import CoreGraphics
import Foundation
import ImageIO
import PeekerKit
import UniformTypeIdentifiers

public enum ImagePlugin: Plugin {
    public static let id = "image"
    public static let name = "Image"
    public static let fileTypes: [UTType] = [.image]
    /// Larger decodes would be refused by Core Animation anyway.
    nonisolated static let maxDimension = 16_384

    public static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument {
        let decoded = try await decode(url, maxPixels: context.maxPixels)
        return ImageDocument(image: decoded.image, info: decoded.info)
    }

    struct Decoded: Sendable {
        let image: CGImage
        let info: [InfoRow]
    }

    /// Decodes the first image, upright and at most `maxPixels` on its longer side, into premultiplied sRGB, the
    /// layout Core Animation draws without converting on the main thread.
    @concurrent nonisolated static func decode(_ url: URL, maxPixels: Int) async throws(PluginError) -> Decoded {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(source) > 0 else { throw PluginError("This file isn't a readable image.") }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: min(maxPixels, maxDimension),
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw PluginError("This image couldn't be decoded.")
        }
        if Task.isCancelled { throw PluginError.cancelled }
        return Decoded(image: try displayReady(thumbnail), info: info(source, url))
    }

    private nonisolated static func displayReady(_ image: CGImage) throws(PluginError) -> CGImage {
        let info = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        guard let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: info) else {
            throw PluginError("This image couldn't be decoded.")
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let converted = context.makeImage() else { throw PluginError("This image couldn't be decoded.") }
        return converted
    }

    private nonisolated static func info(_ source: CGImageSource, _ url: URL) -> [InfoRow] {
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
