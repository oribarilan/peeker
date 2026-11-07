import Foundation

/// YAML's scalars: plain, quoted and block, and the kinds of the core schema.
nonisolated extension YAMLParser.Reader {

    /// A plain scalar in a block, with the more indented lines that continue it, folded into one.
    mutating func plain(parent: Int, key: String?, start: Int, asString: Bool) throws(ParseFailure) -> DataNode {
        let first = at
        if isIndicator(UInt8(ascii: ":")) { throw ParseFailure("Expected a key before the colon", at) }
        var line = try plainLine(colon: "A nested key needs a line of its own")
        var end = line.end, multiline = false
        var lineAt = line.stop
        while !line.comment, lineAt < bytes.count {
            if bytes[lineAt] == 0x0D { lineAt += 1 }
            guard lineAt < bytes.count, bytes[lineAt] == 0x0A else { break }
            lineAt += 1
            var next = lineAt
            while next < bytes.count, bytes[next] == 0x20 { next += 1 }
            let column = next - lineAt
            while next < bytes.count, bytes[next] == 0x20 || bytes[next] == 0x09 { next += 1 }
            guard next < bytes.count else { break }
            let byte = bytes[next]
            if byte == 0x0A || byte == 0x0D {
                lineAt = next
                continue
            }
            let marker = column == 0 && (isMarker(UInt8(ascii: "-"), at: next) || isMarker(UInt8(ascii: "."), at: next))
            if column <= parent || byte == UInt8(ascii: "#") || marker { break }
            at = next
            if parent < 0, mappingKey() != nil { throw ParseFailure("Expected a key and a colon", first) }
            line = try plainLine(colon: "This line is indented more than the one above", from: next)
            end = line.end
            multiline = true
            lineAt = line.stop
        }
        at = end
        try endLine()
        try skipToContent()
        if multiline { return DataNode(kind: .string, key: key, value: fold(first..<end), start: start) }
        return DataNode(kind: asString ? .string : kind(first..<end), key: key, value: String(decoding: bytes[first..<end], as: UTF8.self), start: start)
    }

    /// One line of a plain scalar from the cursor: where its text ends, where reading stopped, and whether a comment
    /// stopped it. A `: ` in it would make it a key, which isn't allowed where it is.
    private func plainLine(colon message: String, from begin: Int? = nil) throws(ParseFailure) -> (end: Int, stop: Int, comment: Bool) {
        let begin = begin ?? at
        var position = begin, last = begin
        while position < bytes.count {
            let byte = bytes[position]
            if byte == 0x0A || byte == 0x0D { break }
            if byte == 0x20 || byte == 0x09 {
                position += 1
                continue
            }
            if byte == UInt8(ascii: "#"), position > begin, bytes[position - 1] == 0x20 || bytes[position - 1] == 0x09 {
                return (last, position, true)
            }
            if byte == UInt8(ascii: ":"), isSeparator(position + 1) { throw ParseFailure(message, position) }
            position += 1
            last = position
        }
        return (last, position, false)
    }

    /// A plain scalar in a flow collection; it ends at a comma, a bracket, `: ` or a comment, and may span lines.
    mutating func flowPlain() throws(ParseFailure) -> (text: String, range: Range<Int>, multiline: Bool) {
        let start = at
        var last = start, broken = false, multiline = false
        while at < bytes.count {
            let byte = bytes[at]
            if isFlowIndicator(byte) { break }
            if byte == UInt8(ascii: ":"), isSeparator(at + 1) || isFlowIndicator(bytes[at + 1]) { break }
            if byte == UInt8(ascii: "#"), at > start, [0x20, 0x09, 0x0A, 0x0D].contains(bytes[at - 1]) { break }
            if byte == 0x0A {
                broken = true
            } else if byte != 0x20, byte != 0x09, byte != 0x0D {
                last = at + 1
                multiline = multiline || broken
            }
            at += 1
        }
        guard last > start else { throw ParseFailure("Expected a value", start) }
        let text = multiline ? fold(start..<last) : String(decoding: bytes[start..<last], as: UTF8.self)
        return (text, start..<last, multiline)
    }

    /// Lines joined with spaces, an empty line kept as a line break, each line trimmed.
    func fold(_ range: Range<Int>) -> String {
        var out: [UInt8] = []
        out.reserveCapacity(range.count)
        var position = range.lowerBound, blanks = 0, first = true
        while position < range.upperBound {
            var lineEnd = position
            while lineEnd < range.upperBound, bytes[lineEnd] != 0x0A { lineEnd += 1 }
            var from = position, to = lineEnd
            while from < to, bytes[from] == 0x20 || bytes[from] == 0x09 { from += 1 }
            while to > from, bytes[to - 1] == 0x20 || bytes[to - 1] == 0x09 || bytes[to - 1] == 0x0D { to -= 1 }
            if from == to {
                if !first { blanks += 1 }
            } else {
                if !first {
                    if blanks == 0 { out.append(0x20) } else { out.append(contentsOf: repeatElement(0x0A, count: blanks)) }
                }
                out.append(contentsOf: bytes[from..<to])
                first = false
                blanks = 0
            }
            position = lineEnd + 1
        }
        return String(decoding: out, as: UTF8.self)
    }

    /// A quoted scalar at the cursor, decoded; it may span lines.
    mutating func quoted() throws(ParseFailure) -> String {
        guard let end = quotedEnd(from: at, singleLine: false) else { throw ParseFailure("This string has no closing quote", at) }
        let text = decodeQuoted(at..<end)
        at = end
        return text
    }

    /// Just past the closing quote of the string at `start`, or nil when there's none (on its line, with `singleLine`).
    func quotedEnd(from start: Int, singleLine: Bool) -> Int? {
        let quote = bytes[start]
        var position = start + 1
        while position < bytes.count {
            let byte = bytes[position]
            if byte == quote {
                if quote == UInt8(ascii: "'"), position + 1 < bytes.count, bytes[position + 1] == quote {
                    position += 2
                    continue
                }
                return position + 1
            }
            if byte == 0x0A, singleLine { return nil }
            position += byte == UInt8(ascii: "\\") && quote == UInt8(ascii: "\"") ? 2 : 1
        }
        return nil
    }

    /// A quoted string's text: escapes decoded (`''` in single quotes), line breaks folded to spaces, an empty line to
    /// a line break.
    func decodeQuoted(_ range: Range<Int>) -> String {
        let double = bytes[range.lowerBound] == UInt8(ascii: "\"")
        let inner = range.lowerBound + 1..<range.upperBound - 1
        let special = double ? UInt8(ascii: "\\") : UInt8(ascii: "'")
        guard bytes[inner].contains(where: { $0 == special || $0 == 0x0A || $0 == 0x0D }) else {
            return String(decoding: bytes[inner], as: UTF8.self)
        }
        var out: [UInt8] = []
        out.reserveCapacity(inner.count)
        var position = inner.lowerBound, kept = 0
        while position < inner.upperBound {
            let byte = bytes[position]
            if byte == 0x0D {
                position += 1
            } else if byte == 0x0A {
                while out.count > kept, out.last == 0x20 || out.last == 0x09 { out.removeLast() }
                position += 1
                var breaks = 0
                while position < inner.upperBound, [0x20, 0x09, 0x0A, 0x0D].contains(bytes[position]) {
                    if bytes[position] == 0x0A { breaks += 1 }
                    position += 1
                }
                if breaks == 0 { out.append(0x20) } else { out.append(contentsOf: repeatElement(0x0A, count: breaks)) }
                kept = out.count
            } else if !double, byte == special {
                out.append(byte)
                position += 2
            } else if double, byte == special, position + 1 < inner.upperBound {
                position = escape(at: position + 1, upTo: inner.upperBound, into: &out)
                kept = out.count
            } else {
                out.append(byte)
                position += 1
            }
        }
        return String(decoding: out, as: UTF8.self)
    }

    /// Decodes the escape whose letter is at `position`; returns where reading goes on. An unknown escape stays as
    /// written.
    private func escape(at position: Int, upTo end: Int, into out: inout [UInt8]) -> Int {
        let letter = bytes[position]
        var next = position + 1
        switch letter {
        case UInt8(ascii: "n"): out.append(0x0A)
        case UInt8(ascii: "t"), 0x09: out.append(0x09)
        case UInt8(ascii: "r"): out.append(0x0D)
        case UInt8(ascii: "0"): out.append(0x00)
        case UInt8(ascii: "a"): out.append(0x07)
        case UInt8(ascii: "b"): out.append(0x08)
        case UInt8(ascii: "e"): out.append(0x1B)
        case UInt8(ascii: "f"): out.append(0x0C)
        case UInt8(ascii: "v"): out.append(0x0B)
        case UInt8(ascii: " "), UInt8(ascii: "/"), UInt8(ascii: "\""), UInt8(ascii: "\\"): out.append(letter)
        case UInt8(ascii: "N"): append(0x85, to: &out)
        case UInt8(ascii: "_"): append(0xA0, to: &out)
        case UInt8(ascii: "L"): append(0x2028, to: &out)
        case UInt8(ascii: "P"): append(0x2029, to: &out)
        case UInt8(ascii: "x"), UInt8(ascii: "u"), UInt8(ascii: "U"):
            let digits = letter == UInt8(ascii: "x") ? 2 : letter == UInt8(ascii: "u") ? 4 : 8
            guard next + digits <= end, let value = UInt32(String(decoding: bytes[next..<next + digits], as: UTF8.self), radix: 16) else {
                out += [UInt8(ascii: "\\"), letter]
                return next
            }
            append(value, to: &out)
            next += digits
        case 0x0A, 0x0D:
            // An escaped line break joins the lines, dropping the next one's indentation.
            while next < end, bytes[next] == 0x0A || bytes[next] == 0x20 || bytes[next] == 0x09 { next += 1 }
        default: out += [UInt8(ascii: "\\"), letter]
        }
        return next
    }

    private func append(_ value: UInt32, to out: inout [UInt8]) {
        let scalar = Unicode.Scalar(value) ?? "\u{FFFD}"
        UTF8.encode(scalar) { out.append($0) }
    }

    /// A `|` (literal) or `>` (folded) block scalar: the lines indented more than `parent`, with its chomping
    /// (`-` strip, `+` keep, clip otherwise) and an optional indentation digit.
    mutating func blockScalar(parent: Int, key: String?, start: Int) throws(ParseFailure) -> DataNode {
        let literal = bytes[at] == UInt8(ascii: "|")
        at += 1
        var chomp: UInt8 = 0, explicit = 0
        for _ in 0..<2 where at < bytes.count {
            let byte = bytes[at]
            if byte == UInt8(ascii: "-") || byte == UInt8(ascii: "+") {
                chomp = byte
                at += 1
            } else if byte >= UInt8(ascii: "1"), byte <= UInt8(ascii: "9") {
                explicit = Int(byte - UInt8(ascii: "0"))
                at += 1
            }
        }
        skipSpaces()
        guard atLineEnd() else { throw ParseFailure("Expected a line break after | or >", at) }
        try endLine()
        var indent = explicit > 0 ? max(parent, 0) + explicit : -1
        var out: [UInt8] = []
        var blanks = 0, first = true, previousMore = false, endedWithBreak = false
        while at < bytes.count {
            var position = at
            while position < bytes.count, bytes[position] == 0x20 { position += 1 }
            let spaces = position - at
            while position < bytes.count, bytes[position] == 0x0D { position += 1 }
            if position >= bytes.count {
                at = bytes.count
                break
            }
            if bytes[position] == 0x0A {
                blanks += 1
                at = position + 1
                continue
            }
            if indent < 0 {
                guard spaces > parent else { break }
                indent = spaces
            }
            guard spaces >= indent, !(spaces == 0 && (isMarker(UInt8(ascii: "-"), at: at) || isMarker(UInt8(ascii: "."), at: at))) else { break }
            var lineEnd = position
            while lineEnd < bytes.count, bytes[lineEnd] != 0x0A { lineEnd += 1 }
            let from = at + indent
            var to = lineEnd
            if to > from, bytes[to - 1] == 0x0D { to -= 1 }
            let more = bytes[from] == 0x20 || bytes[from] == 0x09
            let breaks = first ? blanks : literal || more || previousMore ? blanks + 1 : blanks
            if !first, breaks == 0 { out.append(0x20) } else { out.append(contentsOf: repeatElement(0x0A, count: breaks)) }
            out.append(contentsOf: bytes[from..<to])
            first = false
            previousMore = more
            blanks = 0
            endedWithBreak = lineEnd < bytes.count
            at = endedWithBreak ? lineEnd + 1 : bytes.count
        }
        if chomp != UInt8(ascii: "-"), !first, endedWithBreak { out.append(0x0A) }
        if chomp == UInt8(ascii: "+") { out.append(contentsOf: repeatElement(0x0A, count: blanks)) }
        try skipToContent()
        return DataNode(kind: .string, key: key, value: String(decoding: out, as: UTF8.self), start: start)
    }

    // MARK: Kinds

    /// A plain scalar's kind by the YAML 1.2 core schema.
    func kind(_ range: Range<Int>) -> DataNode.Kind {
        guard let first = range.first.map({ bytes[$0] }) else { return .null }
        let text = bytes[range]
        switch first {
        case UInt8(ascii: "~"): return range.count == 1 ? .null : .string
        case UInt8(ascii: "n"), UInt8(ascii: "N"):
            return text.elementsEqual("null".utf8) || text.elementsEqual("Null".utf8) || text.elementsEqual("NULL".utf8) ? .null : .string
        case UInt8(ascii: "t"), UInt8(ascii: "T"):
            return text.elementsEqual("true".utf8) || text.elementsEqual("True".utf8) || text.elementsEqual("TRUE".utf8) ? .bool : .string
        case UInt8(ascii: "f"), UInt8(ascii: "F"):
            return text.elementsEqual("false".utf8) || text.elementsEqual("False".utf8) || text.elementsEqual("FALSE".utf8) ? .bool : .string
        case UInt8(ascii: "0")...UInt8(ascii: "9"), UInt8(ascii: "+"), UInt8(ascii: "-"), UInt8(ascii: "."):
            return isNumber(text) ? .number : .string
        default: return .string
        }
    }

    /// Decimal ints and floats, `0x` hex, `0o` octal, `.inf` and `.nan`.
    private func isNumber(_ text: ArraySlice<UInt8>) -> Bool {
        var position = text.startIndex
        let end = text.endIndex
        func isDigit(_ byte: UInt8) -> Bool { byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9") }
        if text.count > 2, text[position] == UInt8(ascii: "0") {
            let rest = text.dropFirst(2)
            switch text[position + 1] {
            case UInt8(ascii: "x"): return rest.allSatisfy { isDigit($0) || (0x61...0x66).contains($0 | 0x20) }
            case UInt8(ascii: "o"): return rest.allSatisfy { $0 >= UInt8(ascii: "0") && $0 <= UInt8(ascii: "7") }
            default: break
            }
        }
        if text[position] == UInt8(ascii: "+") || text[position] == UInt8(ascii: "-") { position += 1 }
        if position < end, text[position] == UInt8(ascii: "."), end - position == 4 {
            let word = text[(position + 1)...]
            if word.elementsEqual("inf".utf8) || word.elementsEqual("Inf".utf8) || word.elementsEqual("INF".utf8) { return true }
            if position == text.startIndex, word.elementsEqual("nan".utf8) || word.elementsEqual("NaN".utf8) || word.elementsEqual("NAN".utf8) { return true }
        }
        let whole = position
        while position < end, isDigit(text[position]) { position += 1 }
        let wholeDigits = position - whole
        var fraction = 0
        if position < end, text[position] == UInt8(ascii: ".") {
            position += 1
            let from = position
            while position < end, isDigit(text[position]) { position += 1 }
            fraction = position - from
        }
        guard wholeDigits > 0 || fraction > 0 else { return false }
        if position < end, text[position] == UInt8(ascii: "e") || text[position] == UInt8(ascii: "E") {
            position += 1
            if position < end, text[position] == UInt8(ascii: "+") || text[position] == UInt8(ascii: "-") { position += 1 }
            let from = position
            while position < end, isDigit(text[position]) { position += 1 }
            guard position > from else { return false }
        }
        return position == end
    }
}
