import Foundation
import Markdown

/// Converts swift-markdown's AST into the compact block tree the host lays out.
///
/// Block: `{"k": kind, …}` with kinds h (heading: l, s, n), p (s), ul / ol (i, start), code (x, lang), q (c), hr,
/// table (rows of cells of spans). List item: `{"c": blocks, "n": line, "t": checked?}`. Span: `[text, styleBits, link?]`.
/// `n` is the 1-based source line, used for outline anchors and task toggling.
enum MarkdownTree {
    static func blocks(from source: String) -> [[String: Any]] {
        Document(parsing: source).children.compactMap(block)
    }

    static func outline(of blocks: [[String: Any]]) -> [[String: Any]] {
        blocks.compactMap { block in
            guard block["k"] as? String == "h" else { return nil }
            let title = (block["s"] as? [[Any]] ?? []).compactMap { $0.first as? String }.joined()
            return ["title": title, "level": block["l"] ?? 1, "anchor": block["n"] ?? 0]
        }
    }

    static func taskCounts(in blocks: [[String: Any]]) -> (done: Int, total: Int) {
        var done = 0, total = 0
        func visit(_ blocks: [[String: Any]]) {
            for block in blocks {
                for item in block["i"] as? [[String: Any]] ?? [] {
                    if let checked = item["t"] as? Bool {
                        total += 1
                        if checked { done += 1 }
                    }
                    visit(item["c"] as? [[String: Any]] ?? [])
                }
                visit(block["c"] as? [[String: Any]] ?? [])
            }
        }
        visit(blocks)
        return (done, total)
    }

    /// Flips the task checkbox on a 1-based source line and saves the file.
    static func toggleTask(atLine line: Int, inFile path: String) throws {
        var lines = try String(contentsOfFile: path, encoding: .utf8).components(separatedBy: "\n")
        guard lines.indices.contains(line - 1),
              let match = lines[line - 1].prefixMatch(of: /^(\s*(?:>\s*)*(?:[-*+]|\d+[.)])\s+)\[([ xX])\]/) else {
            throw PluginFailure("no task on line \(line)")
        }
        lines[line - 1].replaceSubrange(match.range, with: "\(match.1)[\(match.2 == " " ? "x" : " ")]")
        try lines.joined(separator: "\n").write(toFile: path, atomically: true, encoding: .utf8)
    }

    private static func block(_ markup: Markup) -> [String: Any]? {
        switch markup {
        case let heading as Heading:
            return ["k": "h", "l": heading.level, "s": spans(heading), "n": line(heading)]
        case let paragraph as Paragraph:
            return ["k": "p", "s": spans(paragraph)]
        case let list as UnorderedList:
            return ["k": "ul", "i": Array(list.listItems).map(item)]
        case let list as OrderedList:
            return ["k": "ol", "start": Int(list.startIndex), "i": Array(list.listItems).map(item)]
        case let code as CodeBlock:
            return ["k": "code", "x": code.code, "lang": code.language ?? ""]
        case let quote as BlockQuote:
            return ["k": "q", "c": quote.children.compactMap(block)]
        case is ThematicBreak:
            return ["k": "hr"]
        case let table as Markdown.Table:
            let head = [Array(table.head.children).map(spans)]
            let body = Array(table.body.children).map { row in Array(row.children).map(spans) }
            return ["k": "table", "rows": head + body]
        case let html as HTMLBlock:
            return ["k": "code", "x": html.rawHTML, "lang": "html"]
        default:
            return nil
        }
    }

    private static func item(_ item: ListItem) -> [String: Any] {
        var out: [String: Any] = ["c": item.children.compactMap(block), "n": line(item)]
        if let checkbox = item.checkbox { out["t"] = checkbox == .checked }
        return out
    }

    private static func spans(_ markup: Markup) -> [[Any]] {
        var out: [[Any]] = []
        collect(markup, style: [], link: nil, into: &out)
        return out
    }

    private static func collect(_ markup: Markup, style: SpanStyle, link: String?, into out: inout [[Any]]) {
        for child in markup.children {
            switch child {
            case let text as Markdown.Text: append(text.string, style, link, &out)
            case is SoftBreak: append(" ", style, link, &out)
            case is LineBreak: append("\n", style, link, &out)
            case let code as InlineCode: append(code.code, style.union(.code), link, &out)
            case let html as InlineHTML: append(html.rawHTML, style.union(.code), link, &out)
            case let image as Markdown.Image: append(image.plainText.isEmpty ? "image" : image.plainText, style.union(.image), image.source, &out)
            case is Emphasis: collect(child, style: style.union(.emphasis), link: link, into: &out)
            case is Strong: collect(child, style: style.union(.strong), link: link, into: &out)
            case is Strikethrough: collect(child, style: style.union(.strikethrough), link: link, into: &out)
            case let linked as Markdown.Link: collect(child, style: style, link: linked.destination, into: &out)
            default: collect(child, style: style, link: link, into: &out)
            }
        }
    }

    private static func append(_ text: String, _ style: SpanStyle, _ link: String?, _ out: inout [[Any]]) {
        out.append(link.map { [text, style.rawValue, $0] } ?? [text, style.rawValue])
    }

    private static func line(_ markup: Markup) -> Int {
        markup.range?.lowerBound.line ?? 0
    }
}
