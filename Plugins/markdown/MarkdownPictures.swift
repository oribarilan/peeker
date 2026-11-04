import AppKit

/// Decodes a rendered Markdown document's pictures in the background, one at a time from the top, at the size
/// they're drawn, and fills them into its text. Decoded pictures are kept, so a new render of the same document
/// (a theme change, a reload) shows them at once.
final class MarkdownPictures {
    private struct Key: Hashable {
        let url: URL
        let modified: Date?
        init(_ image: LocalImage) { (url, modified) = (image.url, image.modified) }
    }

    private weak var textView: NSTextView?
    private var decoded: [Key: CGImage] = [:]
    private var failed: Set<Key> = []
    private(set) var task: Task<Void, Never>?
    /// Pictures decoded so far, for tests.
    private(set) var decodes = 0
    /// Called with the location and the change in length when a picture that failed to decode turns back into its
    /// alt text.
    var onFallback: ((_ location: Int, _ delta: Int) -> Void)?

    init(textView: NSTextView) {
        self.textView = textView
    }

    /// `images` without those that failed to decode, which show their alt text instead.
    func usable(_ images: [String: LocalImage]) -> [String: LocalImage] {
        failed.isEmpty ? images : images.filter { !failed.contains(Key($0.value)) }
    }

    /// Fills the text's pictures from those already decoded, then decodes the rest in document order. Stops the
    /// decoding a previous call started.
    func start(_ images: [String: LocalImage]) {
        cancel()
        guard !images.isEmpty else { return }
        let keys = Set(images.values.map(Key.init))
        decoded = decoded.filter { keys.contains($0.key) }
        failed.formIntersection(keys)
        fill()
        var queued: Set<Key> = []
        let pending = images.values.sorted { $0.order < $1.order }.filter {
            let key = Key($0)
            return decoded[key] == nil && !failed.contains(key) && queued.insert(key).inserted
        }
        guard !pending.isEmpty else { return }
        // Holds this object weakly, so closing the document ends the loop before the next picture.
        task = Task { [weak self] in
            for image in pending {
                guard !Task.isCancelled, let pixels = self?.decodePixels(for: image) else { return }
                let picture = await MarkdownImages.decoded(image, maxPixels: pixels)
                guard !Task.isCancelled, let self else { return }
                if let picture {
                    decoded[Key(image)] = picture
                    decodes += 1
                } else {
                    failed.insert(Key(image))
                }
                fill()
            }
        }
    }

    /// `blocks` rendered for print in the system colors, with their pictures decoded now at twice the size they're
    /// printed: the print job has to be built synchronously. A picture that fails to decode prints its alt text.
    static func printText(_ blocks: [MarkdownBlock], folder: URL, info: NSPrintInfo) -> NSAttributedString {
        let width = info.paperSize.width - info.leftMargin - info.rightMargin
        var images = MarkdownImages.find(in: blocks, folder: folder)
        var decoded: [URL: CGImage] = [:]
        for image in images.values where decoded[image.url] == nil {
            decoded[image.url] = MarkdownImages.decode(image, maxPixels: MarkdownImages.decodePixels(for: image, width: width, scale: 2))
        }
        images = images.filter { decoded[$0.value.url] != nil }
        let text = MarkdownRenderer.render(blocks, theme: .system, images: images).text
        text.enumerateAttribute(.attachment, in: NSRange(location: 0, length: text.length)) { value, _, _ in
            guard let attachment = value as? MarkdownImageAttachment, let picture = decoded[attachment.local.url] else { return }
            attachment.show(decoded: picture)
        }
        return text
    }

    func cancel() {
        task?.cancel()
    }

    /// The text width when the decode starts, or the picture's own size while the view has no width yet.
    private func decodePixels(for image: LocalImage) -> Int {
        let container = textView?.textContainer
        let width = (container?.size.width ?? 0) - 2 * (container?.lineFragmentPadding ?? 0)
        let scale = textView?.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        return MarkdownImages.decodePixels(for: image, width: width > 0 ? width : image.pixelSize.width, scale: scale)
    }

    /// Puts each decoded picture into its attachments, keeping their bounds so no text moves, and turns pictures that
    /// failed back into their alt text.
    func fill() {
        guard let storage = textView?.textStorage, !decoded.isEmpty || !failed.isEmpty else { return }
        var fallbacks: [(range: NSRange, alt: String)] = []
        storage.beginEditing()
        storage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: storage.length)) { value, range, _ in
            guard let attachment = value as? MarkdownImageAttachment, !attachment.isDecoded else { return }
            let key = Key(attachment.local)
            if failed.contains(key) { return fallbacks.append((range, attachment.alt)) }
            guard let picture = decoded[key] else { return }
            attachment.show(decoded: picture)
            storage.edited(.editedAttributes, range: range, changeInLength: 0)  // redraws it
        }
        for (range, alt) in fallbacks.reversed() {
            var attributes = storage.attributes(at: range.location, effectiveRange: nil)
            attributes[.attachment] = nil
            let text = NSAttributedString(string: "[\(alt)]", attributes: attributes)
            storage.replaceCharacters(in: range, with: text)
            onFallback?(range.location, text.length - range.length)
        }
        storage.endEditing()
    }
}
