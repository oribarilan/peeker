import AppKit

/// Shows pixels a plugin already decoded. The host only maps memory; it never parses image files.
final class BitmapComponent: Component {
    private let scrollView = NSScrollView()

    init(bitmap: SharedBitmap) throws(PluginFailure) {
        let image = try SharedBitmapReader.image(from: bitmap)
        let imageView = LayerImageView(image: image)
        scrollView.documentView = imageView
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 1
        scrollView.maxMagnification = 16
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.drawsBackground = false
        imageView.autoresizingMask = [.width, .height]
    }

    var view: NSView { scrollView }

    func perform(_ verb: String) -> Bool {
        switch verb {
        case "zoom-in": scrollView.magnification *= 1.25
        case "zoom-out": scrollView.magnification /= 1.25
        case "zoom-fit": scrollView.magnification = 1
        default: return false
        }
        return true
    }

    private final class LayerImageView: NSView {
        init(image: CGImage) {
            super.init(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
            wantsLayer = true
            layer?.contents = image
            layer?.contentsGravity = .resizeAspect
        }

        required init?(coder: NSCoder) { fatalError("not used") }

        override func viewDidMoveToSuperview() {
            super.viewDidMoveToSuperview()
            if let clip = superview { frame = clip.bounds }
        }
    }
}

enum SharedBitmapReader {
    /// Maps the plugin's bitmap file without copying pixels, after checking that the plugin's numbers can't make the
    /// host read out of bounds. The image keeps the mapping alive.
    static func image(from bitmap: SharedBitmap) throws(PluginFailure) -> CGImage {
        let width = bitmap.width, height = bitmap.height, bytesPerRow = bitmap.bytesPerRow
        guard (1...SharedBitmap.maxDimension).contains(width), (1...SharedBitmap.maxDimension).contains(height),
              bytesPerRow >= width * 4, bytesPerRow <= width * 4 + 64, bitmap.file.byteCount >= bytesPerRow * height else {
            SharedFile.discard(bitmap.file)
            throw PluginFailure("bitmap dimensions are invalid")
        }
        let mapped = try SharedFile.map(bitmap.file)
        let retained = Unmanaged.passRetained(mapped)
        guard let base = mapped.bytes.baseAddress,
              let provider = CGDataProvider(dataInfo: retained.toOpaque(), data: base, size: bytesPerRow * height, releaseData: { info, _, _ in
                  info.map { Unmanaged<MappedFile>.fromOpaque($0).release() }
              }) else {
            retained.release()
            throw PluginFailure("could not wrap bitmap")
        }
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        guard let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: bitmapInfo, provider: provider,
                                  decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { throw PluginFailure("could not create bitmap image") }
        return image
    }
}
