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

/// The bar under the toolbar: tools, colors and sizes.
final class MarkupStrip: NSView {
    var onTool: ((MarkupTool?) -> Void)?
    var onColor: ((RGBA) -> Void)?
    var onSize: ((MarkSize) -> Void)?
    private let tools: NSSegmentedControl
    private var swatches: [SwatchButton] = []
    private let sizes = NSSegmentedControl(labels: ["S", "M", "L"], trackingMode: .selectOne, target: nil, action: nil)

    init() {
        tools = NSSegmentedControl(images: MarkupTool.allCases.map { NSImage(systemSymbolName: $0.symbol, accessibilityDescription: $0.title)! },
                                   trackingMode: .selectOne, target: nil, action: nil)
        super.init(frame: .zero)
        tools.target = self
        tools.action = #selector(toolChosen(_:))
        for (index, tool) in MarkupTool.allCases.enumerated() { tools.setToolTip("\(tool.title) (\(tool.key.uppercased()))", forSegment: index) }
        tools.setAccessibilityLabel("Markup tools")
        swatches = markupPalette.map { entry in
            let button = SwatchButton(color: entry.color)
            button.target = self
            button.action = #selector(swatchChosen(_:))
            button.toolTip = entry.name
            button.setAccessibilityLabel(entry.name)
            return button
        }
        let more = NSButton(title: "More…", target: self, action: #selector(showColors(_:)))
        more.bezelStyle = .accessoryBarAction
        sizes.target = self
        sizes.action = #selector(sizeChosen(_:))
        for (index, name) in ["Small", "Medium", "Large"].enumerated() { sizes.setToolTip(name, forSegment: index) }
        sizes.setAccessibilityLabel("Size")
        let colors = NSStackView(views: swatches + [more])
        colors.spacing = 6
        let row = NSStackView(views: [tools, separator(), colors, separator(), sizes])
        row.spacing = 12
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

    /// Shows the armed tool, the color and the size.
    func show(tool: MarkupTool?, color: RGBA, size: MarkSize) {
        tools.selectedSegment = tool.flatMap { MarkupTool.allCases.firstIndex(of: $0) } ?? -1
        for swatch in swatches { swatch.isChosen = swatch.color == color }
        sizes.selectedSegment = MarkSize.allCases.firstIndex(of: size) ?? 1
    }

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

    @objc private func showColors(_ sender: Any?) {
        let panel = NSColorPanel.shared
        panel.setTarget(self)
        panel.setAction(#selector(colorPicked(_:)))
        panel.showsAlpha = false
        panel.orderFront(nil)
    }

    @objc private func colorPicked(_ sender: NSColorPanel) {
        guard let rgb = sender.color.usingColorSpace(.sRGB) else { return }
        onColor?(RGBA(red: rgb.redComponent, green: rgb.greenComponent, blue: rgb.blueComponent, alpha: 1))
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
