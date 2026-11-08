import AppKit
import PeekerKit

/// The bar under the toolbar while a text box is waited for, typed or selected: an Aa menu (font, Bold, Italic, Plain
/// or Box), six colors and the size. Its controls never take the keyboard, so typing in a box goes on.
final class TextBoxStrip: NSView {
    /// A style or size picked.
    var onChange: ((TextBoxStyle, Double) -> Void)?
    let textMenu = NSPopUpButton(frame: .zero, pullsDown: true)
    private(set) var swatches: [ColorSwatch] = []
    private let sizeLabel = NSTextField(labelWithString: "")
    private var style = TextBoxStyle.standard
    private var size = TextBoxStyle.standardSize

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
        super.init(frame: .zero)
        textMenu.addItem(withTitle: "Aa")  // a pull-down's title is its first item
        let groups: [[(String, Any)]] = [[("Sans", TextBoxStyle.Font.sans), ("Serif", TextBoxStyle.Font.serif), ("Mono", TextBoxStyle.Font.mono)],
                                         [("Bold", "bold"), ("Italic", "italic")], [("Plain", false), ("Box", true)]]
        for (index, group) in groups.enumerated() {
            if index > 0 { textMenu.menu?.addItem(.separator()) }
            for (title, value) in group {
                let item = NSMenuItem(title: title, action: #selector(menuChosen(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = value
                textMenu.menu?.addItem(item)
            }
        }
        textMenu.controlSize = .small
        textMenu.refusesFirstResponder = true
        textMenu.toolTip = "Text style"
        textMenu.setAccessibilityTitle("Text style")  // it shows "Aa", which says nothing read aloud
        textMenu.setAccessibilityLabel("Text style")
        swatches = Self.palette.map { entry in
            let swatch = ColorSwatch(color: entry.color)
            swatch.target = self
            swatch.action = #selector(swatchChosen(_:))
            swatch.toolTip = entry.name
            swatch.setAccessibilityLabel(entry.name)
            return swatch
        }
        let smaller = NSButton(title: "−", target: self, action: #selector(smaller(_:)))
        let larger = NSButton(title: "+", target: self, action: #selector(larger(_:)))
        for (button, label) in [(smaller, "Smaller Text"), (larger, "Larger Text")] {
            button.bezelStyle = .smallSquare
            button.controlSize = .small
            button.refusesFirstResponder = true
            button.toolTip = label
            button.setAccessibilityLabel(label)
        }
        sizeLabel.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        sizeLabel.alignment = .center
        let widest = "\(Int(PDFMarks.fontSizes.upperBound)) pt".size(withAttributes: [.font: sizeLabel.font!]).width
        sizeLabel.widthAnchor.constraint(equalToConstant: ceil(widest)).isActive = true
        sizeLabel.setAccessibilityLabel("Text size")
        let colors = NSStackView(views: swatches)
        colors.spacing = 4
        let sizes = NSStackView(views: [smaller, sizeLabel, larger])
        sizes.spacing = 2
        let row = NSStackView(views: [textMenu, separator(), colors, separator(), sizes])
        row.spacing = 10
        row.edgeInsets = NSEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        let line = NSBox()
        line.boxType = .separator
        for view in [row, line] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            line.topAnchor.constraint(equalTo: row.bottomAnchor),
            line.leadingAnchor.constraint(equalTo: leadingAnchor),
            line.trailingAnchor.constraint(equalTo: trailingAnchor),
            line.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Text box style")
        // It floats over the page, so it needs a background of its own.
        wantsLayer = true
    }

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

    required init?(coder: NSCoder) { fatalError("not used") }

    func show(_ style: TextBoxStyle, size: Double) {
        self.style = style
        self.size = size
        for item in textMenu.itemArray.dropFirst() {
            let on = switch item.representedObject {
            case let font as TextBoxStyle.Font: font == style.font
            case let trait as String: trait == "bold" ? style.bold : style.italic
            case let boxed as Bool: boxed == style.boxed
            default: false
            }
            item.state = on ? .on : .off
        }
        for swatch in swatches { swatch.isChosen = swatch.color == style.color }
        sizeLabel.stringValue = "\(Int(size)) pt"
    }

    private func separator() -> NSView {
        let line = NSBox()
        line.boxType = .separator
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 18).isActive = true
        return line
    }

    @objc private func menuChosen(_ sender: NSMenuItem) {
        var style = style
        switch sender.representedObject {
        case let font as TextBoxStyle.Font: style.font = font
        case let trait as String where trait == "bold": style.bold.toggle()
        case let trait as String where trait == "italic": style.italic.toggle()
        case let boxed as Bool: style.boxed = boxed
        default: return
        }
        onChange?(style, size)
    }

    @objc private func swatchChosen(_ sender: ColorSwatch) {
        var style = style
        style.color = sender.color
        onChange?(style, size)
    }

    @objc private func smaller(_ sender: Any?) { onChange?(style, size - 2) }
    @objc private func larger(_ sender: Any?) { onChange?(style, size + 2) }
}
