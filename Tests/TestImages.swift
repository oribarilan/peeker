import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

/// A `width`×`height` sRGB image with a colored square in each corner: red top left, green top right, blue bottom
/// left, white bottom right, the rest black.
func cornerImage(width: Int = 40, height: Int = 20, bits: Int = 8) throws -> CGImage {
    let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: bits, bytesPerRow: 0,
                                         space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(gray: 0, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let s = 4
    for (x, y, r, g, b) in [(0, height - s, 1.0, 0.0, 0.0), (width - s, height - s, 0, 1, 0), (0, 0, 0, 0, 1), (width - s, 0, 1, 1, 1)] {
        context.setFillColor(red: r, green: g, blue: b, alpha: 1)
        context.fill(CGRect(x: x, y: y, width: s, height: s))
    }
    return try #require(context.makeImage())
}

/// The color names in the four corners: top left, top right, bottom left, bottom right.
func corners(_ image: CGImage) throws -> [String] {
    let w = image.width, h = image.height
    let context = try #require(CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                         space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    let data = try #require(context.data).bindMemory(to: UInt8.self, capacity: w * h * 4)
    func name(_ x: Int, _ y: Int) -> String {  // y from the top
        let p = data + (y * w + x) * 4
        switch (p[0] > 128, p[1] > 128, p[2] > 128) {
        case (true, false, false): return "red"
        case (false, true, false): return "green"
        case (false, false, true): return "blue"
        case (true, true, true): return "white"
        default: return "black"
        }
    }
    return [name(1, 1), name(w - 2, 1), name(1, h - 2), name(w - 2, h - 2)]
}

/// Writes `image` to a new file of `type` with optional properties (orientation, EXIF).
func imageFile(_ image: CGImage, type: UTType, properties: [CFString: Any] = [:]) throws -> URL {
    let url = try TempFile.make(Data(), name: "f." + (type.preferredFilenameExtension ?? "img"))
    let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, properties as CFDictionary)
    #expect(CGImageDestinationFinalize(destination))
    return url
}

/// The stored image (orientation not applied) and the properties of the file at `url`.
func stored(_ url: URL) throws -> (image: CGImage, properties: [CFString: Any], type: String) {
    let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
    let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
    return (image, properties, CGImageSourceGetType(source) as String? ?? "")
}
