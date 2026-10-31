import CoreGraphics
import Foundation
import ImageIO
import PeekerKit
import UniformTypeIdentifiers

public enum ImagePlugin: Plugin {
    public static let id = "image"
    public static let name = "Image"
    /// The common formats ImageIO decodes, and camera RAW. Not SVG: ImageIO can't draw it.
    public static let defaultExtensions = [
        "png", "jpg", "jpeg", "jpe", "heic", "heif", "hif", "avif", "gif", "tif", "tiff", "webp", "bmp", "ico", "icns",
        "jxl", "jp2", "psd", "exr",
        "dng", "cr2", "cr3", "crw", "nef", "nrw", "arw", "sr2", "srf", "raf", "orf", "rw2", "rwl", "pef", "srw", "erf",
        "raw", "3fr", "iiq",
    ]
    public static let commands = [
        CommandSpec(id: "zoom-in", title: "Zoom In", symbol: "plus.magnifyingglass", shortcut: "cmd+="),
        CommandSpec(id: "zoom-out", title: "Zoom Out", symbol: "minus.magnifyingglass", shortcut: "cmd+-"),
        CommandSpec(id: "zoom-fit", title: "Zoom to Fit", symbol: "arrow.up.left.and.down.right.magnifyingglass", shortcut: "cmd+9"),
    ]
    /// Larger decodes would be refused by Core Animation anyway.
    nonisolated static let maxDimension = 16_384

    public static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument {
        let decoded = try await decode(url, maxPixels: context.maxPixels)
        return ImageDocument(image: decoded.image, printSize: decoded.printSize, info: decoded.info)
    }

    struct Decoded: Sendable {
        let image: CGImage
        /// The full image's size in points, upright: pixels at its resolution, or 72 per inch when it states none.
        let printSize: CGSize
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
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
        return Decoded(image: try displayReady(thumbnail), printSize: printSize(properties, decoded: thumbnail), info: info(properties, source, url))
    }

    private nonisolated static func printSize(_ properties: [CFString: Any], decoded: CGImage) -> CGSize {
        func points(_ pixels: CFString, _ dpi: CFString) -> Double? {
            guard let pixels = properties[pixels] as? Double, pixels > 0 else { return nil }
            let dpi = (properties[dpi] as? Double).flatMap { $0 > 0 && $0.isFinite ? $0 : nil } ?? 72
            return pixels * 72 / dpi
        }
        guard let width = points(kCGImagePropertyPixelWidth, kCGImagePropertyDPIWidth),
              let height = points(kCGImagePropertyPixelHeight, kCGImagePropertyDPIHeight) else {
            return CGSize(width: decoded.width, height: decoded.height)
        }
        // Orientations 5 to 8 turn the image a quarter turn.
        let turned = (5...8).contains(properties[kCGImagePropertyOrientation] as? Int ?? 1)
        return turned ? CGSize(width: height, height: width) : CGSize(width: width, height: height)
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

    private nonisolated static func info(_ properties: [CFString: Any], _ source: CGImageSource, _ url: URL) -> [InfoRow] {
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
