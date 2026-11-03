import Foundation
import Markdown

/// What a stretch of Markdown source is, for the Editor's styling. Runs come parent before child, so a child's style
/// adds to its parent's.
nonisolated enum StyleKind: Equatable, Sendable {
    case heading(Int), strong, emphasis, strikethrough, code, codeBlock, link, quote, marker, taskBox
}

/// The Editor's view of a parse: style runs over the source (UTF-16 ranges, as NSString counts) and what the sidebar,
/// task clicks and Cmd-click need.
nonisolated struct MarkdownStyle: Equatable, Sendable {
    var runs: [StyleRun] = []
    var outline: [OutlineItem] = []
    var words = 0
    var tasks = (done: 0, total: 0)
    var taskBoxes: [NSRange] = []
    var links: [LinkRange] = []

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.runs == rhs.runs && lhs.outline == rhs.outline && lhs.words == rhs.words && lhs.tasks == rhs.tasks
            && lhs.taskBoxes == rhs.taskBoxes && lhs.links == rhs.links
    }
}

nonisolated struct StyleRun: Equatable, Sendable {
    let range: NSRange
    let kind: StyleKind
}

nonisolated struct LinkRange: Equatable, Sendable {
    let range: NSRange
    let destination: String
}

/// Parses Markdown source with swift-markdown and turns each node's source range into style runs. Pure, so it runs
/// off the main thread.
nonisolated enum MarkdownStyler {
    static func style(_ source: String) -> MarkdownStyle {
        var walk = Walk(source: source)
        walk.visit(Document(parsing: source))
        walk.style.words = source.split { $0.isWhitespace }.count
        return walk.style
    }

    /// The UTF-16 offset where each 1-based line starts (index 0 is line 1).
    static func lineStarts(in source: String) -> [Int] {
        Lines(Array(source.utf8)).starts.map(\.utf16)
    }

    private struct Walk {
        let bytes: [UInt8]
        let lines: Lines
        var style = MarkdownStyle()

        init(source: String) {
            bytes = Array(source.utf8)
            lines = Lines(bytes)
        }

        mutating func visit(_ markup: Markup) {
            guard let range = markup.range.flatMap(nsRange) else { return markup.children.forEach { visit($0) } }
            switch markup {
            case let heading as Heading:
                add(range, .heading(min(max(heading.level, 1), 6)))
                markEnds(of: markup, in: range)
                style.outline.append(OutlineItem(title: heading.plainText, level: heading.level, line: markup.range!.lowerBound.line))
            case is Strong: add(range, .strong); markEnds(of: markup, in: range)
            case is Emphasis: add(range, .emphasis); markEnds(of: markup, in: range)
            case is Strikethrough: add(range, .strikethrough); markEnds(of: markup, in: range)
            case let link as Markdown.Link:
                add(childSpan(of: markup) ?? range, .link)
                markEnds(of: markup, in: range)
                if let destination = link.destination { style.links.append(LinkRange(range: range, destination: destination)) }
            case let image as Markdown.Image:
                markEnds(of: markup, in: range)
                if let source = image.source { style.links.append(LinkRange(range: range, destination: source)) }
            case is InlineCode, is InlineHTML:
                add(range, .code)
                markBackticks(in: range)
            case let code as CodeBlock:
                add(range, .codeBlock)
                markFences(of: code, in: range)
            case is HTMLBlock: add(range, .codeBlock)
            case is BlockQuote:
                add(range, .quote)
                markLinePrefixes(in: range) { $0 == UInt8(ascii: ">") || $0 == UInt8(ascii: " ") }
            case is ThematicBreak: add(range, .marker)
            case let item as Markdown.ListItem:
                markListPrefix(of: item, in: range)
            case is Markdown.Table:
                markTable(in: range)
            default: break
            }
            for child in markup.children { visit(child) }
        }

        private mutating func add(_ range: NSRange, _ kind: StyleKind) {
            if range.length > 0 { style.runs.append(StyleRun(range: range, kind: kind)) }
        }

        /// The source between the node's start and its first child, and after its last child: `## `, `**`, `[`, `](url)`.
        private mutating func markEnds(of markup: Markup, in range: NSRange) {
            guard let inner = childSpan(of: markup) else { return add(range, .marker) }
            add(NSRange(location: range.location, length: inner.location - range.location), .marker)
            add(NSRange(location: NSMaxRange(inner), length: NSMaxRange(range) - NSMaxRange(inner)), .marker)
        }

        private func childSpan(of markup: Markup) -> NSRange? {
            let ranges = markup.children.compactMap { $0.range.flatMap(nsRange) }
            guard let first = ranges.first, let last = ranges.last else { return nil }
            return NSRange(location: first.location, length: NSMaxRange(last) - first.location)
        }

        private mutating func markBackticks(in range: NSRange) {
            guard let span = byteSpan(range), bytes[span.lowerBound] == UInt8(ascii: "`") else { return }
            let tick = UInt8(ascii: "`")
            let open = bytes[span].prefix { $0 == tick }.count
            let close = min(bytes[span].reversed().prefix { $0 == tick }.count, span.count - open)
            add(NSRange(location: range.location, length: open), .marker)
            add(NSRange(location: NSMaxRange(range) - close, length: close), .marker)
        }

        /// A fenced block's opening and closing fence lines.
        private mutating func markFences(of code: CodeBlock, in range: NSRange) {
            guard let span = byteSpan(range), let first = bytes[span].first(where: { $0 != UInt8(ascii: " ") }),
                  first == UInt8(ascii: "`") || first == UInt8(ascii: "~") else { return }
            let lineRanges = self.lineRanges(in: range)
            guard let opening = lineRanges.first else { return }
            add(opening, .marker)
            if lineRanges.count > 1, let closing = lineRanges.last, text(closing).trimmingCharacters(in: .whitespaces).hasPrefix(String(UnicodeScalar(first))) {
                add(closing, .marker)
            }
        }

        /// `- `, `1. ` and a task box `[ ]` before an item's first block.
        private mutating func markListPrefix(of item: Markdown.ListItem, in range: NSRange) {
            let firstChild = item.children.first(where: { $0.range != nil }).flatMap { $0.range.flatMap(nsRange) }
            let prefixEnd = firstChild?.location ?? NSMaxRange(range)
            let prefix = NSRange(location: range.location, length: prefixEnd - range.location)
            if item.checkbox != nil {
                style.tasks.total += 1
                if item.checkbox == .checked { style.tasks.done += 1 }
            }
            guard item.checkbox != nil, let box = taskBox(after: prefix) else { return add(prefix, .marker) }
            add(NSRange(location: prefix.location, length: box.location - prefix.location), .marker)
            add(box, .taskBox)
            style.taskBoxes.append(box)
        }

        /// swift-markdown starts a task item's paragraph after its box, or at the marker's end, depending on the
        /// version; either way the box is the first `[ ]`, `[x]` or `[X]` from the marker on.
        private func taskBox(after prefix: NSRange) -> NSRange? {
            guard let start = byteOffset(prefix.location) else { return nil }
            var index = start
            while index + 2 < bytes.count, bytes[index] != 0x0A, bytes[index] != 0x0D {
                if bytes[index] == UInt8(ascii: "["), [UInt8(ascii: " "), UInt8(ascii: "x"), UInt8(ascii: "X")].contains(bytes[index + 1]),
                   bytes[index + 2] == UInt8(ascii: "]") {
                    return NSRange(location: lines.utf16(at: index), length: 3)
                }
                index += 1
            }
            return nil
        }

        private mutating func markLinePrefixes(in range: NSRange, while matches: (UInt8) -> Bool) {
            for line in lineRanges(in: range) {
                guard let start = byteOffset(line.location) else { continue }
                var end = start
                while end < bytes.count, matches(bytes[end]) { end += 1 }
                if end > start { add(NSRange(location: line.location, length: lines.utf16(at: end) - line.location), .marker) }
            }
        }

        /// Pipes and the delimiter row.
        private mutating func markTable(in range: NSRange) {
            let lineRanges = self.lineRanges(in: range)
            for (index, line) in lineRanges.enumerated() {
                if index == 1 { add(line, .marker); continue }
                guard let span = byteSpan(line) else { continue }
                for offset in span where bytes[offset] == UInt8(ascii: "|") {
                    add(NSRange(location: lines.utf16(at: offset), length: 1), .marker)
                }
            }
        }

        private func lineRanges(in range: NSRange) -> [NSRange] {
            guard let span = byteSpan(range) else { return [] }
            var result: [NSRange] = []
            var start = span.lowerBound
            var index = start
            while index < span.upperBound {
                if bytes[index] == 0x0A || bytes[index] == 0x0D {
                    result.append(NSRange(location: lines.utf16(at: start), length: lines.utf16(at: index) - lines.utf16(at: start)))
                    if bytes[index] == 0x0D, index + 1 < span.upperBound, bytes[index + 1] == 0x0A { index += 1 }
                    start = index + 1
                }
                index += 1
            }
            if start < span.upperBound {
                result.append(NSRange(location: lines.utf16(at: start), length: lines.utf16(at: span.upperBound) - lines.utf16(at: start)))
            }
            return result
        }

        private func text(_ range: NSRange) -> String {
            guard let span = byteSpan(range) else { return "" }
            return String(decoding: bytes[span], as: UTF8.self)
        }

        private func nsRange(_ range: SourceRange) -> NSRange? {
            guard let start = lines.byteOffset(range.lowerBound), let end = lines.byteOffset(range.upperBound), end >= start else { return nil }
            let location = lines.utf16(at: start)
            return NSRange(location: location, length: lines.utf16(at: min(end, bytes.count)) - location)
        }

        private func byteSpan(_ range: NSRange) -> Range<Int>? {
            guard let start = byteOffset(range.location), let end = byteOffset(NSMaxRange(range)) else { return nil }
            return start..<end
        }

        private func byteOffset(_ utf16: Int) -> Int? { lines.byteOffset(utf16: utf16) }
    }

    /// Converts between swift-markdown's (line, UTF-8 column) locations, UTF-8 byte offsets and UTF-16 offsets.
    /// Lines break at LF, CR or CRLF, as CommonMark's do.
    private struct Lines {
        let bytes: [UInt8]
        let starts: [(utf8: Int, utf16: Int)]

        init(_ bytes: [UInt8]) {
            self.bytes = bytes
            var starts = [(utf8: 0, utf16: 0)]
            var utf16 = 0
            var index = 0
            while index < bytes.count {
                let byte = bytes[index]
                utf16 += Self.units(byte)
                if byte == 0x0D, index + 1 < bytes.count, bytes[index + 1] == 0x0A {
                    utf16 += 1
                    index += 1
                    starts.append((index + 1, utf16))
                } else if byte == 0x0A || byte == 0x0D {
                    starts.append((index + 1, utf16))
                }
                index += 1
            }
            self.starts = starts
        }

        /// UTF-16 units a UTF-8 byte contributes: one per leading byte, two for a four-byte sequence's lead.
        private static func units(_ byte: UInt8) -> Int {
            byte & 0xC0 == 0x80 ? 0 : byte >= 0xF0 ? 2 : 1
        }

        func byteOffset(_ location: SourceLocation) -> Int? {
            guard starts.indices.contains(location.line - 1) else { return location.line == starts.count + 1 ? bytes.count : nil }
            return min(starts[location.line - 1].utf8 + location.column - 1, bytes.count)
        }

        func utf16(at byteOffset: Int) -> Int {
            let line = lineIndex(containingByte: byteOffset)
            var utf16 = starts[line].utf16
            for index in starts[line].utf8..<min(byteOffset, bytes.count) { utf16 += Self.units(bytes[index]) }
            return utf16
        }

        func byteOffset(utf16 target: Int) -> Int? {
            var low = 0, high = starts.count - 1
            while low < high {
                let middle = (low + high + 1) / 2
                if starts[middle].utf16 <= target { low = middle } else { high = middle - 1 }
            }
            var utf16 = starts[low].utf16
            var index = starts[low].utf8
            while utf16 < target, index < bytes.count {
                utf16 += Self.units(bytes[index])
                index += 1
                while index < bytes.count, bytes[index] & 0xC0 == 0x80 { index += 1 }
            }
            return utf16 == target ? index : nil
        }

        private func lineIndex(containingByte offset: Int) -> Int {
            var low = 0, high = starts.count - 1
            while low < high {
                let middle = (low + high + 1) / 2
                if starts[middle].utf8 <= offset { low = middle } else { high = middle - 1 }
            }
            return low
        }
    }
}
