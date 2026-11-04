import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Finds the images a Markdown file names on this Mac and checks each is a picture worth showing.
nonisolated enum MarkdownImages {
    /// The local file `source` names, read against the Markdown file's folder, or nil when it isn't a local path.
    /// Only `file:` URLs on this Mac count, so nothing is ever fetched; a query or fragment is dropped, and `~` stays
    /// literal, as in a browser.
    static func resolve(_ source: String, in folder: URL) -> URL? {
        guard !source.isEmpty else { return nil }
        let url = URL(string: source, relativeTo: folder) ?? folder.appending(path: source)
        guard url.scheme?.lowercased() == "file", ["", "localhost"].contains(url.host()?.lowercased() ?? "") else { return nil }
        return URL(filePath: url.absoluteURL.standardized.path(percentEncoded: false))
    }

    static let maxBytes = 20 * 1_048_576
    static let maxPixels = 50_000_000

    /// The picture at `url`, or nil when it's missing, not a regular file, too large, an iCloud file not downloaded
    /// yet, or not an image the system can read. Reads the file's header, not its pixels.
    static func check(_ url: URL) -> LocalImage? {
        let file = url.resolvingSymlinksInPath()
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey, .isUbiquitousItemKey,
                                         .ubiquitousItemDownloadingStatusKey]
        // A regular file only, so a FIFO or a device can't block the read; an iCloud file only once downloaded, so
        // nothing starts a download.
        guard let values = try? file.resourceValues(forKeys: keys), values.isRegularFile == true, (values.fileSize ?? .max) <= maxBytes,
              values.isUbiquitousItem != true || values.ubiquitousItemDownloadingStatus == .current,
              let source = CGImageSourceCreateWithURL(file as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let type = CGImageSourceGetType(source).flatMap({ UTType($0 as String) }), type.conforms(to: .image),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int, let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, width * height <= maxPixels else { return nil }
        let turned = (5...8).contains(properties[kCGImagePropertyOrientation] as? Int ?? 1)
        return LocalImage(url: url, pixelSize: turned ? CGSize(width: height, height: width) : CGSize(width: width, height: height),
                          modified: values.contentModificationDate)
    }

    static let maxImages = 50

    /// The usable pictures in `blocks`, by their source as written, numbered in document order. Each source is
    /// checked once; images in table cells are skipped, and looking stops after `maxImages`.
    static func find(in blocks: [MarkdownBlock], folder: URL, check: (URL) -> LocalImage? = check) -> [String: LocalImage] {
        var found: [String: LocalImage] = [:]
        var seen: Set<String> = []
        func visit(_ spans: [Span]) {
            for span in spans where span.style.contains(.image) && found.count < maxImages {
                guard let source = span.link, seen.insert(source).inserted,
                      let url = resolve(source, in: folder), var image = check(url) else { continue }
                image.order = found.count
                found[source] = image
            }
        }
        func visit(_ blocks: [MarkdownBlock]) {
            for block in blocks {
                switch block {
                case .heading(_, let spans, _), .paragraph(let spans): visit(spans)
                case .list(_, _, let items): for item in items { visit(item.blocks) }
                case .quote(let children): visit(children)
                case .code, .rule, .table: break
                }
            }
        }
        visit(blocks)
        return found
    }

    static let maxDecodePixels = 4096

    /// The longest side, in pixels, to decode `image` at: its drawn size in a line `width` points wide on a screen of
    /// `scale`, never more than its own longest side or `maxDecodePixels`.
    static func decodePixels(for image: LocalImage, width: CGFloat, scale: CGFloat) -> Int {
        let size = image.pixelSize
        let drawn = min(size.width, max(width, 1))
        let longest = max(drawn, drawn * size.height / size.width) * scale
        return max(1, min(Int(longest.rounded(.up)), Int(max(size.width, size.height)), maxDecodePixels))
    }

    /// `image` decoded upright, at most `maxPixels` on its longest side; nil when the file no longer passes the check
    /// (it changed since) or its data is damaged.
    static func decode(_ image: LocalImage, maxPixels: Int) -> CGImage? {
        guard check(image.url) != nil,
              let source = CGImageSourceCreateWithURL(image.url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// `decode`, off the main thread.
    @concurrent static func decoded(_ image: LocalImage, maxPixels: Int) async -> CGImage? {
        decode(image, maxPixels: maxPixels)
    }
}

/// A picture on this Mac that a Markdown file names, checked from its file's header.
nonisolated struct LocalImage: Sendable, Equatable {
    let url: URL
    /// Upright: turned for EXIF orientations 5 to 8.
    let pixelSize: CGSize
    let modified: Date?
    /// Where it first appears among the document's pictures, so they decode top to bottom.
    var order = 0
}
