import Foundation

/// A key or value of a JSON file, with its place in the file's UTF-8 bytes. Built off the main thread and never changed
/// after, so it's safe to hand to the view.
nonisolated final class JSONNode: @unchecked Sendable {
    enum Kind: Sendable { case object, array, string, number, bool, null }
    let kind: Kind
    /// The key with its quotes.
    let keyRange: Range<Int>?
    let valueRange: Range<Int>
    /// The children, built when first asked for below the levels the parse builds at once.
    var children: [JSONNode] {
        if let built { return built }
        let made = JSONParser.children(of: self, in: source.bytes)
        built = made
        return made
    }
    fileprivate var built: [JSONNode]?
    fileprivate(set) weak var parent: JSONNode?
    /// Its place among its parent's children.
    fileprivate(set) var index = 0
    /// The parsed bytes, shared by every node: keys and strings are decoded only when asked for, which made parsing a
    /// 3 MB file several times faster.
    fileprivate let source: JSONSource

    fileprivate init(kind: Kind, keyRange: Range<Int>?, valueRange: Range<Int>, source: JSONSource) {
        self.kind = kind
        self.keyRange = keyRange
        self.valueRange = valueRange
        self.source = source
        if kind != .object, kind != .array { built = [] }
    }

    fileprivate func adopt(_ children: [JSONNode]) {
        for (index, child) in children.enumerated() {
            child.parent = self
            child.index = index
        }
        built = children
    }

    /// The member's key, decoded; nil for array items and the top.
    var key: String? { keyRange.map { JSONParser.decodeString(source.bytes[$0]) } }

    /// A string decoded, or a scalar's text as written; nil for objects and arrays.
    var value: String? {
        switch kind {
        case .object, .array: nil
        case .string: JSONParser.decodeString(source.bytes[valueRange])
        default: String(decoding: source.bytes[valueRange], as: UTF8.self)
        }
    }

    /// Where the member starts: its key, or its value in an array.
    var start: Int { keyRange?.lowerBound ?? valueRange.lowerBound }
    var isContainer: Bool { kind == .object || kind == .array }
}

/// The bytes a tree was parsed from.
nonisolated final class JSONSource: Sendable {
    let bytes: [UInt8]
    init(_ bytes: [UInt8]) { self.bytes = bytes }
}

nonisolated struct JSONError: Error, Equatable, Sendable {
    let message: String
    let offset: Int
    let line: Int
    let column: Int
}

/// A lenient JSON reader: comments (`//` and `/* */`) and trailing commas are accepted, as in JSONC and many config
/// files.
nonisolated enum JSONParser {
    /// Deep enough for any real file, shallow enough not to run out of stack on a hostile one.
    static let maxDepth = 512
    /// Levels below the top built at once: the top's children and theirs, which the tree shows open.
    static let eagerLevels = 2

    /// A container's children, one level, read from its bytes; their own children wait until asked for.
    static func children(of node: JSONNode, in bytes: [UInt8]) -> [JSONNode] {
        guard node.isContainer else { return [] }
        var reader = Reader(bytes: bytes, source: node.source, at: node.valueRange.lowerBound)
        guard let copy = try? reader.value(keyRange: nil, depth: 0, build: true, levels: 1) else { return [] }
        let children = copy.built ?? []
        node.adopt(children)
        return children
    }

    static func parse(_ text: String) -> Result<JSONNode, JSONError> {
        let bytes = Array(text.utf8)
        var reader = Reader(bytes: bytes, source: JSONSource(bytes))
        do throws(Failure) {
            try reader.skip()
            // The whole file is checked, but nodes are made only for the levels the tree shows at first.
            guard let root = try reader.value(keyRange: nil, depth: 0, build: true, levels: eagerLevels) else { throw Failure("Expected a value", 0) }
            try reader.skip()
            guard reader.at == bytes.count else { throw Failure("Unexpected text after the end", reader.at) }
            return .success(root)
        } catch {
            let before = bytes[..<min(error.offset, bytes.count)]
            let line = before.filter { $0 == 0x0A }.count + 1
            let column = before.count - (before.lastIndex(of: 0x0A).map { $0 + 1 } ?? 0) + 1
            return .failure(JSONError(message: error.message, offset: error.offset, line: line, column: column))
        }
    }

    /// A quoted string's text, its escapes decoded. A lone high surrogate becomes U+FFFD, keeping what follows.
    static func decodeString(_ quoted: ArraySlice<UInt8>) -> String {
        let inner = quoted.dropFirst().dropLast()
        guard inner.contains(0x5C) else { return String(decoding: inner, as: UTF8.self) }
        var out: [UInt8] = [], at = inner.startIndex
        func hex(_ from: Int) -> UInt32? {
            guard from + 4 <= inner.endIndex else { return nil }
            return UInt32(String(decoding: inner[from..<from + 4], as: UTF8.self), radix: 16)
        }
        while at < inner.endIndex {
            let byte = inner[at]
            at += 1
            guard byte == 0x5C, at < inner.endIndex else { out.append(byte); continue }
            let escape = inner[at]
            at += 1
            switch escape {
            case 0x6E: out.append(0x0A)
            case 0x74: out.append(0x09)
            case 0x72: out.append(0x0D)
            case 0x62: out.append(0x08)
            case 0x66: out.append(0x0C)
            case 0x75:
                guard var scalar = hex(at) else { out.append(escape); continue }
                at += 4
                if (0xD800...0xDBFF).contains(scalar), at + 6 <= inner.endIndex, inner[at] == 0x5C, inner[at + 1] == 0x75,
                   let low = hex(at + 2), (0xDC00...0xDFFF).contains(low) {
                    at += 6
                    scalar = 0x10000 + (scalar - 0xD800) << 10 + (low - 0xDC00)
                }
                out += Array(String(Unicode.Scalar(scalar).map(Character.init) ?? "\u{FFFD}").utf8)
            default: out.append(escape)  // \" \\ \/ and anything else stand for themselves
            }
        }
        return String(decoding: out, as: UTF8.self)
    }

    /// JSON's number grammar: `-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?`.
    static func isNumber(_ bytes: ArraySlice<UInt8>) -> Bool {
        var at = bytes.startIndex
        func digits() -> Int {
            let start = at
            while at < bytes.endIndex, (0x30...0x39).contains(bytes[at]) { at += 1 }
            return at - start
        }
        if at < bytes.endIndex, bytes[at] == 0x2D { at += 1 }
        let whole = at
        guard digits() > 0, at - whole == 1 || bytes[whole] != 0x30 else { return false }
        if at < bytes.endIndex, bytes[at] == 0x2E {
            at += 1
            guard digits() > 0 else { return false }
        }
        if at < bytes.endIndex, bytes[at] == 0x65 || bytes[at] == 0x45 {
            at += 1
            if at < bytes.endIndex, bytes[at] == 0x2B || bytes[at] == 0x2D { at += 1 }
            guard digits() > 0 else { return false }
        }
        return at == bytes.endIndex
    }

    fileprivate struct Failure: Error {
        let message: String
        let offset: Int
        init(_ message: String, _ offset: Int) {
            self.message = message
            self.offset = offset
        }
    }

    fileprivate struct Reader {
        let bytes: [UInt8]
        let source: JSONSource
        var at = 0

        func peek() -> UInt8? { at < bytes.count ? bytes[at] : nil }

        /// Spaces, line breaks and comments.
        mutating func skip() throws(Failure) {
            while let byte = peek() {
                if byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D {
                    at += 1
                } else if byte == 0x2F, at + 1 < bytes.count, bytes[at + 1] == 0x2F {
                    while peek().map({ $0 != 0x0A }) == true { at += 1 }
                } else if byte == 0x2F, at + 1 < bytes.count, bytes[at + 1] == 0x2A {
                    let start = at
                    at += 2
                    while at + 1 < bytes.count, !(bytes[at] == 0x2A && bytes[at + 1] == 0x2F) { at += 1 }
                    guard at + 1 < bytes.count else { throw Failure("This comment has no closing */", start) }
                    at += 2
                } else {
                    return
                }
            }
        }

        /// Reads a value. With `build`, makes its node, and nodes for `levels` levels of children below; without, only
        /// checks it.
        mutating func value(keyRange: Range<Int>?, depth: Int, build: Bool, levels: Int) throws(Failure) -> JSONNode? {
            guard depth < JSONParser.maxDepth else { throw Failure("Nested too deeply", at) }
            let start = at
            let kind: JSONNode.Kind
            switch peek() {
            case 0x7B: return try container(object: true, keyRange: keyRange, depth: depth, build: build, levels: levels)
            case 0x5B: return try container(object: false, keyRange: keyRange, depth: depth, build: build, levels: levels)
            case 0x22:
                try string()
                kind = .string
            case let byte? where byte == 0x2D || (0x30...0x39).contains(byte):
                at += 1
                while let next = peek(), (0x30...0x39).contains(next) || next == 0x2E || next == 0x65 || next == 0x45 || next == 0x2B || next == 0x2D { at += 1 }
                guard JSONParser.isNumber(bytes[start..<at]) else { throw Failure("This isn't a number", start) }
                kind = .number
            case 0x74 where matches(0x74, 0x72, 0x75, 0x65): at += 4; kind = .bool                    // true
            case 0x66 where matches(0x66, 0x61, 0x6C, 0x73, 0x65): at += 5; kind = .bool              // false
            case 0x6E where matches(0x6E, 0x75, 0x6C, 0x6C): at += 4; kind = .null                    // null
            default: throw Failure("Expected a value", start)
            }
            return build ? JSONNode(kind: kind, keyRange: keyRange, valueRange: start..<at, source: source) : nil
        }

        private func matches(_ word: UInt8...) -> Bool {
            guard at + word.count <= bytes.count else { return false }
            for (offset, byte) in word.enumerated() where bytes[at + offset] != byte { return false }
            return true
        }

        private mutating func container(object: Bool, keyRange: Range<Int>?, depth: Int, build: Bool, levels: Int) throws(Failure) -> JSONNode? {
            let start = at
            let close: UInt8 = object ? 0x7D : 0x5D
            let expected = object ? "Expected a comma or }" : "Expected a comma or ]"
            at += 1
            var children: [JSONNode] = []
            let buildChildren = build && levels > 0
            try skip()
            while peek() != close {
                if object {
                    guard peek() == 0x22 else { throw Failure(peek() == nil ? expected : "Expected a key in quotes", at) }
                    let keyStart = at
                    try string()
                    let nameRange = keyStart..<at
                    try skip()
                    guard peek() == 0x3A else { throw Failure("Expected a colon after the key", at) }
                    at += 1
                    try skip()
                    if let child = try value(keyRange: nameRange, depth: depth + 1, build: buildChildren, levels: levels - 1) { children.append(child) }
                } else {
                    if let child = try value(keyRange: nil, depth: depth + 1, build: buildChildren, levels: levels - 1) { children.append(child) }
                }
                try skip()
                if peek() == 0x2C {
                    at += 1
                    try skip()
                } else if peek() != close {
                    throw Failure(expected, at)
                }
            }
            at += 1
            guard build else { return nil }
            let node = JSONNode(kind: object ? .object : .array, keyRange: keyRange, valueRange: start..<at, source: source)
            if buildChildren { node.adopt(children) }
            return node
        }

        /// Moves past a quoted string, checking its escapes; `decodeString` reads it when it's shown.
        private mutating func string() throws(Failure) {
            let start = at
            at += 1
            while at < bytes.count {
                let byte = bytes[at]
                at += 1
                if byte == 0x22 { return }
                guard byte == 0x5C, at < bytes.count else { continue }
                if bytes[at] == 0x75 {
                    at += 1
                    guard hex4() != nil else { throw Failure("Expected four hex digits after \\u", at) }
                } else {
                    at += 1
                }
            }
            throw Failure("This string has no closing quote", start)
        }

        private mutating func hex4() -> UInt32? {
            guard at + 4 <= bytes.count, let value = UInt32(String(decoding: bytes[at..<at + 4], as: UTF8.self), radix: 16) else { return nil }
            at += 4
            return value
        }
    }
}

/// A change to the text: the bytes in `range` replaced.
nonisolated struct TextChange: Equatable, Sendable {
    let range: Range<Int>
    let replacement: String
}

/// Tree edits as text changes that touch only the edited part, keeping comments and formatting elsewhere.
nonisolated enum JSONEdits {
    /// A string stays a string; anything else takes a number, true, false or null typed as one, and a string otherwise.
    static func setValue(_ node: JSONNode, typed: String) -> TextChange {
        let trimmed = typed.trimmingCharacters(in: .whitespaces)
        let literal = node.kind != .string && isScalar(trimmed) ? trimmed : quoted(typed)
        return TextChange(range: node.valueRange, replacement: literal)
    }

    static func rename(_ node: JSONNode, to name: String) -> TextChange {
        TextChange(range: node.keyRange ?? node.valueRange.lowerBound..<node.valueRange.lowerBound, replacement: quoted(name))
    }

    /// Removes the member with its comma, and its line when it had one to itself. Two changes when the member is the
    /// last: the comma before it and the member, so a comment between them stays.
    static func delete(_ node: JSONNode, in text: String) -> [TextChange] {
        let bytes = Array(text.utf8)
        let start = node.start, end = node.valueRange.upperBound
        if let comma = comma(after: end, in: bytes) {
            var next = comma + 1
            while next < bytes.count, bytes[next] == 0x20 || bytes[next] == 0x09 { next += 1 }
            if isBlank(before: start, in: bytes), let lineEnd = lineEnd(at: next, in: bytes) {
                return [TextChange(range: lineStart(of: start, in: bytes)..<lineEnd, replacement: "")]
            }
            return [TextChange(range: start..<next, replacement: "")]
        }
        if let parent = node.parent, node.index > 0, let comma = comma(after: parent.children[node.index - 1].valueRange.upperBound, in: bytes) {
            guard isBlank(before: start, in: bytes) else { return [TextChange(range: comma..<end, replacement: "")] }
            // From the line break before the member's line, so the line goes and whatever followed the comma stays.
            var lineBreak = lineStart(of: start, in: bytes) - 1
            if lineBreak > 0, bytes[lineBreak - 1] == 0x0D { lineBreak -= 1 }
            return [TextChange(range: lineBreak..<end, replacement: ""), TextChange(range: comma..<comma + 1, replacement: "")]
        }
        var after = end
        while after < bytes.count, bytes[after] == 0x20 || bytes[after] == 0x09 { after += 1 }
        if isBlank(before: start, in: bytes), after < bytes.count, let lineEnd = lineEnd(at: after, in: bytes) {
            return [TextChange(range: lineStart(of: start, in: bytes)..<lineEnd, replacement: "")]
        }
        return [TextChange(range: start..<end, replacement: "")]
    }

    /// A new member after `sibling`: `"key": null`, or `null` in an array, on its own line at the sibling's
    /// indentation, or on the same line in a one-line object or array.
    static func insert(after sibling: JSONNode, key: String?, in text: String) -> TextChange {
        let bytes = Array(text.utf8)
        let member = key.map { "\(quoted($0)): null" } ?? "null"
        let end = sibling.valueRange.upperBound
        let oneLine = sibling.parent.map { !bytes[$0.valueRange].contains(0x0A) } ?? true
        let separator = oneLine ? ", " : ",\n" + indent(at: sibling.start, in: bytes)
        return TextChange(range: end..<end, replacement: separator + member)
    }

    /// A new member at the end of `container`.
    static func addChild(to container: JSONNode, key: String?, in text: String) -> TextChange {
        if let last = container.children.last { return insert(after: last, key: key, in: text) }
        let bytes = Array(text.utf8)
        let member = key.map { "\(quoted($0)): null" } ?? "null"
        let inner = container.valueRange.lowerBound + 1..<container.valueRange.upperBound - 1
        let multiline = bytes[inner].contains(0x0A)
        let outer = indent(at: container.start, in: bytes)
        // Whitespace inside is replaced; a comment inside stays, with the member after it.
        let from = bytes[inner].lastIndex { ![0x20, 0x09, 0x0A, 0x0D].contains($0) }.map { $0 + 1 } ?? inner.lowerBound
        let lead = from == inner.lowerBound ? "" : " "
        guard multiline else { return TextChange(range: from..<inner.upperBound, replacement: lead + member + (lead.isEmpty ? "" : " ")) }
        return TextChange(range: from..<inner.upperBound, replacement: "\n" + outer + unit(in: bytes) + member + "\n" + indent(at: inner.upperBound, in: bytes))
    }

    /// Moves a member to `index` among its siblings. The text between members (commas, comments, line breaks) stays
    /// where it is; only the members change places.
    static func move(_ node: JSONNode, to index: Int, in text: String) -> TextChange {
        guard let parent = node.parent, let first = parent.children.first, let last = parent.children.last else {
            return TextChange(range: node.start..<node.start, replacement: "")
        }
        let bytes = Array(text.utf8)
        var order = parent.children
        order.remove(at: node.index)
        order.insert(node, at: min(max(index, 0), order.count))
        var out: [UInt8] = []
        for (slot, member) in order.enumerated() {
            out += bytes[member.start..<member.valueRange.upperBound]
            if slot + 1 < parent.children.count {
                out += bytes[parent.children[slot].valueRange.upperBound..<parent.children[slot + 1].start]
            }
        }
        return TextChange(range: first.start..<last.valueRange.upperBound, replacement: String(decoding: out, as: UTF8.self))
    }

    /// "key", or "key 2", "key 3"… when that's taken.
    static func freshKey(in container: JSONNode) -> String {
        let taken = Set(container.children.compactMap(\.key))
        var name = "key", number = 1
        while taken.contains(name) {
            number += 1
            name = "key \(number)"
        }
        return name
    }

    static func quoted(_ string: String) -> String {
        var out = "\""
        for scalar in string.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case let s where s.value < 0x20: out += String(format: "\\u%04x", s.value)
            default: out.unicodeScalars.append(scalar)
            }
        }
        return out + "\""
    }

    private static func isScalar(_ text: String) -> Bool {
        if ["true", "false", "null"].contains(text) { return true }
        return text.range(of: #"^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?$"#, options: .regularExpression) != nil
    }

    /// The comma right after `offset`, past spaces and line breaks only.
    private static func comma(after offset: Int, in bytes: [UInt8]) -> Int? {
        var at = offset
        while at < bytes.count {
            if [0x20, 0x09, 0x0A, 0x0D].contains(bytes[at]) {
                at += 1
            } else if bytes[at] == 0x2F, at + 1 < bytes.count, bytes[at + 1] == 0x2F {
                while at < bytes.count, bytes[at] != 0x0A { at += 1 }
            } else if bytes[at] == 0x2F, at + 1 < bytes.count, bytes[at + 1] == 0x2A {
                at += 2
                while at + 1 < bytes.count, !(bytes[at] == 0x2A && bytes[at + 1] == 0x2F) { at += 1 }
                at += 2
            } else {
                break
            }
        }
        return at < bytes.count && bytes[at] == 0x2C ? at : nil
    }

    /// Just past the line break at `offset` (LF or CRLF), or the end of the text; nil when the line goes on.
    private static func lineEnd(at offset: Int, in bytes: [UInt8]) -> Int? {
        if offset >= bytes.count { return bytes.count }
        if bytes[offset] == 0x0A { return offset + 1 }
        if bytes[offset] == 0x0D, offset + 1 < bytes.count, bytes[offset + 1] == 0x0A { return offset + 2 }
        return nil
    }

    private static func lineStart(of offset: Int, in bytes: [UInt8]) -> Int {
        (bytes[..<offset].lastIndex(of: 0x0A)).map { $0 + 1 } ?? 0
    }

    private static func isBlank(before offset: Int, in bytes: [UInt8]) -> Bool {
        bytes[lineStart(of: offset, in: bytes)..<offset].allSatisfy { $0 == 0x20 || $0 == 0x09 }
    }

    private static func indent(at offset: Int, in bytes: [UInt8]) -> String {
        let start = lineStart(of: offset, in: bytes)
        return String(decoding: bytes[start...].prefix { $0 == 0x20 || $0 == 0x09 }, as: UTF8.self)
    }

    /// The file's indentation step: its first indented line's, or two spaces.
    private static func unit(in bytes: [UInt8]) -> String {
        for (index, byte) in bytes.enumerated() where byte == 0x0A {
            let indent = bytes[(index + 1)...].prefix { $0 == 0x20 || $0 == 0x09 }
            if !indent.isEmpty, index + 1 + indent.count < bytes.count, bytes[index + 1 + indent.count] != 0x0A {
                return String(decoding: indent, as: UTF8.self)
            }
        }
        return "  "
    }
}
