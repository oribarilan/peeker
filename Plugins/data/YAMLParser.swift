import Foundation

/// A small YAML reader for showing a file as a tree. It reads block and flow collections, every scalar style,
/// comments and several documents; anchors and tags are dropped and aliases shown as written. Complex keys (`?`) are
/// reported, not read. Everything is read from the UTF-8 bytes, and each key and scalar is decoded once.
nonisolated enum YAMLParser {
    static func parse(_ text: String) -> Result<DataNode, SyntaxError> {
        let bytes = Array(text.utf8)
        var reader = Reader(bytes: bytes)
        do throws(ParseFailure) {
            return .success(try reader.stream())
        } catch {
            return .failure(SyntaxError(error.message, at: error.offset, in: bytes))
        }
    }

    /// A mapping key found on a line: its name, where it starts, and just past its colon.
    struct Key {
        let name: String
        let start: Int
        let end: Int
    }

    /// Reads with one cursor. Each block-level step returns with the cursor on the next line's first character that
    /// isn't a space or part of a comment, so the caller compares columns to see whether it owns that line.
    struct Reader {
        let bytes: [UInt8]
        var at = 0
        /// Where the cursor's line starts, for columns.
        var lineStart = 0

        init(bytes: [UInt8]) {
            self.bytes = bytes
            if bytes.starts(with: [0xEF, 0xBB, 0xBF]) { at = 3 }
            lineStart = at
        }

        /// The documents: one is the root, several are the root's items, none is an empty mapping.
        mutating func stream() throws(ParseFailure) -> DataNode {
            var documents: [DataNode] = []
            var lastWasEmpty = false
            while true {
                try skipToContent(directives: true)
                guard at < bytes.count else { break }
                if isMarker(UInt8(ascii: ".")) {
                    at += 3
                    try endLine()
                    continue
                }
                let start = at
                if isMarker(UInt8(ascii: "-")) {
                    at += 3
                    skipSpaces()
                    if atLineEnd() {
                        try endLine()
                        try skipToContent()
                    }
                }
                lastWasEmpty = indent() < 0
                let root =
                    lastWasEmpty ? DataNode(kind: .null, key: nil, value: "", start: start) : try block(parent: -1, key: nil, start: at, depth: 0)
                if at < bytes.count, indent() >= 0 { throw ParseFailure("Unexpected text after the value", at) }
                documents.append(root)
            }
            if documents.count > 1 { return DataNode(kind: .array, key: nil, value: nil, start: 0, children: documents) }
            if let only = documents.first, !lastWasEmpty { return only }
            return DataNode(kind: .object, key: nil, value: nil, start: 0)
        }

        /// A node at the cursor whose parent sits at column `parent`: a mapping, a sequence or a scalar, which may
        /// start mid-line after a `-`.
        mutating func block(parent: Int, key: String?, start: Int, depth: Int, asString: Bool = false) throws(ParseFailure) -> DataNode {
            guard depth < DataNode.maxDepth else { throw ParseFailure("Nested too deeply", at) }
            let column = at - lineStart
            let asString = properties(flow: false) || asString
            if atLineEnd() {
                try endLine()
                try skipToContent()
                return try nested(parent: parent, sameIndentList: false, key: key, start: start, depth: depth + 1, asString: asString)
            }
            if isIndicator(UInt8(ascii: "-")) { return try sequence(column: column, key: key, start: start, depth: depth, sharesIndent: false) }
            if isIndicator(UInt8(ascii: "?")) { throw complexKey() }
            if let first = mappingKey() {
                return try mapping(column: column, first: first, key: key, start: start, depth: depth)
            }
            return try inline(parent: parent, key: key, start: start, depth: depth, asString: asString)
        }

        /// What follows a key or dash that ends its line: a more indented block, a list at the key's own indent, or
        /// nothing.
        mutating func nested(parent: Int, sameIndentList: Bool, key: String?, start: Int, depth: Int, asString: Bool) throws(ParseFailure) -> DataNode
        {
            let column = indent()
            if column > parent { return try block(parent: parent, key: key, start: start, depth: depth, asString: asString) }
            if sameIndentList, column == parent, isIndicator(UInt8(ascii: "-")) {
                return try sequence(column: column, key: key, start: start, depth: depth, sharesIndent: true)
            }
            return DataNode(kind: asString ? .string : .null, key: key, value: "", start: start)
        }

        mutating func mapping(column: Int, first: Key, key: String?, start: Int, depth: Int) throws(ParseFailure) -> DataNode {
            var children: [DataNode] = []
            var entry = first
            while true {
                at = entry.end
                skipSpaces()
                let asString = properties(flow: false)
                let child: DataNode
                if atLineEnd() {
                    try endLine()
                    try skipToContent()
                    child = try nested(
                        parent: column, sameIndentList: true, key: entry.name, start: entry.start, depth: depth + 1, asString: asString)
                } else {
                    child = try inline(parent: column, key: entry.name, start: entry.start, depth: depth + 1, asString: asString)
                }
                children.append(child)
                let next = indent()
                if next < column { break }
                if next > column { throw misaligned(after: child) }
                _ = properties(flow: false)
                guard let found = mappingKey() else {
                    throw isIndicator(UInt8(ascii: "?")) ? complexKey() : ParseFailure("Expected a key and a colon", at)
                }
                entry = found
            }
            return DataNode(kind: .object, key: key, value: nil, start: start, children: children)
        }

        /// A list of `-` items at `column`. One that shares its column with the key it belongs to ends at the next
        /// line there that isn't an item; any other must go on with items.
        mutating func sequence(column: Int, key: String?, start: Int, depth: Int, sharesIndent: Bool) throws(ParseFailure) -> DataNode {
            var children: [DataNode] = []
            while true {
                let dash = at
                at += 1
                skipSpaces()
                let child: DataNode
                if atLineEnd() {
                    try endLine()
                    try skipToContent()
                    child = try nested(parent: column, sameIndentList: false, key: nil, start: dash, depth: depth + 1, asString: false)
                } else {
                    child = try block(parent: column, key: nil, start: dash, depth: depth + 1)
                }
                children.append(child)
                let next = indent()
                if next < column { break }
                if next > column { throw misaligned(after: child) }
                guard isIndicator(UInt8(ascii: "-")) else {
                    if sharesIndent { break }
                    throw ParseFailure("Expected - and a list item", at)
                }
            }
            return DataNode(kind: .array, key: key, value: nil, start: start, children: children)
        }

        /// A value that starts on the current line and isn't a block collection.
        mutating func inline(parent: Int, key: String?, start: Int, depth: Int, asString: Bool) throws(ParseFailure) -> DataNode {
            let node: DataNode
            switch bytes[at] {
            case UInt8(ascii: "["), UInt8(ascii: "{"):
                node = try flow(key: key, start: start, depth: depth)
            case UInt8(ascii: "\""), UInt8(ascii: "'"):
                node = DataNode(kind: .string, key: key, value: try quoted(), start: start)
            case UInt8(ascii: "|"), UInt8(ascii: ">"):
                return try blockScalar(parent: parent, key: key, start: start)
            case UInt8(ascii: "*"):
                node = DataNode(kind: .string, key: key, value: alias(flow: false), start: start)
            default:
                return try plain(parent: parent, key: key, start: start, asString: asString)
            }
            try endLine()
            try skipToContent()
            return node
        }

        /// The key at the cursor when the line is `key: …`, without moving: plain or quoted, ending at a colon followed
        /// by a space or the line's end.
        func mappingKey() -> Key? {
            let start = at
            guard start < bytes.count else { return nil }
            var colon: Int
            let name: String
            switch bytes[start] {
            case UInt8(ascii: "\""), UInt8(ascii: "'"):
                guard let close = quotedEnd(from: start, singleLine: true) else { return nil }
                colon = close
                while colon < bytes.count, bytes[colon] == 0x20 || bytes[colon] == 0x09 { colon += 1 }
                guard colon < bytes.count, bytes[colon] == UInt8(ascii: ":"), isSeparator(colon + 1) else { return nil }
                name = decodeQuoted(start..<close)
            case UInt8(ascii: "["), UInt8(ascii: "{"), UInt8(ascii: "|"), UInt8(ascii: ">"), UInt8(ascii: "*"), UInt8(ascii: "#"),
                UInt8(ascii: "&"), UInt8(ascii: "!"), UInt8(ascii: "%"), UInt8(ascii: "@"), UInt8(ascii: "`"):
                return nil
            default:
                if isIndicator(UInt8(ascii: "-")) || isIndicator(UInt8(ascii: "?")) { return nil }
                colon = start
                var last = start
                while colon < bytes.count {
                    let byte = bytes[colon]
                    if byte == 0x0A || byte == 0x0D { return nil }
                    if byte == UInt8(ascii: ":"), isSeparator(colon + 1) { break }
                    if byte == UInt8(ascii: "#"), colon > start, bytes[colon - 1] == 0x20 || bytes[colon - 1] == 0x09 { return nil }
                    if byte != 0x20, byte != 0x09 { last = colon + 1 }
                    colon += 1
                }
                guard colon < bytes.count, last > start else { return nil }
                name = String(decoding: bytes[start..<last], as: UTF8.self)
            }
            return Key(name: name, start: start, end: colon + 1)
        }

        /// A `[…]` or `{…}` collection, which may span lines.
        mutating func flow(key: String?, start: Int, depth: Int) throws(ParseFailure) -> DataNode {
            guard depth < DataNode.maxDepth else { throw ParseFailure("Nested too deeply", at) }
            let object = bytes[at] == UInt8(ascii: "{")
            let close = object ? UInt8(ascii: "}") : UInt8(ascii: "]")
            let expected = object ? "Expected a comma or }" : "Expected a comma or ]"
            at += 1
            var children: [DataNode] = []
            while true {
                flowSkip()
                guard at < bytes.count else { throw ParseFailure(expected, at) }
                if bytes[at] == close {
                    at += 1
                    break
                }
                let item = at
                if object {
                    if isIndicator(UInt8(ascii: "?")) { throw complexKey() }
                    _ = properties(flow: true)
                    flowSkip()
                    guard at < bytes.count else { throw ParseFailure(expected, at) }
                    let name: String
                    switch bytes[at] {
                    case UInt8(ascii: "\""), UInt8(ascii: "'"): name = try quoted()
                    case UInt8(ascii: "["), UInt8(ascii: "{"), UInt8(ascii: ","), UInt8(ascii: "]"), UInt8(ascii: "}"), UInt8(ascii: ":"):
                        throw ParseFailure("Expected a key and a colon", at)
                    default: name = try flowPlain().text
                    }
                    flowSkip()
                    if at < bytes.count, bytes[at] == UInt8(ascii: ":") {
                        at += 1
                        flowSkip()
                        if at < bytes.count, bytes[at] != UInt8(ascii: ","), bytes[at] != close {
                            children.append(try flowValue(key: name, start: item, depth: depth + 1))
                        } else {
                            children.append(DataNode(kind: .null, key: name, value: "", start: item))
                        }
                    } else {
                        children.append(DataNode(kind: .null, key: name, value: "", start: item))
                    }
                } else {
                    children.append(try flowValue(key: nil, start: item, depth: depth + 1))
                }
                flowSkip()
                guard at < bytes.count else { throw ParseFailure(expected, at) }
                if bytes[at] == UInt8(ascii: ",") {
                    at += 1
                } else if bytes[at] != close {
                    throw ParseFailure(expected, at)
                }
            }
            return DataNode(kind: object ? .object : .array, key: key, value: nil, start: start, children: children)
        }

        mutating func flowValue(key: String?, start: Int, depth: Int) throws(ParseFailure) -> DataNode {
            let asString = properties(flow: true)
            flowSkip()
            guard at < bytes.count else { throw ParseFailure("Expected a value", at) }
            switch bytes[at] {
            case UInt8(ascii: "["), UInt8(ascii: "{"): return try flow(key: key, start: start, depth: depth)
            case UInt8(ascii: "\""), UInt8(ascii: "'"): return DataNode(kind: .string, key: key, value: try quoted(), start: start)
            case UInt8(ascii: "*"): return DataNode(kind: .string, key: key, value: alias(flow: true), start: start)
            case UInt8(ascii: ","), UInt8(ascii: "]"), UInt8(ascii: "}"): throw ParseFailure("Expected a value", at)
            default:
                let scalar = try flowPlain()
                return DataNode(kind: asString || scalar.multiline ? .string : kind(scalar.range), key: key, value: scalar.text, start: start)
            }
        }

        // MARK: Lines and separators

        /// The column of the line the cursor is on, or -1 at the end of the file or of a document.
        func indent() -> Int {
            guard at < bytes.count, !isMarker(UInt8(ascii: "-")), !isMarker(UInt8(ascii: ".")) else { return -1 }
            return at - lineStart
        }

        /// `---` or `...` at the start of the cursor's line.
        func isMarker(_ byte: UInt8) -> Bool { at == lineStart && isMarker(byte, at: at) }

        func isMarker(_ byte: UInt8, at position: Int) -> Bool {
            position + 3 <= bytes.count && bytes[position] == byte && bytes[position + 1] == byte && bytes[position + 2] == byte
                && isSeparator(position + 3)
        }

        /// `-` or `?` at the cursor, followed by a space or the line's end.
        func isIndicator(_ byte: UInt8) -> Bool { at < bytes.count && bytes[at] == byte && isSeparator(at + 1) }

        func isSeparator(_ position: Int) -> Bool {
            guard position < bytes.count else { return true }
            let byte = bytes[position]
            return byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D
        }

        func atLineEnd() -> Bool {
            at >= bytes.count || bytes[at] == 0x0A || bytes[at] == 0x0D || bytes[at] == UInt8(ascii: "#")
        }

        mutating func skipSpaces() {
            while at < bytes.count, bytes[at] == 0x20 || bytes[at] == 0x09 || bytes[at] == 0x0D { at += 1 }
        }

        /// The rest of the line, which may hold only spaces and a comment, and its line break.
        mutating func endLine() throws(ParseFailure) {
            skipSpaces()
            guard at < bytes.count else { return }
            if bytes[at] == UInt8(ascii: "#") {
                while at < bytes.count, bytes[at] != 0x0A { at += 1 }
            } else if bytes[at] != 0x0A {
                throw ParseFailure("Unexpected text after the value", at)
            }
            if at < bytes.count { at += 1 }
        }

        /// From a line's start, past blank and comment lines (and `%` directives between documents) to the next
        /// content.
        mutating func skipToContent(directives: Bool = false) throws(ParseFailure) {
            while at < bytes.count {
                lineStart = at
                var tab = -1
                while at < bytes.count, bytes[at] == 0x20 || bytes[at] == 0x09 || bytes[at] == 0x0D {
                    if bytes[at] == 0x09, tab < 0 { tab = at }
                    at += 1
                }
                guard at < bytes.count else { return }
                let byte = bytes[at]
                if byte == 0x0A {
                    at += 1
                    continue
                }
                if byte == UInt8(ascii: "#") || (directives && byte == UInt8(ascii: "%") && at == lineStart) {
                    while at < bytes.count, bytes[at] != 0x0A { at += 1 }
                    continue
                }
                if tab >= 0 { throw ParseFailure("Tabs can't indent YAML", tab) }
                return
            }
        }

        /// Spaces, line breaks and comments inside a flow collection.
        mutating func flowSkip() {
            while at < bytes.count {
                let byte = bytes[at]
                if byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D {
                    at += 1
                } else if byte == UInt8(ascii: "#") {
                    while at < bytes.count, bytes[at] != 0x0A { at += 1 }
                } else {
                    return
                }
            }
        }

        /// Skips anchors (`&name`) and tags (`!tag`, `!<…>`) before a node; true for `!!str`, which keeps a scalar a
        /// string.
        mutating func properties(flow: Bool) -> Bool {
            var asString = false
            while at < bytes.count, bytes[at] == UInt8(ascii: "&") || bytes[at] == UInt8(ascii: "!") {
                let start = at
                if at + 1 < bytes.count, bytes[at] == UInt8(ascii: "!"), bytes[at + 1] == UInt8(ascii: "<") {
                    while at < bytes.count, bytes[at] != UInt8(ascii: ">"), bytes[at] != 0x0A { at += 1 }
                }
                while !isSeparator(at), !(flow && isFlowIndicator(bytes[at])) { at += 1 }
                if bytes[start..<at].elementsEqual("!!str".utf8) { asString = true }
                skipSpaces()
            }
            return asString
        }

        /// `*name`, shown as written.
        mutating func alias(flow: Bool) -> String {
            let start = at
            at += 1
            while !isSeparator(at), !(flow && isFlowIndicator(bytes[at])) { at += 1 }
            return String(decoding: bytes[start..<at], as: UTF8.self)
        }

        func isFlowIndicator(_ byte: UInt8) -> Bool {
            byte == UInt8(ascii: ",") || byte == UInt8(ascii: "[") || byte == UInt8(ascii: "]") || byte == UInt8(ascii: "{")
                || byte == UInt8(ascii: "}")
        }

        func misaligned(after child: DataNode) -> ParseFailure {
            ParseFailure(child.isContainer ? "This line doesn't line up with the lines above" : "This line is indented more than the one above", at)
        }

        func complexKey() -> ParseFailure {
            ParseFailure.unsupported("a complex key (?)", at: at)
        }
    }
}
