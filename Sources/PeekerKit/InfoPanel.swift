import AppKit

public nonisolated struct InfoRow: Sendable, Equatable {
    public let label: String
    public let value: String

    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }
}

public enum InfoPanel {
    /// Labels and values in two columns, or nil without rows. One selectable text field with tab stops, not a grid
    /// of labels: the sidebar is laid out on the way to the first paint, and a grid of wrapping labels cost several
    /// milliseconds of Auto Layout there.
    public static func make(_ rows: [InfoRow]) -> SidebarPanel? {
        guard !rows.isEmpty else { return nil }
        let font = NSFont.systemFont(ofSize: 11)
        let labelWidth = rows.map { ceil(($0.label as NSString).size(withAttributes: [.font: font]).width) }.max() ?? 0
        let style = NSMutableParagraphStyle()
        style.tabStops = [NSTextTab(textAlignment: .right, location: labelWidth), NSTextTab(textAlignment: .left, location: labelWidth + 8)]
        style.headIndent = labelWidth + 8
        style.paragraphSpacing = 4
        let text = NSMutableAttributedString()
        for (index, row) in rows.enumerated() {
            text.append(NSAttributedString(string: "\t" + row.label, attributes: [.font: font, .foregroundColor: NSColor.secondaryLabelColor]))
            text.append(NSAttributedString(string: "\t" + row.value + (index < rows.count - 1 ? "\n" : ""), attributes: [.font: font, .foregroundColor: NSColor.labelColor]))
        }
        text.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: text.length))
        let field = NSTextField(wrappingLabelWithString: "")
        field.attributedStringValue = text
        field.isSelectable = true
        return SidebarPanel(field, sizing: .fit)
    }
}
