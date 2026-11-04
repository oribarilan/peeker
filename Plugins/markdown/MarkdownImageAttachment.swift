import AppKit

/// A local picture in rendered Markdown. Its size is known before its pixels are decoded, so the text around it is
/// laid out once: it starts with a transparent image of that size (an attachment with no image can draw a generic
/// icon) and takes the decoded picture later without moving anything.
nonisolated final class MarkdownImageAttachment: NSTextAttachment {
    let local: LocalImage
    let alt: String

    init(_ local: LocalImage, alt: String) {
        self.local = local
        self.alt = alt
        super.init(data: nil, ofType: nil)
        show(NSImage(size: local.pixelSize, flipped: false) { _ in true })
    }

    required init?(coder: NSCoder) { nil }

    /// As wide as the line at most and never more than one point per pixel, keeping the proportions, so the picture
    /// refits when the text width changes.
    func bounds(fitting width: CGFloat) -> CGRect {
        let size = local.pixelSize
        let fitted = min(size.width, max(width, 1))
        return CGRect(x: 0, y: 0, width: fitted, height: fitted * size.height / size.width)
    }

    /// TextKit 2, as in the Peek panel. The proposed line leaves out the padding but not a list's or quote's indent.
    override func attachmentBounds(for attributes: [NSAttributedString.Key: Any], location: any NSTextLocation, textContainer: NSTextContainer?,
                                   proposedLineFragment: CGRect, position: CGPoint) -> CGRect {
        bounds(fitting: proposedLineFragment.width - Self.indent(attributes[.paragraphStyle]))
    }

    /// TextKit 1, as in printing. The proposed line includes the padding on both sides, and the indent.
    override func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: NSRect, glyphPosition position: NSPoint,
                                   characterIndex charIndex: Int) -> NSRect {
        let storage = textContainer?.layoutManager?.textStorage
        let style = charIndex < storage?.length ?? 0 ? storage?.attribute(.paragraphStyle, at: charIndex, effectiveRange: nil) : nil
        return bounds(fitting: lineFrag.width - 2 * (textContainer?.lineFragmentPadding ?? 0) - Self.indent(style))
    }

    private static func indent(_ style: Any?) -> CGFloat {
        (style as? NSParagraphStyle)?.headIndent ?? 0
    }

    private(set) var isDecoded = false

    /// Shows the decoded picture in place of the transparent stand-in.
    func show(decoded picture: CGImage) {
        show(NSImage(cgImage: picture, size: local.pixelSize))
        isDecoded = true
    }

    /// With the alt text for VoiceOver.
    private func show(_ picture: NSImage) {
        picture.accessibilityDescription = alt
        image = picture
    }
}
