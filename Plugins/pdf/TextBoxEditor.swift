import AppKit
import PDFKit
import PeekerKit

/// Typing into a text box: a borderless text view over the page where the user clicked, in the box's font, size and
/// colors, which the strip under the toolbar can change meanwhile. Ending (a click outside, Escape, a scroll or zoom,
/// another tool) hands the text, size and style to `onEnd`.
final class TextBoxEditor: NSObject, NSTextViewDelegate {
    private static let padding: CGFloat = 2

    private let textView = BoxTextView()
    private weak var view: PDFView?
    private let page: PDFPage
    private let topLeft: CGPoint
    var fontSize: Double {
        didSet { layout() }
    }
    var style: TextBoxStyle {
        didSet { layout() }
    }
    /// An existing box being edited, hidden meanwhile so its text doesn't show twice.
    private weak var hidden: PDFAnnotation?
    private let onEnd: (String, Double, TextBoxStyle) -> Void
    private var ended = false
    /// Typing's own undo steps, gone with the box rather than left on the document's history.
    private let typingUndo = UndoManager()

    /// The bounds of a box holding `text`, growing right and down from `topLeft` (page space, y up).
    static func fittedRect(text: String, fontSize: Double, style: TextBoxStyle = .standard, topLeft: CGPoint) -> CGRect {
        let font = NSFont(name: style.fontName, size: fontSize) ?? .systemFont(ofSize: fontSize)
        let measured = ((text.isEmpty ? " " : text) as NSString)
            .boundingRect(with: CGSize(width: 100_000, height: 100_000), options: .usesLineFragmentOrigin, attributes: [.font: font]).size
        // PDFKit draws free text with a small inset of its own.
        let size = CGSize(width: ceil(measured.width) + padding * 2 + 4, height: ceil(measured.height) + padding * 2)
        return CGRect(x: topLeft.x, y: topLeft.y - size.height, width: size.width, height: size.height)
    }

    init(view: PDFView, page: PDFPage, topLeft: CGPoint, text: String, fontSize: Double, style: TextBoxStyle, hiding annotation: PDFAnnotation?,
         onEnd: @escaping (String, Double, TextBoxStyle) -> Void) {
        self.view = view
        self.page = page
        self.topLeft = topLeft
        self.fontSize = fontSize
        self.style = style
        self.hidden = annotation
        self.onEnd = onEnd
        super.init()
        textView.string = text
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isHorizontallyResizable = true
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = CGSize(width: 100_000, height: 100_000)
        textView.wantsLayer = true
        textView.layer?.borderColor = NSColor.controlAccentColor.cgColor
        textView.layer?.borderWidth = 1
        textView.delegate = self
        textView.onResign = { [weak self] in self?.end() }
        textView.setAccessibilityLabel("Text box")
        annotation?.shouldDisplay = false
        view.addSubview(textView)
        layout()
        view.window?.makeFirstResponder(textView)
        textView.selectAll(nil)

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(viewMoved(_:)), name: .PDFViewScaleChanged, object: view)
        if let clip = view.documentView?.enclosingScrollView?.contentView {
            center.addObserver(self, selector: #selector(viewMoved(_:)), name: NSView.boundsDidChangeNotification, object: clip)
        }
    }

    /// Whether `point`, in the PDF view's coordinates, is on the editor.
    func contains(_ point: NSPoint) -> Bool { textView.frame.contains(point) }

    func end() {
        guard !ended else { return }
        ended = true
        NotificationCenter.default.removeObserver(self)
        textView.removeFromSuperview()
        hidden?.shouldDisplay = true
        onEnd(textView.string, fontSize, style)
    }

    private func layout() {
        guard let view else { return }
        let scale = view.scaleFactor
        textView.font = NSFont(name: style.fontName, size: fontSize * scale)
        textView.textColor = color(style.textColor)
        textView.insertionPointColor = color(style.textColor)
        textView.backgroundColor = style.boxed ? color(style.color) : NSColor.white.withAlphaComponent(0.85)
        textView.textContainerInset = NSSize(width: (Self.padding + 2) * scale, height: Self.padding * scale)
        textView.textContainer?.lineFragmentPadding = 0
        textView.frame = view.convert(Self.fittedRect(text: textView.string, fontSize: fontSize, style: style, topLeft: topLeft), from: page)
    }

    private func color(_ rgba: RGBA) -> NSColor { NSColor(srgbRed: rgba.red, green: rgba.green, blue: rgba.blue, alpha: rgba.alpha) }

    func textDidChange(_ notification: Notification) { layout() }

    func undoManager(for view: NSTextView) -> UndoManager? { typingUndo }

    func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        guard selector == #selector(NSResponder.cancelOperation(_:)) else { return false }
        end()
        return true
    }

    @objc private func viewMoved(_ note: Notification) { end() }
}

/// Ends the box when it loses focus: saving, printing and the unsaved-changes question take focus to finish typing in progress.
private final class BoxTextView: NSTextView {
    var onResign: (() -> Void)?

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned { onResign?() }
        return resigned
    }
}
