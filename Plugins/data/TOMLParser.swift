import Foundation

/// A TOML reader for the tree: tables, arrays of tables, dotted and quoted keys, inline tables, arrays, every string
/// form, numbers, booleans and dates. Numbers and dates keep the text as written. Inline tables and arrays may span
/// lines, as TOML 1.1 allows.
nonisolated enum TOMLParser {

    static func parse(_ text: String) -> Result<DataNode, SyntaxError> {
        let bytes = Array(text.utf8)
        var reader = Reader(bytes: bytes)
        do throws(ParseFailure) {
            return .success(try reader.document())
        } catch {
            return .failure(SyntaxError(error.message, at: error.offset, in: bytes))
        }
    }


    /// A table while the file is read: a later `[a.b]` can still add to a table opened earlier, so nodes are made at
    /// the end.
    fileprivate final class Table {
        enum Origin { case implicit, dotted, header }
        var origin: Origin
        var start: Int
        let depth: Int
        var entries: [(name: String, member: Member)] = []
        var index: [String: Int] = [:]
        init(_ origin: Origin, start: Int, depth: Int) {
            self.origin = origin
            self.start = start
            self.depth = depth
        }

        func member(_ name: String) -> Member? { index[name].map { entries[$0].member } }
        func add(_ name: String, _ member: Member) {
            index[name] = entries.count
            entries.append((name, member))
        }

        func node(key: String?) -> DataNode {
            let children = entries.map { name, member in
                switch member {
                case .value(let node): node
                case .table(let table): table.node(key: name)
                case .tables(let list): DataNode(kind: .array, key: name, value: nil, start: list.start, children: list.tables.map { $0.node(key: nil) })
                }
            }
            return DataNode(kind: .object, key: key, value: nil, start: start, children: children)
        }
    }

    /// An array of tables, made by `[[name]]` headers.
    fileprivate final class TableList {
        let start: Int
        var tables: [Table]
        init(start: Int, first: Table) {
            self.start = start
            tables = [first]
        }
    }

    /// Inline tables and arrays are closed when read, so they're stored as finished nodes and can't be added to.
    fileprivate enum Member {
        case value(DataNode)
        case table(Table)
        case tables(TableList)
    }

    fileprivate typealias Key = [(name: String, start: Int)]

    fileprivate struct Reader {
        let bytes: [UInt8]
        var at = 0

        func peek(_ ahead: Int = 0) -> UInt8? { at + ahead < bytes.count ? bytes[at + ahead] : nil }

        mutating func document() throws(ParseFailure) -> DataNode {
            if bytes.starts(with: [0xEF, 0xBB, 0xBF]) { at = 3 }
            let root = Table(.header, start: 0, depth: 0)
            var current = root, path: [String] = []
            while true {
                skipBlank()
                guard let byte = peek() else { break }
                if byte == 0x5B {
                    (current, path) = try header(in: root)
                } else {
                    try keyValue(into: current, path: path)
                }
                try endOfLine()
            }
            return root.node(key: nil)
        }

        /// Spaces and tabs.
        mutating func skipSpaces() {
            while let byte = peek(), byte == 0x20 || byte == 0x09 { at += 1 }
        }

        /// Spaces, line breaks and comments.
        mutating func skipBlank() {
            while let byte = peek() {
                if byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D {
                    at += 1
                } else if byte == 0x23 {
                    while let next = peek(), next != 0x0A { at += 1 }
                } else {
                    return
                }
            }
        }

        mutating func endOfLine() throws(ParseFailure) {
            skipSpaces()
            if peek() == 0x23 { while let next = peek(), next != 0x0A { at += 1 } }
            if peek() == 0x0D, peek(1) == 0x0A { at += 1 }
            guard let byte = peek() else { return }
            guard byte == 0x0A else { throw ParseFailure("Expected the end of the line", at) }
            at += 1
        }

        /// `[a.b]` or `[[a.b]]`: the table that the following lines fill, and its path for messages.
        mutating func header(in root: Table) throws(ParseFailure) -> (Table, [String]) {
            let start = at
            let list = peek(1) == 0x5B
            at += list ? 2 : 1
            skipSpaces()
            let key = try self.key()
            skipSpaces()
            guard peek() == 0x5D, !list || peek(1) == 0x5D else { throw ParseFailure(list ? "Expected ]] after the table name" : "Expected ] after the table name", at) }
            at += list ? 2 : 1
            let names = key.map(\.name)
            var table = root
            for (name, keyStart) in key.dropLast() {
                switch table.member(name) {
                case .table(let next)?: table = next
                case .tables(let next)?: table = next.tables[next.tables.count - 1]
                case .value?: throw ParseFailure("Key \(name) is defined twice", keyStart)
                case nil:
                    let next = try Table(.implicit, start: keyStart, depth: deeper(table.depth, keyStart))
                    table.add(name, .table(next))
                    table = next
                }
            }
            let (name, keyStart) = key[key.count - 1]
            let twice = "Table [\(names.joined(separator: "."))] is defined twice"
            switch table.member(name) {
            case .value?: throw ParseFailure("Key \(name) is defined twice", keyStart)
            case .table(let made)? where !list && made.origin == .implicit:
                made.origin = .header
                made.start = start
                return (made, names)
            case .tables(let made)? where list:
                let next = try Table(.header, start: start, depth: deeper(table.depth + 1, start))
                made.tables.append(next)
                return (next, names)
            case .table?, .tables?: throw ParseFailure(twice, start)
            case nil:
                if list {
                    let next = try Table(.header, start: start, depth: deeper(table.depth + 1, start))
                    table.add(name, .tables(TableList(start: start, first: next)))
                    return (next, names)
                }
                let next = try Table(.header, start: start, depth: deeper(table.depth, start))
                table.add(name, .table(next))
                return (next, names)
            }
        }

        func deeper(_ depth: Int, _ offset: Int) throws(ParseFailure) -> Int {
            guard depth + 1 < DataNode.maxDepth else { throw ParseFailure("Nested too deeply", offset) }
            return depth + 1
        }

        /// `a.b = value`, its dotted parts making tables inside `table`.
        mutating func keyValue(into table: Table, path: [String]) throws(ParseFailure) {
            let key = try self.key()
            skipSpaces()
            guard peek() == 0x3D else { throw ParseFailure("Expected = after the key", at) }
            at += 1
            skipSpaces()
            var table = table
            for (index, (name, keyStart)) in key.dropLast().enumerated() {
                switch table.member(name) {
                case .table(let next)? where next.origin != .header: table = next
                case .table?: throw ParseFailure("Table [\((path + key[...index].map(\.name)).joined(separator: "."))] is defined twice", keyStart)
                case .tables?, .value?: throw ParseFailure("Key \(name) is defined twice", keyStart)
                case nil:
                    let next = try Table(.dotted, start: keyStart, depth: deeper(table.depth, keyStart))
                    table.add(name, .table(next))
                    table = next
                }
            }
            let (name, keyStart) = key[key.count - 1]
            switch table.member(name) {
            case .value?: throw ParseFailure("Key \(name) is defined twice", keyStart)
            case .table?, .tables?: throw ParseFailure("Table [\((path + key.map(\.name)).joined(separator: "."))] is defined twice", keyStart)
            case nil: table.add(name, .value(try value(key: name, start: keyStart, depth: table.depth + 1)))
            }
        }

        /// A bare, quoted or dotted key.
        mutating func key() throws(ParseFailure) -> Key {
            var key: Key = []
            while true {
                let start = at
                switch peek() {
                case 0x22?, 0x27?: key.append((try string(multiline: false), start))
                default:
                    while let byte = peek(), Reader.isBare(byte) { at += 1 }
                    guard at > start else { throw ParseFailure("Expected a key", at) }
                    key.append((String(decoding: bytes[start..<at], as: UTF8.self), start))
                }
                skipSpaces()
                guard peek() == 0x2E else { return key }
                at += 1
                skipSpaces()
            }
        }

        static func isBare(_ byte: UInt8) -> Bool {
            (0x30...0x39).contains(byte) || (0x41...0x5A).contains(byte) || (0x61...0x7A).contains(byte) || byte == 0x5F || byte == 0x2D
        }

        mutating func value(key: String?, start: Int, depth: Int) throws(ParseFailure) -> DataNode {
            guard depth < DataNode.maxDepth else { throw ParseFailure("Nested too deeply", at) }
            let begin = at
            switch peek() {
            case 0x22?, 0x27?: return DataNode(kind: .string, key: key, value: try string(multiline: true), start: start)
            case 0x5B?: return try array(key: key, start: start, depth: depth)
            case 0x7B?: return try inlineTable(key: key, start: start, depth: depth)
            default: break
            }
            while let byte = peek(), Reader.isToken(byte) {
                at += 1
                // The space form of a date-time: `1979-05-27 07:32:00`.
                if at - begin == 10, peek() == 0x20, let next = peek(1), (0x30...0x39).contains(next), peek(3) == 0x3A, TOMLParser.isDateTime(bytes[begin..<at]) { at += 1 }
            }
            let token = bytes[begin..<at]
            guard let first = token.first else { throw ParseFailure("Expected a value", begin) }
            let text = String(decoding: token, as: UTF8.self)
            if text == "true" || text == "false" { return DataNode(kind: .bool, key: key, value: text, start: start) }
            if TOMLParser.isNumber(token) { return DataNode(kind: .number, key: key, value: text, start: start) }
            if TOMLParser.isDateTime(token) { return DataNode(kind: .string, key: key, value: text, start: start) }
            let letter = first != 0x2B && first != 0x2D && !(0x30...0x39).contains(first)
            throw ParseFailure(letter ? "Expected a value" : "This isn't a number or a date", begin)
        }

        static func isToken(_ byte: UInt8) -> Bool {
            isBare(byte) || byte == 0x2B || byte == 0x2E || byte == 0x3A
        }

        mutating func array(key: String?, start: Int, depth: Int) throws(ParseFailure) -> DataNode {
            at += 1
            var items: [DataNode] = []
            while true {
                skipBlank()
                if peek() == 0x5D { break }
                guard peek() != nil else { throw ParseFailure("Expected a comma or ]", at) }
                items.append(try value(key: nil, start: at, depth: depth + 1))
                skipBlank()
                if peek() == 0x2C {
                    at += 1
                } else if peek() != 0x5D {
                    throw ParseFailure("Expected a comma or ]", at)
                }
            }
            at += 1
            return DataNode(kind: .array, key: key, value: nil, start: start, children: items)
        }

        mutating func inlineTable(key: String?, start: Int, depth: Int) throws(ParseFailure) -> DataNode {
            at += 1
            let table = Table(.dotted, start: start, depth: depth)
            while true {
                skipBlank()
                if peek() == 0x7D { break }
                guard peek() != nil else { throw ParseFailure("Expected a comma or }", at) }
                try keyValue(into: table, path: [])
                skipBlank()
                if peek() == 0x2C {
                    at += 1
                } else if peek() != 0x7D {
                    throw ParseFailure("Expected a comma or }", at)
                }
            }
            at += 1
            return table.node(key: key)
        }

        /// A basic or literal string, decoded; with `multiline`, also the `"""` and `'''` forms. The text is copied into
        /// a buffer only from the first escape on.
        mutating func string(multiline allowed: Bool) throws(ParseFailure) -> String {
            let start = at, quote = bytes[at]
            let multiline = allowed && peek(1) == quote && peek(2) == quote
            at += multiline ? 3 : 1
            if multiline {
                if peek() == 0x0D, peek(1) == 0x0A { at += 2 } else if peek() == 0x0A { at += 1 }
            }
            var out: [UInt8] = [], buffered = false, from = at
            while at < bytes.count {
                let byte = bytes[at]
                if byte == quote {
                    var end = at
                    if multiline {
                        var quotes = 0
                        while peek(quotes) == quote { quotes += 1 }
                        guard quotes >= 3 else { at += quotes; continue }
                        // Up to two quotes may sit right before the closing three.
                        end = at + min(quotes - 3, 2)
                        at = end + 3
                    } else {
                        at += 1
                    }
                    guard buffered else { return String(decoding: bytes[from..<end], as: UTF8.self) }
                    out += bytes[from..<end]
                    return String(decoding: out, as: UTF8.self)
                }
                if byte == 0x5C, quote == 0x22 {
                    out += bytes[from..<at]
                    buffered = true
                    try escape(into: &out, multiline: multiline)
                    from = at
                    continue
                }
                if byte == 0x0A, !multiline { break }
                at += 1
            }
            throw ParseFailure("This string has no closing quote", start)
        }

        mutating func escape(into out: inout [UInt8], multiline: Bool) throws(ParseFailure) {
            let start = at
            guard let code = peek(1) else { throw ParseFailure("This string has no closing quote", start) }
            at += 2
            switch code {
            case 0x62: out.append(0x08)  // b
            case 0x74: out.append(0x09)  // t
            case 0x6E: out.append(0x0A)  // n
            case 0x66: out.append(0x0C)  // f
            case 0x72: out.append(0x0D)  // r
            case 0x65: out.append(0x1B)  // e
            case 0x22, 0x5C: out.append(code)
            case 0x75, 0x55, 0x78:  // u, U, x
                let count = code == 0x75 ? 4 : code == 0x55 ? 8 : 2
                guard at + count <= bytes.count, let value = Reader.hex(bytes[at..<at + count]), let scalar = Unicode.Scalar(value) else {
                    throw ParseFailure("This escape isn't valid", start)
                }
                at += count
                UTF8.encode(scalar) { out.append($0) }
            case 0x20, 0x09, 0x0D, 0x0A:
                // A backslash at the end of a line trims the break and the whitespace after it.
                guard multiline else { throw ParseFailure("This escape isn't valid", start) }
                at -= 1
                skipSpaces()
                guard peek() == 0x0A || (peek() == 0x0D && peek(1) == 0x0A) else { throw ParseFailure("This escape isn't valid", start) }
                while let byte = peek(), byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D { at += 1 }
            default: throw ParseFailure("This escape isn't valid", start)
            }
        }

        static func hex(_ digits: ArraySlice<UInt8>) -> UInt32? {
            var value: UInt32 = 0
            for byte in digits {
                let digit: UInt8
                switch byte {
                case 0x30...0x39: digit = byte - 0x30
                case 0x41...0x46: digit = byte - 0x37
                case 0x61...0x66: digit = byte - 0x57
                default: return nil
                }
                value = value << 4 | UInt32(digit)
            }
            return value
        }
    }

    /// TOML's integers and floats: decimal with `_` between digits, `0x`, `0o` and `0b`, fractions, exponents, `inf`
    /// and `nan`, each signed but the prefixed ones.
    static func isNumber(_ token: ArraySlice<UInt8>) -> Bool {
        var at = token.startIndex
        let end = token.endIndex
        func run(_ valid: (UInt8) -> Bool) -> Bool {
            guard at < end, valid(token[at]) else { return false }
            at += 1
            while at < end {
                if valid(token[at]) {
                    at += 1
                } else if token[at] == 0x5F, at + 1 < end, valid(token[at + 1]) {
                    at += 2
                } else {
                    break
                }
            }
            return true
        }
        let decimal: (UInt8) -> Bool = { (0x30...0x39).contains($0) }
        let signed = at < end && (token[at] == 0x2B || token[at] == 0x2D)
        if signed { at += 1 }
        let rest = token[at...]
        if rest.elementsEqual("inf".utf8) || rest.elementsEqual("nan".utf8) { return true }
        if !signed, rest.count > 2, token[at] == 0x30 {
            let radix: ((UInt8) -> Bool)? = switch token[at + 1] {
            case 0x78: { (0x30...0x39).contains($0) || (0x41...0x46).contains($0) || (0x61...0x66).contains($0) }
            case 0x6F: { (0x30...0x37).contains($0) }
            case 0x62: { $0 == 0x30 || $0 == 0x31 }
            default: nil
            }
            if let radix {
                at += 2
                return run(radix) && at == end
            }
        }
        let whole = at
        guard run(decimal), token[whole] != 0x30 || at - whole == 1 else { return false }
        if at < end, token[at] == 0x2E {
            at += 1
            guard run(decimal) else { return false }
        }
        if at < end, token[at] == 0x65 || token[at] == 0x45 {
            at += 1
            if at < end, token[at] == 0x2B || token[at] == 0x2D { at += 1 }
            guard run(decimal) else { return false }
        }
        return at == end
    }

    /// A date `1979-05-27`, a time `07:32:00.5`, or both joined by `T` or a space, with an optional `Z` or `+09:00`.
    /// Seconds may be left out, as TOML 1.1 allows.
    static func isDateTime(_ token: ArraySlice<UInt8>) -> Bool {
        var at = token.startIndex
        let end = token.endIndex
        func digits(_ count: Int) -> Bool {
            guard at + count <= end, token[at..<at + count].allSatisfy({ (0x30...0x39).contains($0) }) else { return false }
            at += count
            return true
        }
        func byte(_ value: UInt8) -> Bool {
            guard at < end, token[at] == value else { return false }
            at += 1
            return true
        }
        let dated = digits(4) && byte(0x2D) && digits(2) && byte(0x2D) && digits(2)
        if dated {
            if at == end { return true }
            guard byte(0x54) || byte(0x74) || byte(0x20) else { return false }
        } else {
            at = token.startIndex
        }
        guard digits(2), byte(0x3A), digits(2) else { return false }
        if byte(0x3A) {
            guard digits(2) else { return false }
            if byte(0x2E) {
                guard digits(1) else { return false }
                while at < end, (0x30...0x39).contains(token[at]) { at += 1 }
            }
        }
        if at == end { return true }
        guard dated else { return false }
        if byte(0x5A) || byte(0x7A) { return at == end }
        guard byte(0x2B) || byte(0x2D), digits(2), byte(0x3A), digits(2) else { return false }
        return at == end
    }
}
