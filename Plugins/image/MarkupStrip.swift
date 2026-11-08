import AppKit
import PeekerKit

/// The markup tools, in the strip's order. Tools PDFs have too use the same keys there (A, L, B, T, P); C stays Crop's.
/// Rotate & Resize's L, R, H and V work only in its panel, a window of its own, so they don't clash.
nonisolated enum MarkupTool: String, CaseIterable, Sendable {
    case arrow, line, box, text, pixelate, step, pen, marker, spotlight

    var id: String { "markup-\(rawValue)" }
    init?(id: String) {
        guard id.hasPrefix("markup-") else { return nil }
        self.init(rawValue: String(id.dropFirst("markup-".count)))
    }

    var title: String {
        switch self {
        case .arrow: "Arrow"
        case .line: "Line"
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
        case .line: "l"
        case .box: "b"
        case .text: "t"
        case .pixelate: "x"
        case .step: "n"
        case .pen: "p"
        case .marker: "h"  // H highlights, as Highlight does in PDFs
        case .spotlight: "s"
        }
    }

    var symbol: String {
        switch self {
        case .arrow: "arrow.up.right"
        case .line: "line.diagonal"
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

/// The bar under the toolbar: the shared markup bar (tools and colors) with the image's own controls: the size, or
/// Pixelate's strength, Spotlight's shape, or the size and the text menu.
final class MarkupStrip: NSView {
    /// What the strip's last control sets.
    enum Detail { case size, strength, shape, text }

    var onTool: ((MarkupTool?) -> Void)?
    var onColor: ((RGBA) -> Void)?
    var onSize: ((MarkSize) -> Void)?
    var onStrength: ((Double) -> Void)?
    var onOval: ((Bool) -> Void)?
    var onText: ((TextStyle) -> Void)?
    private let bar: MarkupBar
    var tools: NSSegmentedControl { bar.tools }
    private let sizes = MarkupBar.sizePicker()
    let strength = NSSlider(value: MarkStyle.defaultStrength, minValue: 0, maxValue: 1, target: nil, action: nil)
    private let strengthRow: NSStackView
    /// Text's font, bold, italic and effect, in one menu so the strip stays narrow. Ids are the raw values, which don't overlap.
    let textMenu = StyleMenu(sections: [TextStyle.Font.allCases.map { ($0.rawValue.capitalized, $0.rawValue) },
                                        [("Bold", "bold"), ("Italic", "italic")],
                                        TextStyle.Effect.allCases.map { ($0.rawValue.capitalized, $0.rawValue) }])
    private var textStyle = TextStyle.standard
    let shapes = NSSegmentedControl(images: ["rectangle", "oval"].map { NSImage(systemSymbolName: $0, accessibilityDescription: nil)! },
                                    trackingMode: .selectOne, target: nil, action: nil)

    init() {
        let icon = NSImageView(image: NSImage(systemSymbolName: "checkerboard.rectangle", accessibilityDescription: nil)!)
        icon.contentTintColor = .secondaryLabelColor
        strengthRow = NSStackView(views: [icon, strength])
        strengthRow.spacing = 6
        bar = MarkupBar(tools: MarkupTool.allCases.map { MarkupBar.Tool(id: $0.id, title: $0.title, symbol: $0.symbol, key: $0.key) },
                        palette: markupPalette, moreColors: true, details: [sizes, strengthRow, shapes, textMenu])
        super.init(frame: .zero)
        bar.onTool = { [weak self] id in self?.onTool?(id.flatMap(MarkupTool.init(id:))) }
        bar.onColor = { [weak self] in self?.onColor?($0) }
        sizes.target = self
        sizes.action = #selector(sizeChosen(_:))
        strength.target = self
        strength.action = #selector(strengthChosen(_:))
        strength.isContinuous = false  // one edit when the slider is let go
        strength.controlSize = .small
        strength.refusesFirstResponder = true
        strength.setAccessibilityLabel("Strength")
        strength.toolTip = "Pixelate strength"
        strength.widthAnchor.constraint(equalToConstant: 80).isActive = true
        shapes.target = self
        shapes.action = #selector(shapeChosen(_:))
        shapes.controlSize = .small
        shapes.refusesFirstResponder = true
        for (index, name) in ["Rectangle", "Oval"].enumerated() {
            shapes.setToolTip(name, forSegment: index)
            shapes.image(forSegment: index)?.accessibilityDescription = name
        }
        shapes.setAccessibilityLabel("Spotlight shape")
        textMenu.onPick = { [weak self] in self?.textItemChosen($0) }
        bar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bar)
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: topAnchor), bar.bottomAnchor.constraint(equalTo: bottomAnchor),
            bar.leadingAnchor.constraint(equalTo: leadingAnchor), bar.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// Shows the armed tool, the color, and the size, strength, shape or text style as `detail` says.
    func show(tool: MarkupTool?, style: MarkStyle, detail: Detail) {
        bar.show(tool: tool?.id, color: style.color)
        sizes.selectedSegment = MarkSize.allCases.firstIndex(of: style.size) ?? 1
        strength.doubleValue = style.strength
        shapes.selectedSegment = style.ovalSpotlight ? 1 : 0
        textStyle = style.text
        textMenu.check(Set([style.text.font.rawValue, style.text.effect.rawValue]
                           + (style.text.bold ? ["bold"] : []) + (style.text.italic ? ["italic"] : [])))
        sizes.isHidden = detail != .size && detail != .text  // text has a size too
        strengthRow.isHidden = detail != .strength
        shapes.isHidden = detail != .shape
        textMenu.isHidden = detail != .text
    }

    /// Which of size, strength, shape and text shows, for tests.
    var detail: Detail { !strengthRow.isHidden ? .strength : !shapes.isHidden ? .shape : !textMenu.isHidden ? .text : .size }

    @objc private func sizeChosen(_ sender: NSSegmentedControl) {
        if MarkSize.allCases.indices.contains(sender.selectedSegment) { onSize?(MarkSize.allCases[sender.selectedSegment]) }
    }

    @objc private func strengthChosen(_ sender: NSSlider) { onStrength?(sender.doubleValue) }

    @objc private func shapeChosen(_ sender: NSSegmentedControl) { onOval?(sender.selectedSegment == 1) }

    /// What an item of the text menu picks or toggles.
    private func textItemChosen(_ id: String) {
        var style = textStyle
        switch id {
        case "bold": style.bold.toggle()
        case "italic": style.italic.toggle()
        default:
            if let font = TextStyle.Font(rawValue: id) { style.font = font }
            else if let effect = TextStyle.Effect(rawValue: id) { style.effect = effect }
            else { return }
        }
        onText?(style)
    }
}
