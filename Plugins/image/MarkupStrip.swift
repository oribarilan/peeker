import AppKit
import PeekerKit

/// The markup tools, in the strip's order. Their keys avoid C (Crop) and Rotate & Resize's L, R, H and V.
nonisolated enum MarkupTool: String, CaseIterable, Sendable {
    case arrow, box, text, pixelate, step, pen, marker, spotlight

    var id: String { "markup-\(rawValue)" }
    init?(id: String) {
        guard id.hasPrefix("markup-") else { return nil }
        self.init(rawValue: String(id.dropFirst("markup-".count)))
    }

    var title: String {
        switch self {
        case .arrow: "Arrow"
        case .box: "Box"
        case .text: "Text"
        case .pixelate: "Pixelate"
        case .step: "Steps"
        case .pen: "Pen"
        case .marker: "Marker"
        case .spotlight: "Spotlight"
        }
    }

    var key: String {
        switch self {
        case .arrow: "a"
        case .box: "b"
        case .text: "t"
        case .pixelate: "x"
        case .step: "n"
        case .pen: "p"
        case .marker: "k"
        case .spotlight: "s"
        }
    }

    var symbol: String {
        switch self {
        case .arrow: "arrow.up.right"
        case .box: "rectangle"
        case .text: "textformat"
        case .pixelate: "checkerboard.rectangle"
        case .step: "1.circle"
        case .pen: "scribble"
        case .marker: "highlighter"
        case .spotlight: "flashlight.on.fill"
        }
    }

    @MainActor var spec: ToolSpec { ToolSpec(id: id, title: title, symbol: symbol, shortcut: key, isEditTool: true, showsInToolbar: false) }
}

/// The six swatches, the first the default.
nonisolated let markupPalette: [(name: String, color: RGBA)] = [
    ("Red", RGBA(red: 0.92, green: 0.2, blue: 0.2, alpha: 1)),
    ("Orange", RGBA(red: 1, green: 0.58, blue: 0, alpha: 1)),
    ("Yellow", RGBA(red: 1, green: 0.84, blue: 0.04, alpha: 1)),
    ("Green", RGBA(red: 0.2, green: 0.74, blue: 0.3, alpha: 1)),
    ("Blue", RGBA(red: 0.1, green: 0.48, blue: 1, alpha: 1)),
    ("Black", RGBA(red: 0, green: 0, blue: 0, alpha: 1)),
]

/// The bar under the toolbar: tools, colors, and the size, or Pixelate's strength, Spotlight's shape, or the size and
/// the text menu.
final class MarkupStrip: NSView {
    /// What the strip's last control sets.
    enum Detail { case size, strength, shape, text }

    var onTool: ((MarkupTool?) -> Void)?
    var onColor: ((RGBA) -> Void)?
    var onSize: ((MarkSize) -> Void)?
    var onStrength: ((Double) -> Void)?
    var onOval: ((Bool) -> Void)?
    var onText: ((TextStyle) -> Void)?
    let tools: NSSegmentedControl
    private var swatches: [SwatchButton] = []
    private let sizes = NSSegmentedControl(labels: ["S", "M", "L"], trackingMode: .selectOne, target: nil, action: nil)
    let strength = NSSlider(value: MarkStyle.defaultStrength, minValue: 0, maxValue: 1, target: nil, action: nil)
    private lazy var strengthRow: NSStackView = {
        let icon = NSImageView(image: NSImage(systemSymbolName: "checkerboard.rectangle", accessibilityDescription: nil)!)
        icon.contentTintColor = .secondaryLabelColor
        let row = NSStackView(views: [icon, strength])
        row.spacing = 6
        return row
    }()
    /// Text's font, bold, italic and effect, in one menu so the strip stays narrow.
    let textMenu = NSPopUpButton(frame: .zero, pullsDown: true)
    private var textStyle = TextStyle.standard
    let shapes = NSSegmentedControl(images: ["rectangle", "oval"].map { NSImage(systemSymbolName: $0, accessibilityDescription: nil)! },
                                    trackingMode: .selectOne, target: nil, action: nil)

    init() {
        tools = NSSegmentedControl(images: MarkupTool.allCases.map { NSImage(systemSymbolName: $0.symbol, accessibilityDescription: $0.title)! },
                                   trackingMode: .selectOne, target: nil, action: nil)
        super.init(frame: .zero)
        tools.target = self
        tools.action = #selector(toolChosen(_:))
        // Each tool's key beside its icon, as toolbar buttons show theirs.
        for (index, tool) in MarkupTool.allCases.enumerated() {
            tools.setToolTip("\(tool.title) (\(tool.key.uppercased()))", forSegment: index)
            tools.setLabel(tool.key.uppercased(), forSegment: index)
        }
        tools.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        tools.setAccessibilityLabel("Markup tools")
        swatches = markupPalette.map { entry in
            let button = SwatchButton(color: entry.color)
            button.target = self
            button.action = #selector(swatchChosen(_:))
            button.toolTip = entry.name
            button.setAccessibilityLabel(entry.name)
            return button
        }
        let more = NSButton(image: NSImage(systemSymbolName: "paintpalette", accessibilityDescription: "More colors")!, target: self,
                            action: #selector(showColors(_:)))
        more.bezelStyle = .accessoryBarAction
        more.toolTip = "More colors"
        sizes.target = self
        sizes.action = #selector(sizeChosen(_:))
        sizes.controlSize = .small
        for (index, name) in ["Small", "Medium", "Large"].enumerated() { sizes.setToolTip(name, forSegment: index) }
        sizes.setAccessibilityLabel("Size")
        strength.target = self
        strength.action = #selector(strengthChosen(_:))
        strength.isContinuous = false  // one edit when the slider is let go
        strength.controlSize = .small
        strength.setAccessibilityLabel("Strength")
        strength.toolTip = "Pixelate strength"
        strength.widthAnchor.constraint(equalToConstant: 80).isActive = true
        shapes.target = self
        shapes.action = #selector(shapeChosen(_:))
        for (index, name) in ["Rectangle", "Oval"].enumerated() {
            shapes.setToolTip(name, forSegment: index)
            shapes.image(forSegment: index)?.accessibilityDescription = name
        }
        shapes.setAccessibilityLabel("Spotlight shape")
        textMenu.addItem(withTitle: "Aa")  // a pull-down's title is its first item
        // Each item carries what it picks: a font, an effect, or the name of a trait to toggle.
        let groups: [[(String, Any)]] = [TextStyle.Font.allCases.map { ($0.rawValue.capitalized, $0) }, [("Bold", "bold"), ("Italic", "italic")],
                                         TextStyle.Effect.allCases.map { ($0.rawValue.capitalized, $0) }]
        for (index, group) in groups.enumerated() {
            if index > 0 { textMenu.menu?.addItem(.separator()) }
            for (title, value) in group {
                let item = NSMenuItem(title: title, action: #selector(textItemChosen(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = value
                textMenu.menu?.addItem(item)
            }
        }
        textMenu.controlSize = .small
        textMenu.toolTip = "Text style"
        textMenu.setAccessibilityLabel("Text style")
        let colors = NSStackView(views: swatches + [more])
        colors.spacing = 4
        let row = NSStackView(views: [tools, separator(), colors, separator(), sizes, strengthRow, shapes, textMenu])
        row.spacing = 8
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
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// Shows the armed tool, the color, and the size, strength, shape or text style as `detail` says.
    func show(tool: MarkupTool?, style: MarkStyle, detail: Detail) {
        tools.selectedSegment = tool.flatMap { MarkupTool.allCases.firstIndex(of: $0) } ?? -1
        for swatch in swatches { swatch.isChosen = swatch.color == style.color }
        sizes.selectedSegment = MarkSize.allCases.firstIndex(of: style.size) ?? 1
        strength.doubleValue = style.strength
        shapes.selectedSegment = style.ovalSpotlight ? 1 : 0
        textStyle = style.text
        for item in textMenu.itemArray.dropFirst() {
            let on = switch item.representedObject {
            case let font as TextStyle.Font: font == style.text.font
            case let effect as TextStyle.Effect: effect == style.text.effect
            case let trait as String: trait == "bold" ? style.text.bold : style.text.italic
            default: false
            }
            item.state = on ? .on : .off
        }
        sizes.isHidden = detail != .size && detail != .text  // text has a size too
        strengthRow.isHidden = detail != .strength
        shapes.isHidden = detail != .shape
        textMenu.isHidden = detail != .text
    }

    /// Which of size, strength, shape and text shows, for tests.
    var detail: Detail { !strengthRow.isHidden ? .strength : !shapes.isHidden ? .shape : !textMenu.isHidden ? .text : .size }

    private func separator() -> NSView {
        let line = NSBox()
        line.boxType = .separator
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 18).isActive = true
        return line
    }

    @objc private func toolChosen(_ sender: NSSegmentedControl) {
        onTool?(MarkupTool.allCases.indices.contains(sender.selectedSegment) ? MarkupTool.allCases[sender.selectedSegment] : nil)
    }

    @objc private func swatchChosen(_ sender: SwatchButton) { onColor?(sender.color) }

    @objc private func sizeChosen(_ sender: NSSegmentedControl) {
        if MarkSize.allCases.indices.contains(sender.selectedSegment) { onSize?(MarkSize.allCases[sender.selectedSegment]) }
    }

    @objc private func strengthChosen(_ sender: NSSlider) { onStrength?(sender.doubleValue) }

    @objc private func shapeChosen(_ sender: NSSegmentedControl) { onOval?(sender.selectedSegment == 1) }

    /// What a menu item of the text menu picks or toggles.
    @objc private func textItemChosen(_ sender: NSMenuItem) {
        var style = textStyle
        switch sender.representedObject {
        case let font as TextStyle.Font: style.font = font
        case let effect as TextStyle.Effect: style.effect = effect
        case let trait as String where trait == "bold": style.bold.toggle()
        case let trait as String where trait == "italic": style.italic.toggle()
        default: return
        }
        onText?(style)
    }

    @objc private func showColors(_ sender: Any?) {
        let panel = NSColorPanel.shared
        panel.setTarget(self)
        panel.setAction(#selector(colorPicked(_:)))
        panel.showsAlpha = false
        panel.orderFront(nil)
    }

    @objc private func colorPicked(_ sender: NSColorPanel) {
        guard let rgb = sender.color.usingColorSpace(.sRGB) else { return }
        let clamp = { (value: CGFloat) in Double(min(max(value, 0), 1)) }  // wide colors can come back past 0 or 1
        onColor?(RGBA(red: clamp(rgb.redComponent), green: clamp(rgb.greenComponent), blue: clamp(rgb.blueComponent), alpha: 1))
    }
}

/// A round color swatch, ringed while it's the color in use.
final class SwatchButton: NSButton {
    let color: RGBA
    var isChosen = false {
        didSet { needsDisplay = true }
    }

    init(color: RGBA) {
        self.color = color
        super.init(frame: NSRect(x: 0, y: 0, width: 18, height: 18))
        isBordered = false
        title = ""
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 18).isActive = true
        heightAnchor.constraint(equalToConstant: 18).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func draw(_ dirtyRect: NSRect) {
        let dot = bounds.insetBy(dx: 3, dy: 3)
        NSColor(cgColor: color.cgColor)?.setFill()
        NSBezierPath(ovalIn: dot).fill()
        NSColor.separatorColor.setStroke()
        NSBezierPath(ovalIn: dot).stroke()
        if isChosen {
            NSColor.controlAccentColor.setStroke()
            let ring = NSBezierPath(ovalIn: bounds.insetBy(dx: 1, dy: 1))
            ring.lineWidth = 2
            ring.stroke()
        }
    }
}
