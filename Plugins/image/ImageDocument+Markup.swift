import AppKit
import PeekerKit

/// The image's scroll view filling the content area, and the markup strip, when it shows, under the toolbar with the
/// image below it. Laid out with frames, so a resize applies at once.
final class MarkupContainer: NSView {
    var image: NSView? {
        didSet {
            oldValue?.removeFromSuperview()
            image.map { addSubview($0) }
            resizeSubviews(withOldSize: bounds.size)
        }
    }
    var strip: NSView? {
        didSet {
            oldValue?.removeFromSuperview()
            strip.map { addSubview($0) }
            resizeSubviews(withOldSize: bounds.size)
        }
    }

    override var isFlipped: Bool { true }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        guard let strip, !strip.isHidden else {
            image?.frame = bounds
            return
        }
        let top = safeAreaInsets.top, height = strip.fittingSize.height
        strip.frame = NSRect(x: 0, y: top, width: bounds.width, height: height)
        image?.frame = NSRect(x: 0, y: top + height, width: bounds.width, height: max(bounds.height - top - height, 0))
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        resizeSubviews(withOldSize: bounds.size)
    }
}

/// Markup: the strip under the toolbar, the overlay over the image, the remembered style, and Copy and Paste.
extension ImageDocument {
    static let markPasteboardType = NSPasteboard.PasteboardType("dev.peeker.image-mark")

    var isMarkingUp: Bool { strip.map { !$0.isHidden } ?? false }

    /// The remembered color and size, or red and medium when there's none or it doesn't read.
    static func markupStyle(in preferences: PluginPreferences?) -> (RGBA, MarkSize) {
        let size = preferences?.string("markupSize").flatMap(MarkSize.init(rawValue:)) ?? .medium
        guard let hex = preferences?.string("markupColor"), hex.count == 6, let value = UInt32(hex, radix: 16) else { return (markupPalette[0].color, size) }
        // A swatch comes back as itself, so it shows as chosen.
        if let swatch = markupPalette.first(where: { Self.hex($0.color) == hex.uppercased() }) { return (swatch.color, size) }
        let channel = { (shift: UInt32) in Double((value >> shift) & 0xFF) / 255 }
        return (RGBA(red: channel(16), green: channel(8), blue: channel(0), alpha: 1), size)
    }

    static func hex(_ color: RGBA) -> String {
        [color.red, color.green, color.blue].map { String(format: "%02X", Int(($0 * 255).rounded())) }.joined()
    }

    func showMarkup() {
        guard isEditing else { return }
        let strip = strip ?? makeStrip()
        strip.isHidden = false
        container.resizeSubviews(withOldSize: container.bounds.size)
        let overlay = overlay ?? makeOverlay()
        if overlay.superview == nil { canvas.addSubview(overlay) }
        canvas.window?.makeFirstResponder(overlay)
        showStyle()
        onActiveToolChange?()
    }

    func hideMarkup() {
        guard isMarkingUp, let strip else { return }
        overlay?.endTextEditing()
        overlay?.select(nil)
        overlay?.removeFromSuperview()
        strip.isHidden = true
        container.resizeSubviews(withOldSize: container.bounds.size)
        canvas.window?.makeFirstResponder(canvas)
        onActiveToolChange?()
    }

    func arm(_ tool: MarkupTool?) {
        showMarkup()
        overlay?.tool = tool
        showStyle()
    }

    private func makeStrip() -> MarkupStrip {
        let strip = MarkupStrip()
        strip.onTool = { [weak self] in self?.arm($0) }
        strip.onColor = { [weak self] in self?.setMarkupColor($0) }
        strip.onSize = { [weak self] in self?.setMarkupSize($0) }
        container.strip = strip
        self.strip = strip
        return strip
    }

    private func makeOverlay() -> MarkupOverlay {
        let overlay = MarkupOverlay(canvas: canvas, document: MarkupOverlay.Document(
            marks: { [weak self] in self?.marks ?? [] },
            pixelSize: { [weak self] in self?.pixelSize ?? .zero },
            style: { [weak self] in (self?.markupColor ?? markupPalette[0].color, self?.markupSize ?? .medium) },
            preview: { [weak self] in self?.redraw(draft: $0) },
            put: { [weak self] in self?.put($0) },
            remove: { [weak self] in self?.removeMark(id: $0) },
            selected: { [weak self] _ in self?.showStyle() }))
        self.overlay = overlay
        return overlay
    }

    /// The strip shows the armed tool and the selected mark's color and size, or the style in use.
    private func showStyle() {
        let mark = overlay?.selected
        strip?.show(tool: overlay?.tool, color: mark?.color ?? markupColor, size: mark?.size ?? markupSize)
    }

    func setMarkupColor(_ color: RGBA) {
        markupColor = color
        preferences?.set(Self.hex(color), for: "markupColor")
        if var mark = overlay?.selected {
            mark.color = color
            put(mark)
        }
        showStyle()
    }

    func setMarkupSize(_ size: MarkSize) {
        markupSize = size
        preferences?.set(size.rawValue, for: "markupSize")
        if var mark = overlay?.selected {
            mark.size = size
            mark.width = size.width(for: pixelSize)
            put(mark)
        }
        showStyle()
    }

    // MARK: Copy and Paste

    /// The selected mark, or with none the whole image with its edits and marks at full resolution.
    func copy() {
        let pasteboard = pasteboard
        if let mark = overlay?.selected, let data = try? JSONEncoder().encode(mark) {
            pasteboard.clearContents()
            pasteboard.setData(data, forType: Self.markPasteboardType)
            return
        }
        let path = (original ?? url).path, edits = edits, marks = marks
        Task {
            guard let image = await ImageSaving.image(edits, marks: marks, from: path) else { return NSSound.beep() }
            let picture = NSImage(cgImage: image, size: .zero)
            pasteboard.clearContents()
            pasteboard.writeObjects([picture])
            if let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) { pasteboard.setData(png, forType: .png) }
        }
    }

    var canPasteMark: Bool { isEditing && pasteboard.data(forType: Self.markPasteboardType) != nil }

    /// A copied mark again, a little below and right of where it was, selected.
    func paste() {
        guard isEditing, let data = pasteboard.data(forType: Self.markPasteboardType),
              let copied = try? JSONDecoder().decode(ImageMark.self, from: data), copied.isValid else { return NSSound.beep() }
        var mark = copied.moved(by: CGPoint(x: copied.width * 4, y: copied.width * 4))
        mark = ImageMark(id: ImageMark.newID(), kind: mark.kind, color: mark.color, size: mark.size, width: mark.width)
        showMarkup()
        put(mark)
        overlay?.select(mark.id)
    }
}
