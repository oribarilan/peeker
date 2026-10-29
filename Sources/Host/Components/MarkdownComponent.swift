import AppKit

/// Lays out the block tree from the Markdown plugin. Task checkboxes are links the plugin handles.
final class MarkdownComponent: NSObject, Component, NSTextViewDelegate {
    private let scrollView = NSTextView.scrollableTextView()
    private var textView: NSTextView { scrollView.documentView as! NSTextView }
    private var anchors: [Int: Int] = [:]
    var onToggleTask: ((Int) -> Void)?

    init(blocks: [[String: Any]]) {
        super.init()
        textView.isEditable = false
        textView.delegate = self
        textView.textContainerInset = NSSize(width: 28, height: 22)
        textView.usesFindBar = true
        textView.linkTextAttributes = [.foregroundColor: NSColor.linkColor, .cursor: NSCursor.pointingHand]
        update(blocks: blocks)
    }

    var view: NSView { scrollView }

    /// Blocks drawn before the first paint; the rest are appended on the next run loop turn, the way Preview
    /// shows the first pages of a long PDF before the rest.
    private static let firstPaintBlocks = 150

    func update(blocks: [[String: Any]]) {
        let visible = scrollView.contentView.bounds.origin
        let head = MarkdownRenderer.render(blocks.prefix(Self.firstPaintBlocks))
        anchors = head.anchors
        textView.textStorage?.setAttributedString(head.text)
        scrollView.contentView.scroll(to: visible)
        guard blocks.count > Self.firstPaintBlocks else { return }
        let offset = head.text.length
        // One frame later, so the first screen is drawn and shown before the rest is laid out.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.016) { [weak self] in
            guard let self else { return }
            let tail = MarkdownRenderer.render(blocks.dropFirst(Self.firstPaintBlocks), leadingBreak: true)
            self.textView.textStorage?.append(tail.text)
            for (line, location) in tail.anchors { self.anchors[line] = location + offset }
            self.scrollView.contentView.scroll(to: visible)
        }
    }

    func scroll(toLine line: Int) {
        guard let location = anchors[line] else { return }
        textView.scrollRangeToVisible(NSRange(location: location, length: 0))
        textView.showFindIndicator(for: NSRange(location: location, length: 1))
    }

    func perform(_ verb: String) -> Bool { false }

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        guard let url = link as? URL else { return false }
        if url.scheme == MarkdownRenderer.taskScheme, let line = Int(url.host() ?? "") {
            onToggleTask?(line)
        } else {
            NSWorkspace.shared.open(url)
        }
        return true
    }
}

enum MarkdownRenderer {
    static let taskScheme = "ppp-task"

    static func render(_ blocks: some Collection<[String: Any]>, leadingBreak: Bool = false) -> (text: NSAttributedString, anchors: [Int: Int]) {
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

        mutating func render(_ block: [String: Any], indent: CGFloat, prefix: NSAttributedString? = nil) {
            switch block["k"] as? String {
            case "h":
                let level = min(max(block["l"] as? Int ?? 1, 1), 6)
                anchors[block["n"] as? Int ?? 0] = out.length
                let font = NSFont.systemFont(ofSize: Self.headingSizes[level - 1], weight: .bold)
                paragraph(spans: block["s"], font: font, indent: indent, before: level <= 2 ? 14 : 8, prefix: prefix)
            case "p":
                paragraph(spans: block["s"], font: Self.body, indent: indent, before: 0, prefix: prefix)
            case "ul", "ol":
                let ordered = block["k"] as? String == "ol"
                let start = block["start"] as? Int ?? 1
                for (index, item) in (block["i"] as? [[String: Any]] ?? []).enumerated() {
                    listItem(item, marker: ordered ? "\(start + index)." : "•", indent: indent)
                }
            case "code":
                let style = paragraphStyle(indent: indent + 12, before: 4)
                style.paragraphSpacing = 10
                let code = (block["x"] as? String ?? "").trimmingCharacters(in: .newlines)
                out.append(NSAttributedString(string: code + "\n", attributes: [
                    .font: Self.mono, .foregroundColor: NSColor.labelColor, .backgroundColor: NSColor.quaternarySystemFill, .paragraphStyle: style,
                ]))
            case "q":
                let start = out.length
                for child in block["c"] as? [[String: Any]] ?? [] { render(child, indent: indent + 18) }
                out.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: NSRange(location: start, length: out.length - start))
            case "hr":
                out.append(NSAttributedString(string: String(repeating: "─", count: 24) + "\n", attributes: [
                    .foregroundColor: NSColor.separatorColor, .paragraphStyle: paragraphStyle(indent: indent, before: 6),
                ]))
            case "table":
                table(block["rows"] as? [[Any]] ?? [], indent: indent)
            default:
                break
            }
        }

        private mutating func listItem(_ item: [String: Any], marker: String, indent: CGFloat) {
            let prefix = NSMutableAttributedString(string: marker + "\t", attributes: [.font: Self.body, .foregroundColor: NSColor.secondaryLabelColor])
            if let checked = item["t"] as? Bool {
                prefix.setAttributedString(NSAttributedString(string: (checked ? "☑" : "☐") + "\t", attributes: [
                    .font: NSFont.systemFont(ofSize: 15), .link: URL(string: "\(taskScheme)://\(item["n"] as? Int ?? 0)")!,
                ]))
            }
            let children = item["c"] as? [[String: Any]] ?? []
            guard let first = children.first else {
                out.append(prefix)
                out.append(NSAttributedString(string: "\n"))
                return
            }
            render(first, indent: indent + 22, prefix: prefix)
            for child in children.dropFirst() { render(child, indent: indent + 22) }
        }

        private mutating func paragraph(spans: Any?, font: NSFont, indent: CGFloat, before: CGFloat, prefix: NSAttributedString?) {
            let start = out.length
            let style = paragraphStyle(indent: indent, before: before)
            if let prefix {
                style.firstLineHeadIndent = indent - 22
                style.tabStops = [NSTextTab(textAlignment: .left, location: indent)]
                out.append(prefix)
            }
            appendSpans(spans as? [[Any]] ?? [], font: font)
            out.append(NSAttributedString(string: "\n"))
            out.addAttribute(.paragraphStyle, value: style, range: NSRange(location: start, length: out.length - start))
        }

        private mutating func table(_ rows: [[Any]], indent: CGFloat) {
            let columns = rows.map(\.count).max() ?? 0
            let style = paragraphStyle(indent: indent, before: 2)
            style.tabStops = (1..<max(columns, 1)).map { NSTextTab(textAlignment: .left, location: indent + CGFloat($0) * 150) }
            for (index, row) in rows.enumerated() {
                let start = out.length
                for (column, cell) in row.enumerated() {
                    if column > 0 { out.append(NSAttributedString(string: "\t")) }
                    appendSpans(cell as? [[Any]] ?? [], font: index == 0 ? .systemFont(ofSize: 13, weight: .semibold) : .systemFont(ofSize: 13))
                }
                out.append(NSAttributedString(string: "\n"))
                out.addAttribute(.paragraphStyle, value: style, range: NSRange(location: start, length: out.length - start))
            }
        }

        private func appendSpans(_ spans: [[Any]], font: NSFont) {
            for span in spans {
                guard let text = span.first as? String else { continue }
                let style = SpanStyle(rawValue: span.count > 1 ? span[1] as? Int ?? 0 : 0)
                var attributes: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.labelColor]
                let spanFont = MarkdownRenderer.font(font, style)
                if style.contains(.code) { attributes[.backgroundColor] = NSColor.quaternarySystemFill }
                if style.contains(.strikethrough) { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
                if style.contains(.image) { attributes[.foregroundColor] = NSColor.secondaryLabelColor }
                if span.count > 2, let link = span[2] as? String, let url = URL(string: link) { attributes[.link] = url }
                attributes[.font] = spanFont
                out.append(NSAttributedString(string: style.contains(.image) ? "[\(text)]" : text, attributes: attributes))
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
