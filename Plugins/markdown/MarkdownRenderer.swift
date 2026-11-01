import AppKit

/// Lays out the block tree as native attributed text, with each heading's source line mapped to where it starts.
enum MarkdownRenderer {
    static let taskScheme = "peeker-task"

    static func render(_ blocks: some Collection<MarkdownBlock>, leadingBreak: Bool = false) -> (text: NSAttributedString, anchors: [Int: Int]) {
        var context = Context()
        if leadingBreak { context.out.append(NSAttributedString(string: "\n")) }
        for block in blocks { context.render(block, indent: 0) }
        if context.out.length > 0 { context.out.deleteCharacters(in: NSRange(location: context.out.length - 1, length: 1)) }
        return (context.out, context.anchors)
    }

    /// Fonts per (base font, style bits); creating one per span dominated render time on large files.
    private static var fontCache: [String: NSFont] = [:]

    fileprivate static func font(_ base: NSFont, _ style: SpanStyle) -> NSFont {
        let key = "\(base.fontName)|\(base.pointSize)|\(style.rawValue)"
        if let cached = fontCache[key] { return cached }
        var font = base
        var traits: NSFontDescriptor.SymbolicTraits = []
        if style.contains(.strong) { traits.insert(.bold) }
        if style.contains(.emphasis) { traits.insert(.italic) }
        if !traits.isEmpty {
            font = NSFont(descriptor: base.fontDescriptor.withSymbolicTraits(base.fontDescriptor.symbolicTraits.union(traits)), size: base.pointSize) ?? base
        }
        if style.contains(.code) { font = .monospacedSystemFont(ofSize: base.pointSize - 1.5, weight: .regular) }
        fontCache[key] = font
        return font
    }

    private struct Context {
        let out = NSMutableAttributedString()
        var anchors: [Int: Int] = [:]

        private static let body = NSFont.systemFont(ofSize: 14)
        private static let mono = NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular)
        private static let headingSizes: [CGFloat] = [26, 21, 18, 16, 14, 13]

        mutating func render(_ block: MarkdownBlock, indent: CGFloat, prefix: NSAttributedString? = nil) {
            switch block {
            case .heading(let level, let spans, let line):
                let level = min(max(level, 1), 6)
                anchors[line] = out.length
                let font = NSFont.systemFont(ofSize: Self.headingSizes[level - 1], weight: .bold)
                paragraph(spans, font: font, indent: indent, before: level <= 2 ? 14 : 8, prefix: prefix)
            case .paragraph(let spans):
                paragraph(spans, font: Self.body, indent: indent, before: 0, prefix: prefix)
            case .list(let ordered, let start, let items):
                for (index, item) in items.enumerated() {
                    listItem(item, marker: ordered ? "\(start + index)." : "•", indent: indent)
                }
            case .code(let text, _):
                let style = paragraphStyle(indent: indent + 12, before: 4)
                style.paragraphSpacing = 10
                let code = text.trimmingCharacters(in: .newlines)
                out.append(NSAttributedString(string: code + "\n", attributes: [
                    .font: Self.mono, .foregroundColor: NSColor.labelColor, .backgroundColor: NSColor.quaternarySystemFill, .paragraphStyle: style,
                ]))
            case .quote(let children):
                let start = out.length
                for child in children { render(child, indent: indent + 18) }
                out.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: NSRange(location: start, length: out.length - start))
            case .rule:
                out.append(NSAttributedString(string: String(repeating: "─", count: 24) + "\n", attributes: [
                    .foregroundColor: NSColor.separatorColor, .paragraphStyle: paragraphStyle(indent: indent, before: 6),
                ]))
            case .table(let rows):
                table(rows, indent: indent)
            }
        }

        private mutating func listItem(_ item: ListItem, marker: String, indent: CGFloat) {
            let prefix = NSMutableAttributedString(string: marker + "\t", attributes: [.font: Self.body, .foregroundColor: NSColor.secondaryLabelColor])
            if let checked = item.checked {
                prefix.setAttributedString(NSAttributedString(string: (checked ? "☑" : "☐") + "\t", attributes: [
                    .font: NSFont.systemFont(ofSize: 15), .link: URL(string: "\(taskScheme)://\(item.line)")!,
                ]))
            }
            guard let first = item.blocks.first else {
                out.append(prefix)
                out.append(NSAttributedString(string: "\n"))
                return
            }
            render(first, indent: indent + 22, prefix: prefix)
            for child in item.blocks.dropFirst() { render(child, indent: indent + 22) }
        }

        private mutating func paragraph(_ spans: [Span], font: NSFont, indent: CGFloat, before: CGFloat, prefix: NSAttributedString?) {
            let start = out.length
            let style = paragraphStyle(indent: indent, before: before)
            if let prefix {
                style.firstLineHeadIndent = indent - 22
                style.tabStops = [NSTextTab(textAlignment: .left, location: indent)]
                out.append(prefix)
            }
            appendSpans(spans, font: font)
            out.append(NSAttributedString(string: "\n"))
            out.addAttribute(.paragraphStyle, value: style, range: NSRange(location: start, length: out.length - start))
        }

        private mutating func table(_ rows: [[[Span]]], indent: CGFloat) {
            let columns = rows.map(\.count).max() ?? 0
            let style = paragraphStyle(indent: indent, before: 2)
            style.tabStops = (1..<max(columns, 1)).map { NSTextTab(textAlignment: .left, location: indent + CGFloat($0) * 150) }
            for (index, row) in rows.enumerated() {
                let start = out.length
                for (column, cell) in row.enumerated() {
                    if column > 0 { out.append(NSAttributedString(string: "\t")) }
                    appendSpans(cell, font: index == 0 ? .systemFont(ofSize: 13, weight: .semibold) : .systemFont(ofSize: 13))
                }
                out.append(NSAttributedString(string: "\n"))
                out.addAttribute(.paragraphStyle, value: style, range: NSRange(location: start, length: out.length - start))
            }
        }

        private func appendSpans(_ spans: [Span], font: NSFont) {
            for span in spans {
                var attributes: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.labelColor]
                let style = span.style
                if style.contains(.code) { attributes[.backgroundColor] = NSColor.quaternarySystemFill }
                if style.contains(.strikethrough) { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
                if style.contains(.image) { attributes[.foregroundColor] = NSColor.secondaryLabelColor }
                if let link = span.link, let url = URL(string: link) { attributes[.link] = url }
                attributes[.font] = MarkdownRenderer.font(font, style)
                out.append(NSAttributedString(string: style.contains(.image) ? "[\(span.text)]" : span.text, attributes: attributes))
            }
        }

        private func paragraphStyle(indent: CGFloat, before: CGFloat) -> NSMutableParagraphStyle {
            let style = NSMutableParagraphStyle()
            style.headIndent = indent
            style.firstLineHeadIndent = indent
            style.paragraphSpacing = 7
            style.paragraphSpacingBefore = before
            style.lineSpacing = 2
            return style
        }
    }
}
