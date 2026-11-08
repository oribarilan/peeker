import AppKit
import PeekerKit

/// The markup strip under the toolbar, the bar image markup uses: the tools with their keys, six colors, then S, M
/// and L, or for a text box an Aa menu (font, Bold, Italic, Plain or Box) and the point size. Its controls never take
/// the keyboard, so typing in a box goes on.
final class PDFMarkupStrip: NSView {
    /// A tool picked, by id; nil for none.
    var onTool: ((String?) -> Void)?
    var onColor: ((RGBA) -> Void)?
    var onSize: ((MarkupSize) -> Void)?
    /// A text style or point size picked.
    var onText: ((TextBoxStyle, Double) -> Void)?
    private let bar: MarkupBar
    var swatches: [ColorSwatch] { bar.swatches }
    var tools: NSSegmentedControl { bar.tools }
    let sizes = MarkupBar.sizePicker()
    let textMenu = StyleMenu(sections: [TextBoxStyle.Font.allCases.map { ($0.rawValue.capitalized, $0.rawValue) },
                                        [("Bold", "bold"), ("Italic", "italic")], [("Plain", "plain"), ("Box", "box")]])
    private let pointSize = NSTextField(labelWithString: "")
    private let pointSizes: NSStackView
    private var style = TextBoxStyle.standard
    private var fontSize = TextBoxStyle.standardSize

    /// The pages under the strip, which get the scroll wheel turned over it.
    weak var pages: NSView?

    static let palette: [(name: String, color: RGBA)] = [
        ("Black", rgb(0x000000)), ("Red", rgb(0xDB2626)), ("Orange", rgb(0xF28000)), ("Green", rgb(0x219940)), ("Blue", rgb(0x1A66E6)), ("Yellow", rgb(0xFFD60A)),
    ]

    /// In whole 8-bit steps, as the file stores colors, so a color read back is the swatch's own.
    private static func rgb(_ hex: Int) -> RGBA {
        RGBA(red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, alpha: 1)
    }

    init() {
        let smaller = NSButton(title: "−", target: nil, action: nil)
        let larger = NSButton(title: "+", target: nil, action: nil)
        pointSizes = NSStackView(views: [smaller, pointSize, larger])
        pointSizes.spacing = 2
        bar = MarkupBar(tools: PDFPlugin.markupTools.map { MarkupBar.Tool(id: $0.id, title: $0.title, symbol: $0.symbol, key: $0.key) },
                        palette: Self.palette, moreColors: false, details: [sizes, textMenu, pointSizes])
        super.init(frame: .zero)
        bar.onTool = { [weak self] in self?.onTool?($0) }
        bar.onColor = { [weak self] in self?.onColor?($0) }
        sizes.target = self
        sizes.action = #selector(sizeChosen(_:))
        textMenu.onPick = { [weak self] in self?.textItemChosen($0) }
        for (button, label, action) in [(smaller, "Smaller Text", #selector(smaller(_:))), (larger, "Larger Text", #selector(larger(_:)))] {
            button.target = self
            button.action = action
            button.bezelStyle = .smallSquare
            button.controlSize = .small
            button.refusesFirstResponder = true
            button.toolTip = label
            button.setAccessibilityLabel(label)
        }
        pointSize.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        pointSize.alignment = .center
        let widest = "\(Int(PDFMarks.fontSizes.upperBound)) pt".size(withAttributes: [.font: pointSize.font!]).width
        pointSize.widthAnchor.constraint(equalToConstant: ceil(widest)).isActive = true
        pointSize.setAccessibilityLabel("Text size")
        bar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bar)
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: topAnchor), bar.bottomAnchor.constraint(equalTo: bottomAnchor),
            bar.leadingAnchor.constraint(equalTo: leadingAnchor), bar.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        // It floats over the page, so it needs a background of its own.
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override var wantsUpdateLayer: Bool { true }
    override func updateLayer() { layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.96).cgColor }

    /// Clicks on the strip's empty parts stay on it rather than reaching the page under it.
    override func mouseDown(with event: NSEvent) {}

    override func scrollWheel(with event: NSEvent) { pages?.scrollWheel(with: event) }

    /// When it appeared, so the second click of a double-click that showed it goes to the page under it.
    private var shownAt = Date.distantPast
    override var isHidden: Bool {
        didSet { if !isHidden, oldValue { shownAt = Date() } }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if let event = NSApp.currentEvent, event.type == .leftMouseDown, event.clickCount > 1,
           Date().timeIntervalSince(shownAt) < NSEvent.doubleClickInterval { return nil }
        return super.hitTest(point)
    }

    /// Shows the armed tool by id, and the text style and size, or the drawing color and size.
    func show(tool: String?, state: EditController.StripState) {
        switch state {
        case .text(let style, let size):
            (self.style, fontSize) = (style, size)
            bar.show(tool: tool, color: style.color)
            textMenu.check(Set([style.font.rawValue, style.boxed ? "box" : "plain"] + (style.bold ? ["bold"] : []) + (style.italic ? ["italic"] : [])))
            pointSize.stringValue = "\(Int(size)) pt"
        case .drawing(let color, let size):
            bar.show(tool: tool, color: color)
            sizes.selectedSegment = MarkupSize.allCases.firstIndex(of: size) ?? 1
        }
        let isText = if case .text = state { true } else { false }
        sizes.isHidden = isText
        textMenu.isHidden = !isText
        pointSizes.isHidden = !isText
    }

    /// Whether the text controls show, for tests.
    var showsText: Bool { !textMenu.isHidden }

    @objc private func sizeChosen(_ sender: NSSegmentedControl) {
        if MarkupSize.allCases.indices.contains(sender.selectedSegment) { onSize?(MarkupSize.allCases[sender.selectedSegment]) }
    }

    private func textItemChosen(_ id: String) {
        var style = style
        switch id {
        case "bold": style.bold.toggle()
        case "italic": style.italic.toggle()
        case "plain", "box": style.boxed = id == "box"
        default:
            guard let font = TextBoxStyle.Font(rawValue: id) else { return }
            style.font = font
        }
        onText?(style, fontSize)
    }

    @objc private func smaller(_ sender: Any?) { onText?(style, fontSize - 2) }
    @objc private func larger(_ sender: Any?) { onText?(style, fontSize + 2) }
}
