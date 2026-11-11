import CoreGraphics
import Foundation
import ImageIO
import PeekerKit
import UniformTypeIdentifiers

public enum ImagePlugin: Plugin {
    public static let id = "image"
    public static let name = "Image"
    public static let symbol = "photo"
    /// The common formats ImageIO decodes, and camera RAW. Not SVG: ImageIO can't draw it.
    public static let defaultExtensions = [
        "png", "jpg", "jpeg", "jpe", "heic", "heif", "hif", "avif", "gif", "tif", "tiff", "webp", "bmp", "ico", "icns",
        "jxl", "jp2", "psd", "exr",
        "dng", "cr2", "cr3", "crw", "nef", "nrw", "arw", "sr2", "srf", "raf", "orf", "rw2", "rwl", "pef", "srw", "erf",
        "raw", "3fr", "iiq",
    ]
    /// Everything ImageIO decodes.
    public static let readableTypes = (CGImageSourceCopyTypeIdentifiers() as? [String] ?? []).compactMap { UTType($0) }
    public static let tools =
        [
            ToolSpec(id: "zoom-in", title: "Zoom In", symbol: "plus.magnifyingglass", shortcut: "cmd+=", showsInToolbar: false),
            ToolSpec(id: "zoom-out", title: "Zoom Out", symbol: "minus.magnifyingglass", shortcut: "cmd+-", showsInToolbar: false),
            ToolSpec(
                id: "zoom-fit", title: "Zoom to Fit", symbol: "arrow.up.left.and.down.right.magnifyingglass", shortcut: "cmd+9", showsInToolbar: false
            ),
            ToolSpec(id: "zoom-actual", title: "Actual Size", symbol: "1.magnifyingglass", shortcut: "cmd+0", showsInToolbar: false),
            // Offered only for a multi-page TIFF.
            ToolSpec(id: "previous-page", title: "Previous Page", symbol: "chevron.up", shortcut: "pageup", showsInToolbar: false),
            ToolSpec(id: "next-page", title: "Next Page", symbol: "chevron.down", shortcut: "pagedown", showsInToolbar: false),
            ToolSpec(id: "play-animation", title: "Play Animation", symbol: "play", showsInToolbar: false),
            // A single key, kept for Crop alone: other letters stay free for markup tools.
            ToolSpec(id: "crop", title: "Crop", symbol: "crop", shortcut: "c", isEditTool: true, tip: "Drag a rectangle, then press Return."),
            ToolSpec(id: "transform", title: "Rotate & Resize", symbol: "rotate.right", isEditTool: true),
            ToolSpec(
                id: "markup", title: "Markup", symbol: "pencil.tip.crop.circle", shortcut: "m", isEditTool: true,
                tip: "Pick a tool, or press its key, then drag on the image. Hold Option for an ellipse or a text label."),
        ] + MarkupTool.allCases.map(\.spec)
    /// Larger decodes would be refused by Core Animation anyway.
    nonisolated static let maxDimension = 16_384

    public static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument {
        let decoded = try await decode(url, maxPixels: context.maxPixels)
        return ImageDocument(
            url: url, decoded: decoded, editable: context.allowsEditing, maxPixels: context.maxPixels,
            preferences: context.preferences)
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
        /// Print points per pixel: 72 over the file's resolution, or 1 when it states none.
        let pointsPerPixel: CGFloat
        /// The full image's size in pixels, upright.
        let pixelSize: CGSize
        let uneditableReason: String?
        /// Several frames in a format that animates them; a multi-page TIFF isn't.
        let isAnimated: Bool
        /// The TIFF pages the file has; 1 for every other image, whatever its frames.
        let pageCount: Int
        let info: [InfoRow]
    }

    nonisolated static let animatedTypes: Set<String> = [UTType.gif.identifier, UTType.png.identifier, UTType.webP.identifier, "public.heics"]

    /// Decodes the image, or the page of a multi-page TIFF, upright and at most `maxPixels` on its longer side, into
    /// premultiplied sRGB, the layout Core Animation draws without converting on the main thread.
    @concurrent nonisolated static func decode(_ url: URL, maxPixels: Int, page: Int = 0) async throws(PluginError) -> Decoded {
        try decodeNow(url, maxPixels: maxPixels, page: page)
    }

    /// `decode` on the calling thread, for the rare case that can't wait: recovered edits on the file as it opened.
    /// The first image at screen size and its full size upright, on the calling thread: for edits recovered against
    /// the file as it opened, kept in memory.
    nonisolated static func screenDecode(_ image: ImageSource, maxPixels: Int) throws(PluginError) -> (image: CGImage, pixelSize: CGSize) {
        let (source, properties) = try source(image, page: 0)
        let decoded = try displayDecode(source, page: 0, maxSide: min(maxPixels, maxDimension))
        let width = properties[kCGImagePropertyPixelWidth] as? Int ?? decoded.width
        let height = properties[kCGImagePropertyPixelHeight] as? Int ?? decoded.height
        let turned = (5...8).contains(properties[kCGImagePropertyOrientation] as? Int ?? 1)
        return (decoded, turned ? CGSize(width: height, height: width) : CGSize(width: width, height: height))
    }

    nonisolated static func decodeNow(_ url: URL, maxPixels: Int, page: Int = 0) throws(PluginError) -> Decoded {
        let (source, properties) = try source(url, page: page)
        let image = try displayDecode(source, page: page, maxSide: min(maxPixels, maxDimension))
        let width = properties[kCGImagePropertyPixelWidth] as? Int ?? image.width
        let height = properties[kCGImagePropertyPixelHeight] as? Int ?? image.height
        // Orientations 5 to 8 turn the image a quarter turn.
        let turned = (5...8).contains(properties[kCGImagePropertyOrientation] as? Int ?? 1)
        let type = CGImageSourceGetType(source).map { $0 as String } ?? ""
        let frames = CGImageSourceGetCount(source)
        let reason = uneditableReason(
            type: type, frames: frames, pixels: width * height, isFloat: properties[kCGImagePropertyIsFloat] as? Bool ?? false)
        return Decoded(
            image: image, pointsPerPixel: pointsPerPixel(properties),
            pixelSize: turned ? CGSize(width: height, height: width) : CGSize(width: width, height: height),
            uneditableReason: reason, isAnimated: frames > 1 && animatedTypes.contains(type),
            pageCount: pageCount(source), info: info(properties, source, url, page: page))
    }

    /// The image or page `pixelSize` large upright, decoded as `decode` does but at `fullSide(for:)`, for showing it
    /// zoomed in.
    @concurrent nonisolated static func decodeFull(_ url: URL, pixelSize: CGSize, page: Int = 0) async throws(PluginError) -> CGImage {
        try await decodeFull(.file(url), pixelSize: pixelSize, page: page)
    }

    @concurrent nonisolated static func decodeFull(_ image: ImageSource, pixelSize: CGSize, page: Int = 0) async throws(PluginError) -> CGImage {
        try displayDecode(try source(image, page: page).source, page: page, maxSide: fullSide(for: pixelSize))
    }

    /// A page as it prints: upright, decoded at screen size, with its size in points from its resolution.
    struct PrintPage {
        let image: CGImage
        let size: CGSize
    }

    /// Every page of the file, decoded at most `maxSide` on its longer side, for printing; pages that can't be decoded
    /// are left out.
    nonisolated static func printPages(_ url: URL, maxSide: Int) -> [PrintPage] {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else { return [] }
        return (0..<pageCount(source)).compactMap { page in
            guard let image = try? displayDecode(source, page: page, maxSide: min(maxSide, maxDimension)) else { return nil }
            let properties = CGImageSourceCopyPropertiesAtIndex(source, page, nil) as? [CFString: Any] ?? [:]
            let scale = pointsPerPixel(properties)
            let width = CGFloat(properties[kCGImagePropertyPixelWidth] as? Int ?? image.width)
            let height = CGFloat(properties[kCGImagePropertyPixelHeight] as? Int ?? image.height)
            let turned = (5...8).contains(properties[kCGImagePropertyOrientation] as? Int ?? 1)
            return PrintPage(
                image: image,
                size: turned ? CGSize(width: height * scale, height: width * scale) : CGSize(width: width * scale, height: height * scale))
        }
    }

    /// A small decode of a page, for its thumbnail; nil when it can't be decoded.
    @concurrent nonisolated static func thumbnail(_ url: URL, page: Int, maxSide: Int) async -> CGImage? {
        try? displayDecode(try source(url, page: page).source, page: page, maxSide: maxSide)
    }

    /// The pages of a multi-page TIFF; 1 for other images, whose extra frames are animation or sizes.
    private nonisolated static func pageCount(_ source: CGImageSource) -> Int {
        CGImageSourceGetType(source) as String? == UTType.tiff.identifier ? max(CGImageSourceGetCount(source), 1) : 1
    }

    /// The longer side of the full decode of an image `pixelSize` large: its own, at most `maxDimension`, and smaller
    /// still where needed to hold no more than `maxEditablePixels`.
    nonisolated static func fullSide(for pixelSize: CGSize) -> Int {
        let longer = max(pixelSize.width, pixelSize.height), shorter = max(min(pixelSize.width, pixelSize.height), 1)
        guard longer >= 1 else { return 1 }
        func pixels(_ side: Int) -> Int { side * Int((CGFloat(side) * shorter / longer).rounded(.up)) }
        var side = Int(min(longer, CGFloat(maxDimension)))
        if pixels(side) > maxEditablePixels { side = Int((CGFloat(maxEditablePixels) * longer / shorter).squareRoot()) }
        while pixels(side) > maxEditablePixels { side -= 1 }
        return side
    }

    /// The file's image source and the properties of its image at `page`.
    private nonisolated static func source(_ url: URL, page: Int) throws(PluginError) -> (source: CGImageSource, properties: [CFString: Any]) {
        try source(.file(url), page: page)
    }

    private nonisolated static func source(_ image: ImageSource, page: Int) throws(PluginError) -> (
        source: CGImageSource, properties: [CFString: Any]
    ) {
        guard let source = image.makeSource(), CGImageSourceGetCount(source) > page, page >= 0 else {
            throw PluginError("This file isn't a readable image.")
        }
        // Before the thumbnail: otherwise ImageIO ignores a PNG's orientation tag when the PNG has other EXIF too,
        // and the window would show it unturned while saving turns it.
        return (source, CGImageSourceCopyPropertiesAtIndex(source, page, nil) as? [CFString: Any] ?? [:])
    }

    /// The image at `page`, upright and at most `maxSide` on its longer side, in the layout `displayReady` gives.
    private nonisolated static func displayDecode(_ source: CGImageSource, page: Int, maxSide: Int) throws(PluginError) -> CGImage {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSide,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, page, options as CFDictionary) else {
            throw PluginError("This image couldn't be decoded.")
        }
        if Task.isCancelled { throw PluginError.cancelled }
        return try displayReady(thumbnail)
    }

    /// The info rows for the file, or a page of it, as it is now, such as after a save.
    @concurrent nonisolated static func info(of url: URL, page: Int = 0) async -> [InfoRow] {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else { return [] }
        return info(CGImageSourceCopyPropertiesAtIndex(source, page, nil) as? [CFString: Any] ?? [:], source, url, page: page)
    }

    /// Takes pixels as square, as nearly every image's are, so the horizontal resolution holds both ways.
    private nonisolated static func pointsPerPixel(_ properties: [CFString: Any]) -> CGFloat {
        guard let dpi = properties[kCGImagePropertyDPIWidth] as? Double, dpi > 0, dpi.isFinite else { return 1 }
        return 72 / dpi
    }

    private nonisolated static func displayReady(_ image: CGImage) throws(PluginError) -> CGImage {
        let info = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        guard
            let context = CGContext(
                data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: info)
        else {
            throw PluginError("This image couldn't be decoded.")
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let converted = context.makeImage() else { throw PluginError("This image couldn't be decoded.") }
        return converted
    }

    private nonisolated static func info(_ properties: [CFString: Any], _ source: CGImageSource, _ url: URL, page: Int) -> [InfoRow] {
        var rows: [InfoRow] = []
        let pages = pageCount(source)
        if pages > 1 { rows.append(InfoRow(label: "Page", value: "\(page + 1) of \(pages)")) }
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

/// Where an image's bytes come from: its file, or a copy in memory of the file as it opened.
nonisolated enum ImageSource: Sendable {
    case file(URL)
    case bytes(Data)

    func makeSource() -> CGImageSource? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        return switch self {
        case .file(let url): CGImageSourceCreateWithURL(url as CFURL, options)
        case .bytes(let data): CGImageSourceCreateWithData(data as CFData, options)
        }
    }
}
