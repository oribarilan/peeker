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

    /// The remembered style; what's missing or doesn't read is the standard one (red, medium).
    static func markupStyle(in preferences: PluginPreferences?) -> MarkStyle {
        var style = MarkStyle.standard
        if let size = preferences?.string("markupSize").flatMap(MarkSize.init(rawValue:)) { style.size = size }
        if let strength = preferences?.double("markupStrength"), (0...1).contains(strength) { style.strength = strength }
        style.ovalSpotlight = preferences?.string("spotlightShape") == "oval"
        if let json = preferences?.string("textStyle"), let text = try? JSONDecoder().decode(TextStyle.self, from: Data(json.utf8)) {
            style.text = text
        }
        guard let hex = preferences?.string("markupColor"), hex.count == 6, let value = UInt32(hex, radix: 16) else { return style }
        // A swatch comes back as itself, so it shows as chosen.
        if let swatch = markupPalette.first(where: { Self.hex($0.color) == hex.uppercased() }) {
            style.color = swatch.color
        } else {
            let channel = { (shift: UInt32) in Double((value >> shift) & 0xFF) / 255 }
            style.color = RGBA(red: channel(16), green: channel(8), blue: channel(0), alpha: 1)
        }
        return style
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
        strip.onStrength = { [weak self] in self?.setMarkupStrength($0) }
        strip.onOval = { [weak self] in self?.setSpotlightOval($0) }
        strip.onText = { [weak self] in self?.setTextStyle($0) }
        container.strip = strip
        self.strip = strip
        return strip
    }

    private func makeOverlay() -> MarkupOverlay {
        let overlay = MarkupOverlay(
            canvas: canvas,
            document: MarkupOverlay.Document(
                marks: { [weak self] in self?.marks ?? [] },
                pixelSize: { [weak self] in self?.pixelSize ?? .zero },
                style: { [weak self] in self?.markupStyle ?? .standard },
                hide: { [weak self] in self?.redraw(hiding: $0) },
                preview: { [weak self] in self?.preview($0) },
                put: { [weak self] in self?.put($0) },
                remove: { [weak self] in self?.removeMark(id: $0) },
                selected: { [weak self] _ in self?.showStyle() }))
        self.overlay = overlay
        return overlay
    }

    /// The strip shows the armed tool and the style of the text being typed or the selected mark, or the style in use.
    /// Pixelate's strength or Spotlight's shape takes the size's place, and the text menu joins it, while that tool is
    /// armed or its mark selected.
    func showStyle() {
        let mark = overlay?.editingMark ?? overlay?.selected
        var style = markupStyle
        if let mark {
            style.color = mark.color
            style.size = mark.size
        }
        var detail = MarkupStrip.Detail.size
        switch mark?.kind {
        case .pixelate(_, let strength)?:
            style.strength = strength
            detail = .strength
        case .spotlight(_, let ellipse)?:
            style.ovalSpotlight = ellipse
            detail = .shape
        case .text(_, _, let text)?:
            style.text = text
            detail = .text
        case nil where overlay?.tool == .pixelate: detail = .strength
        case nil where overlay?.tool == .spotlight: detail = .shape
        case nil where overlay?.tool == .text: detail = .text
        default: break
        }
        strip?.show(tool: overlay?.tool, style: style, detail: detail)
    }

    func setMarkupStrength(_ strength: Double) {
        markupStyle.strength = min(max(strength, 0), 1)
        preferences?.set(markupStyle.strength, for: "markupStrength")
        if var mark = overlay?.selected, case .pixelate(let rect, _) = mark.kind {
            mark.kind = .pixelate(rect, strength: markupStyle.strength)
            put(mark)
        }
        showStyle()
    }

    func setTextStyle(_ text: TextStyle) {
        markupStyle.text = text
        if let json = try? JSONEncoder().encode(text) { preferences?.set(String(decoding: json, as: UTF8.self), for: "textStyle") }
        let restyle = { (mark: inout ImageMark) in
            if case .text(let origin, let string, _) = mark.kind { mark.kind = .text(origin: origin, string: string, style: text) }
        }
        if overlay?.restyleEditing(restyle) == true {
            // put when typing ends
        } else if var mark = overlay?.selected, case .text = mark.kind {
            restyle(&mark)
            put(mark)
        }
        showStyle()
    }

    func setSpotlightOval(_ oval: Bool) {
        markupStyle.ovalSpotlight = oval
        preferences?.set(oval ? "oval" : "rectangle", for: "spotlightShape")
        if var mark = overlay?.selected, case .spotlight(let rect, _) = mark.kind {
            mark.kind = .spotlight(rect, ellipse: oval)
            put(mark)
        }
        showStyle()
    }

    func setMarkupColor(_ color: RGBA) {
        markupStyle.color = color
        preferences?.set(Self.hex(color), for: "markupColor")
        if overlay?.restyleEditing({ $0.color = color }) == true {
            // put when typing ends
        } else if var mark = overlay?.selected {
            mark.color = color
            put(mark)
        }
        showStyle()
    }

    func setMarkupSize(_ size: MarkSize) {
        markupStyle.size = size
        preferences?.set(size.rawValue, for: "markupSize")
        let width = size.width(for: pixelSize)
        if overlay?.restyleEditing({
            $0.size = size; $0.width = width
        }) == true {
            // put when typing ends
        } else if var mark = overlay?.selected {
            mark.size = size
            mark.width = width
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
        let source = source, edits = edits, marks = marks
        Task {
            guard let image = await ImageSaving.image(edits, marks: marks, from: source) else { return NSSound.beep() }
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
            let copied = try? JSONDecoder().decode(ImageMark.self, from: data), copied.isValid
        else { return NSSound.beep() }
        var mark = copied.moved(by: CGPoint(x: copied.width * 4, y: copied.width * 4))
        mark = ImageMark(id: ImageMark.newID(), kind: mark.kind, color: mark.color, size: mark.size, width: mark.width)
        showMarkup()
        put(mark)
        overlay?.select(mark.id)
    }
}
