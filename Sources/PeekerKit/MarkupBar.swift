import AppKit

/// The markup strip's shared part, so marking up an image and a PDF look and work alike: the tools, each with its key
/// beside its icon, the color swatches, and the plugin's own controls for the tool in use (a size, a text menu...),
/// which the plugin shows and hides.
public final class MarkupBar: NSView {
    public struct Tool: Sendable {
        public let id: String
        public let title: String
        public let symbol: String
        /// A single letter, shown uppercased.
        public let key: String

        public init(id: String, title: String, symbol: String, key: String) {
            self.id = id
            self.title = title
            self.symbol = symbol
            self.key = key
        }
    }

    public var onTool: ((String?) -> Void)?
    public var onColor: ((RGBA) -> Void)?
    public let tools: NSSegmentedControl
    public private(set) var swatches: [ColorSwatch] = []
    private let toolList: [Tool]

    /// `details` sit after the colors, in order, and should refuse the keyboard as the bar's own controls do, so Delete,
    /// Escape and Undo keep reaching the marks. `moreColors` adds a button for the system color picker.
    public init(tools: [Tool], palette: [(name: String, color: RGBA)], moreColors: Bool, details: [NSView]) {
        toolList = tools
        // The key is drawn into the icon rather than set as a label, which Accessibility would read instead of the name.
        self.tools = NSSegmentedControl(
            images: tools.map {
                KeyedSymbolImage.make(
                    symbol: $0.symbol, name: $0.title, key: $0.key.uppercased(), pointSize: 12, fontSize: NSFont.smallSystemFontSize) ?? NSImage()
            }, trackingMode: .selectOne, target: nil, action: nil)
        super.init(frame: .zero)
        self.tools.target = self
        self.tools.action = #selector(toolChosen(_:))
        for (index, tool) in tools.enumerated() { self.tools.setToolTip("\(tool.title) (\(tool.key.uppercased()))", forSegment: index) }
        self.tools.controlSize = .small
        self.tools.refusesFirstResponder = true
        self.tools.setAccessibilityLabel("Markup tools")
        swatches = palette.map { entry in
            let swatch = ColorSwatch(color: entry.color)
            swatch.target = self
            swatch.action = #selector(swatchChosen(_:))
            swatch.toolTip = entry.name
            swatch.setAccessibilityLabel(entry.name)
            return swatch
        }
        var colorViews: [NSView] = swatches
        if moreColors {
            let more = NSButton(
                image: NSImage(systemSymbolName: "paintpalette", accessibilityDescription: "More colors") ?? NSImage(), target: self,
                action: #selector(showColors(_:)))
            more.bezelStyle = .accessoryBarAction
            more.controlSize = .small
            more.refusesFirstResponder = true
            more.toolTip = "More colors"
            colorViews.append(more)
        }
        let colors = NSStackView(views: colorViews)
        colors.spacing = 4
        let row = NSStackView(views: [self.tools, Self.separator(), colors] + (details.isEmpty ? [] : [Self.separator()] + details))
        row.spacing = 7
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
        setAccessibilityLabel("Markup")
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// Shows the armed tool, by id, and the color in use.
    public func show(tool: String?, color: RGBA) {
        tools.selectedSegment = tool.flatMap { id in toolList.firstIndex { $0.id == id } } ?? -1
        for swatch in swatches { swatch.isChosen = swatch.color == color }
    }

    /// An S, M, L control, small, for a plugin's sizes.
    public static func sizePicker() -> NSSegmentedControl {
        let sizes = NSSegmentedControl(labels: ["S", "M", "L"], trackingMode: .selectOne, target: nil, action: nil)
        sizes.controlSize = .small
        sizes.refusesFirstResponder = true
        for (index, name) in ["Small", "Medium", "Large"].enumerated() { sizes.setToolTip(name, forSegment: index) }
        sizes.setAccessibilityLabel("Size")
        return sizes
    }

    private static func separator() -> NSView {
        let line = NSBox()
        line.boxType = .separator
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 18).isActive = true
        return line
    }

    @objc private func toolChosen(_ sender: NSSegmentedControl) {
        onTool?(toolList.indices.contains(sender.selectedSegment) ? toolList[sender.selectedSegment].id : nil)
    }

    @objc private func swatchChosen(_ sender: ColorSwatch) { onColor?(sender.color) }

    @objc private func showColors(_ sender: Any?) {
        let panel = NSColorPanel.shared
        panel.setTarget(self)
        panel.setAction(#selector(colorPicked(_:)))
        panel.showsAlpha = false
        panel.isContinuous = false  // one edit per pick, not one per step of a drag in the wheel
        panel.orderFront(nil)
    }

    @objc private func colorPicked(_ sender: NSColorPanel) {
        guard let rgb = sender.color.usingColorSpace(.sRGB) else { return }
        let clamp = { (value: CGFloat) in Double(min(max(value, 0), 1)) }  // wide colors can come back past 0 or 1
        onColor?(RGBA(red: clamp(rgb.redComponent), green: clamp(rgb.greenComponent), blue: clamp(rgb.blueComponent), alpha: 1))
    }
}

/// A round color swatch, ringed while it's the color in use. It never takes the keyboard.
public final class ColorSwatch: NSButton {
    public let color: RGBA
    public var isChosen = false {
        didSet {
            needsDisplay = true
            setAccessibilityValue(isChosen ? "chosen" : nil)
        }
    }

    public init(color: RGBA) {
        self.color = color
        super.init(frame: NSRect(x: 0, y: 0, width: 18, height: 18))
        isBordered = false
        title = ""
        refusesFirstResponder = true
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 18).isActive = true
        heightAnchor.constraint(equalToConstant: 18).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override public func draw(_ dirtyRect: NSRect) {
        let dot = bounds.insetBy(dx: 3, dy: 3)
        NSColor(srgbRed: color.red, green: color.green, blue: color.blue, alpha: 1).setFill()
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

/// The Aa pull-down for text: sections of items, each picking or toggling something by id, and checked by id.
public final class StyleMenu: NSPopUpButton {
    public var onPick: ((String) -> Void)?

    /// `sections` of (title, id) items, separated by lines.
    public init(sections: [[(title: String, id: String)]]) {
        super.init(frame: .zero, pullsDown: true)
        addItem(withTitle: "Aa")  // a pull-down's title is its first item
        for (index, section) in sections.enumerated() {
            if index > 0 { menu?.addItem(.separator()) }
            for (title, id) in section {
                let item = NSMenuItem(title: title, action: #selector(picked(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = id
                menu?.addItem(item)
            }
        }
        controlSize = .small
        refusesFirstResponder = true
        toolTip = "Text style"
        setAccessibilityTitle("Text style")  // it shows "Aa", which says nothing read aloud
        setAccessibilityLabel("Text style")
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// Checks the items whose ids are in `ids`, and unchecks the rest.
    public func check(_ ids: Set<String>) {
        for item in itemArray.dropFirst() { item.state = (item.representedObject as? String).map(ids.contains) == true ? .on : .off }
    }

    @objc private func picked(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? String { onPick?(id) }
    }
}
