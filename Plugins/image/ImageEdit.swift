import CoreGraphics
import Foundation

/// One change to an image. A list of them applies in order, each to the image as the ones before left it.
nonisolated enum ImageEdit: Codable, Sendable, Equatable {
    /// A quarter turn: 90 is clockwise, -90 counterclockwise.
    case rotate(by: Int)
    case flip(horizontal: Bool)
    /// The part to keep, as fractions of the width and height, measured from the top left.
    case crop(CGRect)
    case resize(width: Int, height: Int)

    /// The longest side a resize may ask for.
    static let maxSide = 32_768

    /// Changes only which way the image faces, so saving can rewrite the orientation tag alone.
    var isOrientationOnly: Bool {
        switch self {
        case .rotate, .flip: true
        case .crop, .resize: false
        }
    }

    /// Within bounds; recovered edits come from a file.
    var isValid: Bool {
        switch self {
        case .rotate(let by): by == 90 || by == -90
        case .flip: true
        case .crop(let rect):
            [rect.minX, rect.minY, rect.width, rect.height].allSatisfy(\.isFinite) && rect.width > 0 && rect.height > 0
                && rect.minX >= 0 && rect.minY >= 0 && rect.maxX <= 1.000_001 && rect.maxY <= 1.000_001
        case .resize(let width, let height):
            (1...Self.maxSide).contains(width) && (1...Self.maxSide).contains(height) && width * height <= ImagePlugin.maxEditablePixels
        }
    }
}

/// Applies image edits to pixels, keeping the image's bit depth and color space where a bitmap context can.
nonisolated enum ImageEditing {
    /// The pixel size after `edits`, starting from `size`.
    static func size(after edits: [ImageEdit], from size: CGSize) -> CGSize {
        edits.reduce(size) { size, edit in
            switch edit {
            case .rotate: CGSize(width: size.height, height: size.width)
            case .flip: size
            case .crop(let rect): cropRect(rect, in: size).size
            case .resize(let width, let height): CGSize(width: width, height: height)
            }
        }
    }

    /// `edits`, made to the full image of `fullSize`, applied to `decode`, a smaller decode of it for the screen. A resize
    /// scales the decode by the same factor as the full image, but never past the decode's own size: enlarging only
    /// shows as the same picture, and stays cheap. An edit that can't be drawn is skipped.
    static func preview(_ edits: [ImageEdit], of decode: CGImage, fullSize: CGSize) -> CGImage {
        var image = decode
        var full = fullSize
        for edit in edits {
            var shown = edit
            if case .resize(let width, let height) = edit, full.width > 0, full.height > 0 {
                var size = CGSize(width: CGFloat(image.width) * CGFloat(width) / full.width, height: CGFloat(image.height) * CGFloat(height) / full.height)
                let limit = CGFloat(max(decode.width, decode.height)) / max(size.width, size.height)
                if limit < 1 { size = CGSize(width: size.width * limit, height: size.height * limit) }
                shown = .resize(width: max(Int(size.width.rounded()), 1), height: max(Int(size.height.rounded()), 1))
            }
            image = apply(shown, to: image) ?? image
            full = size(after: [edit], from: full)
        }
        return image
    }

    static func apply(_ edits: [ImageEdit], to image: CGImage) -> CGImage? {
        edits.reduce(Optional(image)) { image, edit in image.flatMap { apply(edit, to: $0) } }
    }

    static func apply(_ edit: ImageEdit, to image: CGImage) -> CGImage? {
        let w = CGFloat(image.width), h = CGFloat(image.height)
        switch edit {
        case .crop(let rect):
            return image.cropping(to: cropRect(rect, in: CGSize(width: w, height: h)))
        case .rotate(let by):
            // Clockwise maps (x, y) to (y, w - x) with y up; counterclockwise to (h - y, x).
            let turn = by > 0 ? CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: w) : CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: h, ty: 0)
            return redraw(image, size: CGSize(width: h, height: w), transform: turn)
        case .flip(let horizontal):
            let mirror = horizontal ? CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: w, ty: 0) : CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: h)
            return redraw(image, size: CGSize(width: w, height: h), transform: mirror)
        case .resize(let width, let height):
            let scale = CGAffineTransform(scaleX: CGFloat(width) / w, y: CGFloat(height) / h)
            return redraw(image, size: CGSize(width: width, height: height), transform: scale)
        }
    }

    /// The crop in pixels, from the top left, rounded to whole pixels and at least one pixel.
    static func cropRect(_ rect: CGRect, in size: CGSize) -> CGRect {
        let x = min((rect.minX * size.width).rounded(), size.width - 1), y = min((rect.minY * size.height).rounded(), size.height - 1)
        let maxX = min((rect.maxX * size.width).rounded(), size.width), maxY = min((rect.maxY * size.height).rounded(), size.height)
        return CGRect(x: x, y: y, width: max(maxX - x, 1), height: max(maxY - y, 1))
    }

    private static func redraw(_ image: CGImage, size: CGSize, transform: CGAffineTransform) -> CGImage? {
        guard let context = context(like: image, width: Int(size.width), height: Int(size.height)) else { return nil }
        context.interpolationQuality = .high
        context.concatenate(transform)
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return context.makeImage()
    }

    /// A bitmap context as close to `image` as Core Graphics allows: its color space and 8 or 16 bits per channel,
    /// with alpha only when it has alpha.
    private static func context(like image: CGImage, width: Int, height: Int) -> CGContext? {
        let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
        let bits = image.bitsPerComponent > 8 ? 16 : 8
        let hasAlpha = ![.none, .noneSkipFirst, .noneSkipLast].contains(image.alphaInfo)
        let space = image.colorSpace.flatMap { $0.model == .rgb || ($0.model == .monochrome && !hasAlpha) ? $0 : nil } ?? srgb
        let alpha: CGImageAlphaInfo = space.model == .monochrome ? .none : hasAlpha ? .premultipliedLast : .noneSkipLast
        return CGContext(data: nil, width: width, height: height, bitsPerComponent: bits, bytesPerRow: 0, space: space, bitmapInfo: alpha.rawValue)
            ?? CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: srgb,
                         bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    }
}
