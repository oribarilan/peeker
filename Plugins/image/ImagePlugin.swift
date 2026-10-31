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
        CommandSpec(id: "zoom-actual", title: "Actual Size", symbol: "1.magnifyingglass", shortcut: "cmd+0"),
        // A single key, kept for Crop alone: other letters stay free for markup tools.
        CommandSpec(id: "crop", title: "Crop", symbol: "crop", shortcut: "c", isEditTool: true),
        CommandSpec(id: "transform", title: "Rotate & Resize", symbol: "rotate.right", shortcut: "cmd+r", isEditTool: true),
    ]
    /// Larger decodes would be refused by Core Animation anyway.
    nonisolated static let maxDimension = 16_384

    public static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument {
        let decoded = try await decode(url, maxPixels: context.maxPixels)
        return ImageDocument(url: url, decoded: decoded, editable: context.allowsEditing)
    }

    /// Formats ImageIO writes without losing what Peeker shows: no layers, no floating point, no camera RAW.
    nonisolated static let editableTypes: Set<String> = [
        UTType.jpeg.identifier, UTType.png.identifier, UTType.gif.identifier, UTType.tiff.identifier, UTType.heic.identifier,
        "public.avif", UTType.bmp.identifier, "public.jpeg-2000",
    ]
    /// Above this the full decode and a working copy could take more than a gigabyte.
    nonisolated static let maxEditablePixels = 100_000_000

    /// Why an image can't be edited, or nil when it can.
    nonisolated static func uneditableReason(type: String, frames: Int, pixels: Int, isFloat: Bool) -> String? {
        if !editableTypes.contains(type) || isFloat { return "Peeker can't save this format." }
        if frames > 1 { return "This image has several frames." }
        if pixels > maxEditablePixels { return "This image is too large to edit." }
        return nil
    }

    struct Decoded: Sendable {
        let image: CGImage
        /// The full image's size in points, upright: pixels at its resolution, or 72 per inch when it states none.
        let printSize: CGSize
        /// The full image's size in pixels, upright.
        let pixelSize: CGSize
        let uneditableReason: String?
        /// Several frames in a format that animates them; a multi-page TIFF isn't.
        let isAnimated: Bool
        let info: [InfoRow]
    }

    nonisolated static let animatedTypes: Set<String> = [UTType.gif.identifier, UTType.png.identifier, UTType.webP.identifier, "public.heics"]

    /// Decodes the first image, upright and at most `maxPixels` on its longer side, into premultiplied sRGB, the
    /// layout Core Animation draws without converting on the main thread.
    @concurrent nonisolated static func decode(_ url: URL, maxPixels: Int) async throws(PluginError) -> Decoded {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(source) > 0 else { throw PluginError("This file isn't a readable image.") }
        // Before the thumbnail: otherwise ImageIO ignores a PNG's orientation tag when the PNG has other EXIF too,
        // and the window would show it unturned while saving turns it.
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
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
        let printSize = printSize(properties, decoded: thumbnail)
        let width = properties[kCGImagePropertyPixelWidth] as? Int ?? thumbnail.width
        let height = properties[kCGImagePropertyPixelHeight] as? Int ?? thumbnail.height
        let turned = (5...8).contains(properties[kCGImagePropertyOrientation] as? Int ?? 1)
        let reason = uneditableReason(type: CGImageSourceGetType(source).map { $0 as String } ?? "", frames: CGImageSourceGetCount(source),
                                      pixels: width * height, isFloat: properties[kCGImagePropertyIsFloat] as? Bool ?? false)
        return Decoded(image: try displayReady(thumbnail), printSize: printSize,
                       pixelSize: turned ? CGSize(width: height, height: width) : CGSize(width: width, height: height),
                       uneditableReason: reason,
                       isAnimated: CGImageSourceGetCount(source) > 1 && animatedTypes.contains(CGImageSourceGetType(source).map { $0 as String } ?? ""),
                       info: info(properties, source, url))
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
