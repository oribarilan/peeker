import AppKit
import PDFKit

/// Typing into a text box: a borderless text view over the page where the user clicked, with a size control beside
/// it. Ending (a click outside, Escape, a scroll or zoom, another tool) hands the text and size to `onEnd`.
final class TextBoxEditor: NSObject, NSTextViewDelegate {
    private static let padding: CGFloat = 2

    private let textView = BoxTextView()
    private let controls: NSStackView
    private let sizeLabel = NSTextField(labelWithString: "")
    private weak var view: PDFView?
    private let page: PDFPage
    private let topLeft: CGPoint
    private var fontSize: Double
    /// An existing box being edited, hidden meanwhile so its text doesn't show twice.
    private weak var hidden: PDFAnnotation?
    private let onEnd: (String, Double) -> Void
    private var ended = false
    /// Typing's own undo steps, gone with the box rather than left on the document's history.
    private let typingUndo = UndoManager()

    /// The bounds of a box holding `text`, growing right and down from `topLeft` (page space, y up).
    static func fittedRect(text: String, fontSize: Double, topLeft: CGPoint) -> CGRect {
        let font = NSFont(name: PDFMarks.fontName, size: fontSize) ?? .systemFont(ofSize: fontSize)
        let measured = ((text.isEmpty ? " " : text) as NSString)
            .boundingRect(with: CGSize(width: 100_000, height: 100_000), options: .usesLineFragmentOrigin, attributes: [.font: font]).size
        // PDFKit draws free text with a small inset of its own.
        let size = CGSize(width: ceil(measured.width) + padding * 2 + 4, height: ceil(measured.height) + padding * 2)
        return CGRect(x: topLeft.x, y: topLeft.y - size.height, width: size.width, height: size.height)
    }

    init(view: PDFView, page: PDFPage, topLeft: CGPoint, text: String, fontSize: Double, hiding annotation: PDFAnnotation?, onEnd: @escaping (String, Double) -> Void) {
        self.view = view
        self.page = page
        self.topLeft = topLeft
        self.fontSize = fontSize
        self.hidden = annotation
        self.onEnd = onEnd
        let smaller = NSButton(title: "−", target: nil, action: nil)
        let larger = NSButton(title: "+", target: nil, action: nil)
        controls = NSStackView(views: [smaller, sizeLabel, larger])
        super.init()
        for (button, label, action) in [(smaller, "Smaller Text", #selector(smaller(_:))), (larger, "Larger Text", #selector(larger(_:)))] {
            button.target = self
            button.action = action
            button.bezelStyle = .smallSquare
            button.controlSize = .small
            button.setAccessibilityLabel(label)
            button.refusesFirstResponder = true  // clicking a size keeps typing in the box
        }
        sizeLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        controls.spacing = 2
        controls.edgeInsets = NSEdgeInsets(top: 2, left: 4, bottom: 2, right: 4)
        controls.wantsLayer = true
        controls.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        controls.layer?.cornerRadius = 4

        textView.string = text
        textView.isRichText = false
        textView.allowsUndo = true
        textView.textColor = .black
        textView.backgroundColor = NSColor.white.withAlphaComponent(0.85)
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
        view.addSubview(controls)
        layout()
        view.window?.makeFirstResponder(textView)
        textView.selectAll(nil)

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(viewMoved(_:)), name: .PDFViewScaleChanged, object: view)
        if let clip = view.documentView?.enclosingScrollView?.contentView {
            center.addObserver(self, selector: #selector(viewMoved(_:)), name: NSView.boundsDidChangeNotification, object: clip)
        }
    }

    /// Whether `point`, in the PDF view's coordinates, is on the editor or its size control.
    func contains(_ point: NSPoint) -> Bool {
        textView.frame.contains(point) || controls.frame.contains(point)
    }

    func end() {
        guard !ended else { return }
        ended = true
        NotificationCenter.default.removeObserver(self)
        textView.removeFromSuperview()
        controls.removeFromSuperview()
        hidden?.shouldDisplay = true
        onEnd(textView.string, fontSize)
    }

    private func layout() {
        guard let view else { return }
        let scale = view.scaleFactor
        textView.font = NSFont(name: PDFMarks.fontName, size: fontSize * scale)
        textView.textContainerInset = NSSize(width: (Self.padding + 2) * scale, height: Self.padding * scale)
        textView.textContainer?.lineFragmentPadding = 0
        textView.frame = view.convert(Self.fittedRect(text: textView.string, fontSize: fontSize, topLeft: topLeft), from: page)
        sizeLabel.stringValue = "\(Int(fontSize)) pt"
        let size = controls.fittingSize
        controls.frame = CGRect(x: textView.frame.maxX + 6, y: textView.frame.maxY - size.height, width: size.width, height: size.height)
    }

    func textDidChange(_ notification: Notification) { layout() }

    func undoManager(for view: NSTextView) -> UndoManager? { typingUndo }

    func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        guard selector == #selector(NSResponder.cancelOperation(_:)) else { return false }
        end()
        return true
    }

    @objc private func smaller(_ sender: Any?) { resize(by: -2) }
    @objc private func larger(_ sender: Any?) { resize(by: 2) }

    private func resize(by step: Double) {
        fontSize = min(max(fontSize + step, PDFMarks.fontSizes.lowerBound), PDFMarks.fontSizes.upperBound)
        layout()
        view?.window?.makeFirstResponder(textView)
    }

    @objc private func viewMoved(_ note: Notification) { end() }
}

/// Ends the box when it loses focus: saving and leaving Edit mode take focus to finish typing in progress.
private final class BoxTextView: NSTextView {
    var onResign: (() -> Void)?

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned { onResign?() }
        return resigned
    }
}
