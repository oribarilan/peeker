import Foundation
import Markdown
import PeekerKit

/// Converts swift-markdown's AST into the block tree the view lays out. Lines are 1-based source lines, used for
/// outline anchors and task toggling.
nonisolated enum MarkdownTree {
    static func blocks(from source: String) -> [MarkdownBlock] {
        Document(parsing: source).children.compactMap(block)
    }

    static func outline(of blocks: [MarkdownBlock]) -> [OutlineItem] {
        blocks.compactMap { block in
            guard case .heading(let level, let spans, let line) = block else { return nil }
            return OutlineItem(title: spans.map(\.text).joined(), level: level, line: line)
        }
    }

    static func taskCounts(in blocks: [MarkdownBlock]) -> (done: Int, total: Int) {
        var done = 0, total = 0
        func visit(_ blocks: [MarkdownBlock]) {
            for block in blocks {
                switch block {
                case .list(_, _, let items):
                    for item in items {
                        if let checked = item.checked {
                            total += 1
                            if checked { done += 1 }
                        }
                        visit(item.blocks)
                    }
                case .quote(let children):
                    visit(children)
                default:
                    break
                }
            }
        }
        visit(blocks)
        return (done, total)
    }

    /// Flips the task checkbox on a 1-based source line and saves the file.
    static func toggleTask(atLine line: Int, inFile path: String) throws(PluginError) {
        var lines = try PluginError.catching { try String(contentsOfFile: path, encoding: .utf8) }.components(separatedBy: "\n")
        guard lines.indices.contains(line - 1),
              let match = lines[line - 1].prefixMatch(of: /^(\s*(?:>\s*)*(?:[-*+]|\d+[.)])\s+)\[([ xX])\]/) else {
            throw PluginError("Line \(line) has no task to tick. The file may have changed.")
        }
        lines[line - 1].replaceSubrange(match.range, with: "\(match.1)[\(match.2 == " " ? "x" : " ")]")
        let data = Data(lines.joined(separator: "\n").utf8)
        try FileReplacement.replaceContents(ofFileAt: path, with: data)
    }

    private static func block(_ markup: Markup) -> MarkdownBlock? {
        switch markup {
        case let heading as Heading:
            return .heading(level: heading.level, spans: spans(heading), line: line(heading))
        case let paragraph as Paragraph:
            return .paragraph(spans(paragraph))
        case let list as UnorderedList:
            return .list(ordered: false, start: 1, items: Array(list.listItems).map(item))
        case let list as OrderedList:
            return .list(ordered: true, start: Int(list.startIndex), items: Array(list.listItems).map(item))
        case let code as CodeBlock:
            return .code(text: code.code, language: code.language)
        case let quote as BlockQuote:
            return .quote(quote.children.compactMap(block))
        case is ThematicBreak:
            return .rule
        case let table as Markdown.Table:
            let head = [Array(table.head.children).map(spans)]
            let body = Array(table.body.children).map { row in Array(row.children).map(spans) }
            return .table(head + body)
        case let html as HTMLBlock:
            return .code(text: html.rawHTML, language: "html")
        default:
            return nil
        }
    }

    private static func item(_ item: Markdown.ListItem) -> ListItem {
        ListItem(blocks: item.children.compactMap(block), line: line(item), checked: item.checkbox.map { $0 == .checked })
    }

    private static func spans(_ markup: Markup) -> [Span] {
        var out: [Span] = []
        collect(markup, style: [], link: nil, into: &out)
        return out
    }

    private static func collect(_ markup: Markup, style: SpanStyle, link: String?, into out: inout [Span]) {
        for child in markup.children {
            switch child {
            case let text as Markdown.Text: out.append(Span(text: text.string, style: style, link: link))
            case is SoftBreak: out.append(Span(text: " ", style: style, link: link))
            case is LineBreak: out.append(Span(text: "\n", style: style, link: link))
            case let code as InlineCode: out.append(Span(text: code.code, style: style.union(.code), link: link))
            case let html as InlineHTML: out.append(Span(text: html.rawHTML, style: style.union(.code), link: link))
            case let image as Markdown.Image:
                out.append(Span(text: image.plainText.isEmpty ? "image" : image.plainText, style: style.union(.image), link: image.source))
            case is Emphasis: collect(child, style: style.union(.emphasis), link: link, into: &out)
            case is Strong: collect(child, style: style.union(.strong), link: link, into: &out)
            case is Strikethrough: collect(child, style: style.union(.strikethrough), link: link, into: &out)
            case let linked as Markdown.Link: collect(child, style: style, link: linked.destination, into: &out)
            default: collect(child, style: style, link: link, into: &out)
            }
        }
    }

    private static func line(_ markup: Markup) -> Int {
        markup.range?.lowerBound.line ?? 0
    }
}
