import AppKit

/// A cell that draws its text and nothing else: much cheaper than a text field per cell, which made opening a table
/// slower than opening the same file as plain text. It also draws the selection's tint, a find match's tint and the
/// current cell's ring, so changing the selection redraws cells rather than adding views.
final class CellView: NSView {
    /// The fonts at the default size.
    static let font = NSFont.systemFont(ofSize: TableDocument.defaultFontSize)
    static let numberFont = NSFont.monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
    private static let leftParagraph = paragraph(.natural, .byTruncatingTail)
    private static let rightParagraph = paragraph(.right, .byTruncatingTail)
    private static let rowNumberParagraph = paragraph(.right, .byClipping)

    private static func paragraph(_ alignment: NSTextAlignment, _ lineBreak: NSLineBreakMode) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineBreakMode = lineBreak
        return style
    }

    /// The row-number column's cell, grey and right-aligned.
    private let isRowNumber: Bool
    var text = "" {
        didSet { if text != oldValue { needsDisplay = true } }
    }
    var font: NSFont {
        didSet { if font != oldValue { needsDisplay = true } }
    }
    /// Right for number columns.
    var alignsRight = false {
        didSet { if alignsRight != oldValue { needsDisplay = true } }
    }
    enum Mark { case none, match, current }
    /// A find match is tinted; the current one more strongly.
    var mark = Mark.none {
        didSet { if mark != oldValue { needsDisplay = true } }
    }
    /// In the selection: tinted. The current cell has a ring. Both are grey while the table isn't taking keys.
    var isSelected = false {
        didSet { if isSelected != oldValue { needsDisplay = true } }
    }
    var isCurrent = false {
        didSet { if isCurrent != oldValue { needsDisplay = true } }
    }
    var isActive = true {
        didSet { if isActive != oldValue { needsDisplay = true } }
    }

    /// Black on the current match's solid yellow, which white text in dark mode can't be read on.
    var textColor: NSColor {
        mark == .current ? .black : isRowNumber ? .secondaryLabelColor : .labelColor
    }

    private var selectionColor: NSColor { isActive ? .controlAccentColor : .secondaryLabelColor }

    init(identifier: NSUserInterfaceItemIdentifier, isRowNumber: Bool) {
        self.isRowNumber = isRowNumber
        font = isRowNumber ? Self.numberFont : Self.font
        super.init(frame: .zero)
        self.identifier = identifier
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        if isSelected {
            selectionColor.withAlphaComponent(0.16).setFill()
            bounds.fill(using: .sourceOver)
        }
        if mark != .none {
            NSColor.findHighlightColor.withAlphaComponent(mark == .current ? 1 : 0.4).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 3, yRadius: 3).fill()
        }
        let paragraph = isRowNumber ? Self.rowNumberParagraph : alignsRight ? Self.rightParagraph : Self.leftParagraph
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor, .paragraphStyle: paragraph]
        let line = text.replacingOccurrences(of: "\n", with: " ")  // one line per cell, as a spreadsheet shows it
        let height = font.boundingRectForFont.height
        let box = NSRect(x: 3, y: (bounds.height - height) / 2, width: bounds.width - 6, height: height)
        (line as NSString).draw(with: box, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: attributes)
        if isCurrent {
            selectionColor.setStroke()
            let ring = NSBezierPath(rect: bounds.insetBy(dx: 1, dy: 1))
            ring.lineWidth = 2
            ring.stroke()
        }
    }

    // A cell reads as static text, as the text field it replaces did.
    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .staticText }
    override func accessibilityValue() -> Any? { text }
    override func isAccessibilitySelected() -> Bool { isSelected || isCurrent }
}
