import CoreGraphics
import Foundation
import ImageIO
import PeekerKit
import UniformTypeIdentifiers

/// Writes image edits into the file at full resolution, in its own format, keeping its metadata.
nonisolated enum ImageSaving {
    static let lossyQuality = 0.9
    private static let lossy: Set<String> = [UTType.jpeg.identifier, UTType.heic.identifier, "public.avif"]
    /// Formats whose orientation tag apps read, where turning the image can leave its data untouched.
    private static let orientable: Set<String> = [UTType.jpeg.identifier, UTType.heic.identifier, UTType.heif.identifier, UTType.tiff.identifier]

    /// Applies `edits` to the file at `path` and replaces it. Writes nothing on failure.
    @concurrent static func save(_ edits: [ImageEdit], to path: String) async throws(PluginError) {
        let name = URL(filePath: path).lastPathComponent
        guard let source = CGImageSourceCreateWithURL(URL(filePath: path) as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let type = CGImageSourceGetType(source), CGImageSourceGetCount(source) > 0 else {
            throw PluginError("“\(name)” is no longer a readable image.")
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
        let orientation = (properties[kCGImagePropertyOrientation] as? Int).flatMap(Orientation.init) ?? .up
        var data: Data?
        if edits.allSatisfy(\.isOrientationOnly), orientable.contains(type as String) {
            data = reoriented(source, type: type, to: edits.reduce(orientation) { $0.then($1) })
        }
        if data == nil {
            data = redrawn(source, type: type, properties: properties, edits: orientation.uprightEdits + edits)
        }
        guard let data else { throw PluginError("“\(name)” couldn't be saved as \(UTType(type as String)?.localizedDescription ?? "an image").") }
        try FileReplacement.replaceContents(ofFileAt: path, with: data)
    }

    /// The same image data with a new orientation tag.
    private static func reoriented(_ source: CGImageSource, type: CFString, to orientation: Orientation) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, type, 1, nil) else { return nil }
        let options: [CFString: Any] = [kCGImageDestinationOrientation: orientation.rawValue, kCGImageDestinationMergeMetadata: true]
        return CGImageDestinationCopyImageSource(destination, source, options as CFDictionary, nil) ? data as Data : nil
    }

    /// The full image turned upright, edited, and written with its metadata, orientation 1 and its new size.
    private static func redrawn(_ source: CGImageSource, type: CFString, properties: [CFString: Any], edits: [ImageEdit]) -> Data? {
        guard let full = CGImageSourceCreateImageAtIndex(source, 0, nil), let image = ImageEditing.apply(edits, to: full) else { return nil }
        var written = properties
        for key in [kCGImagePropertyPixelWidth, kCGImagePropertyPixelHeight, kCGImagePropertyDepth] { written[key] = nil }
        written[kCGImagePropertyOrientation] = 1
        if var tiff = written[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            tiff[kCGImagePropertyTIFFOrientation] = 1
            written[kCGImagePropertyTIFFDictionary] = tiff
        }
        if var exif = written[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            exif[kCGImagePropertyExifPixelXDimension] = image.width
            exif[kCGImagePropertyExifPixelYDimension] = image.height
            written[kCGImagePropertyExifDictionary] = exif
        }
        written[kCGImageDestinationEmbedThumbnail] = false
        if lossy.contains(type as String) { written[kCGImageDestinationLossyCompressionQuality] = lossyQuality }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, type, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, written as CFDictionary)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }
}

/// An EXIF orientation: how the stored image is turned and mirrored to be shown. As a matrix on (x, y) with y down,
/// so edits compose by multiplying.
nonisolated enum Orientation: Int {
    case up = 1, mirrored, upsideDown, mirroredUpsideDown, transposed, right, transverse, left

    private var matrix: (Int, Int, Int, Int) {
        switch self {
        case .up: (1, 0, 0, 1)
        case .mirrored: (-1, 0, 0, 1)
        case .upsideDown: (-1, 0, 0, -1)
        case .mirroredUpsideDown: (1, 0, 0, -1)
        case .transposed: (0, 1, 1, 0)
        case .right: (0, -1, 1, 0)
        case .transverse: (0, -1, -1, 0)
        case .left: (0, 1, -1, 0)
        }
    }

    /// The orientation after `edit` turns or mirrors the image as shown.
    func then(_ edit: ImageEdit) -> Orientation {
        let e: (Int, Int, Int, Int) = switch edit {
        case .rotate(let by): by > 0 ? Orientation.right.matrix : Orientation.left.matrix
        case .flip(let horizontal): horizontal ? Orientation.mirrored.matrix : Orientation.mirroredUpsideDown.matrix
        case .crop, .resize: Orientation.up.matrix
        }
        let m = matrix
        let product = (e.0 * m.0 + e.1 * m.2, e.0 * m.1 + e.1 * m.3, e.2 * m.0 + e.3 * m.2, e.2 * m.1 + e.3 * m.3)
        return Self.allCases.first { $0.matrix == product } ?? .up
    }

    /// The edits that turn the stored image as this orientation shows it.
    var uprightEdits: [ImageEdit] {
        switch self {
        case .up: []
        case .mirrored: [.flip(horizontal: true)]
        case .upsideDown: [.rotate(by: 90), .rotate(by: 90)]
        case .mirroredUpsideDown: [.flip(horizontal: false)]
        case .transposed: [.rotate(by: 90), .flip(horizontal: true)]
        case .right: [.rotate(by: 90)]
        case .transverse: [.flip(horizontal: true), .rotate(by: 90)]
        case .left: [.rotate(by: -90)]
        }
    }
}

extension Orientation: CaseIterable {}
