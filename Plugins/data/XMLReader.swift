import Foundation

/// A small XML reader for the tree. Foundation's `XMLParser` reports attributes unordered, places as line and column,
/// and errors as numbered codes; this keeps attribute order and byte offsets and says what's wrong in words. Nothing
/// outside the file is ever loaded: only the five named entities and numeric references are expanded, so a doctype's
/// entities can't multiply or reach out.
nonisolated enum XMLReader {

    /// The element tree, or the property list's values when the root element is `plist`.
    static func parse(_ text: String) -> Result<DataNode, SyntaxError> {
        let bytes = Array(text.utf8)
        var reader = Reader(bytes: bytes)
        do throws(ParseFailure) {
            return .success(try reader.document())
        } catch {
            return .failure(SyntaxError(error.message, at: error.offset, in: bytes))
        }
    }


    struct Tag {
        /// The offset of its `<`.
        let start: Int
        let nameRange: Range<Int>
        let name: String
        let attributes: [Attribute]
        let selfClosing: Bool
    }

    struct Attribute {
        let name: Range<Int>
        /// Inside the quotes.
        let value: Range<Int>
        /// No entities or carriage returns, so the bytes are the value.
        let plain: Bool
    }

    /// The text between two tags, possibly broken by comments and CDATA sections. Only its span is kept, and it's
    /// decoded once, when it becomes a value.
    struct Run {
        var span: Range<Int>?
        var plain = true
        /// The first byte that isn't whitespace; nil while the run is blank.
        var visible: Int?

        mutating func add(_ range: Range<Int>, plain: Bool, visible: Int?) {
            if let span {
                self.span = span.lowerBound..<range.upperBound
                self.plain = false
            } else {
                span = range
                self.plain = plain
            }
            if self.visible == nil { self.visible = visible }
        }
    }

    enum Item { case open(Tag), close }

    static let commentOpen = Array("<!--".utf8), commentClose = Array("-->".utf8)
    static let cdataOpen = Array("<![CDATA[".utf8), cdataClose = Array("]]>".utf8)
    static let piClose = Array("?>".utf8), doctypeOpen = Array("<!DOCTYPE".utf8)

    static func isSpace(_ byte: UInt8) -> Bool { byte == 0x20 || byte == 0x0A || byte == 0x09 || byte == 0x0D }

    /// Lenient: anything but whitespace and the bytes that end a name.
    static func isNameByte(_ byte: UInt8) -> Bool {
        switch byte {
        case 0x20, 0x09, 0x0A, 0x0D, UInt8(ascii: "/"), UInt8(ascii: ">"), UInt8(ascii: "<"), UInt8(ascii: "="),
             UInt8(ascii: "\""), UInt8(ascii: "'"), UInt8(ascii: "&"), UInt8(ascii: "!"), UInt8(ascii: "?"): false
        default: true
        }
    }

    struct Reader {
        let bytes: [UInt8]
        var at = 0

        mutating func document() throws(ParseFailure) -> DataNode {
            if bytes.starts(with: [0xEF, 0xBB, 0xBF]) { at = 3 }
            try skipProlog()
            guard at + 1 < bytes.count, bytes[at] == UInt8(ascii: "<"), isNameByte(bytes[at + 1]) else { throw ParseFailure("Expected an element", at) }
            let tag = try startTag()
            let root = tag.name == "plist" ? try plist(tag) : try element(tag, depth: 0)
            try skipProlog()
            guard at == bytes.count else { throw ParseFailure("Unexpected text after the root element", at) }
            return root
        }

        /// Whitespace, comments, processing instructions and a doctype, around the root.
        private mutating func skipProlog() throws(ParseFailure) {
            while at < bytes.count {
                if isSpace(bytes[at]) {
                    at += 1
                } else if starts(commentOpen) {
                    try skipComment()
                } else if starts(doctypeOpen) {
                    try skipDoctype()
                } else if bytes[at] == UInt8(ascii: "<"), at + 1 < bytes.count, bytes[at + 1] == UInt8(ascii: "?") {
                    try skipInstruction()
                } else {
                    return
                }
            }
        }

        mutating func element(_ tag: Tag, depth: Int) throws(ParseFailure) -> DataNode {
            guard depth < DataNode.maxDepth else { throw ParseFailure("Nested too deeply", tag.start) }
            var children: [DataNode] = []
            for attribute in tag.attributes {
                children.append(DataNode(kind: .string, key: "@" + String(decoding: bytes[attribute.name], as: UTF8.self),
                                         value: attributeValue(attribute), start: attribute.name.lowerBound))
            }
            var run = Run(), hasElements = false
            if !tag.selfClosing {
                while case .open(let child) = try next(in: tag, run: &run) {
                    flush(&run, into: &children)
                    hasElements = true
                    children.append(try element(child, depth: depth + 1))
                }
            }
            if !hasElements, tag.attributes.isEmpty {
                return DataNode(kind: .string, key: tag.name, value: string(run, trim: true), start: tag.start)
            }
            flush(&run, into: &children)
            return DataNode(kind: .element, key: tag.name, value: nil, start: tag.start, children: children)
        }

        /// A text run that isn't blank, as a `#text` child.
        private func flush(_ run: inout Run, into children: inout [DataNode]) {
            if let visible = run.visible {
                children.append(DataNode(kind: .string, key: "#text", value: string(run, trim: true), start: visible))
            }
            run = Run()
        }

        /// Reads `tag`'s content up to its next child element, which it returns read, or past its end tag. Text and
        /// CDATA go into `run`; comments and processing instructions are skipped.
        mutating func next(in tag: Tag, run: inout Run) throws(ParseFailure) -> Item {
            while at < bytes.count {
                guard bytes[at] == UInt8(ascii: "<") else {
                    text(into: &run)
                    continue
                }
                switch at + 1 < bytes.count ? bytes[at + 1] : 0 {
                case UInt8(ascii: "/"):
                    try endTag(of: tag)
                    return .close
                case UInt8(ascii: "?"):
                    try skipInstruction()
                case UInt8(ascii: "!"):
                    if starts(commentOpen) {
                        try skipComment()
                    } else if starts(cdataOpen) {
                        try cdata(into: &run)
                    } else {
                        throw ParseFailure("Expected an element", at)
                    }
                default:
                    return .open(try startTag())
                }
            }
            throw ParseFailure("The file ends before <\(tag.name)> closes", tag.start)
        }

        private mutating func startTag() throws(ParseFailure) -> Tag {
            let start = at
            at += 1
            let nameRange = name()
            guard !nameRange.isEmpty else { throw ParseFailure("Expected an element name", at) }
            let name = String(decoding: bytes[nameRange], as: UTF8.self)
            var attributes: [Attribute] = []
            while true {
                while at < bytes.count, isSpace(bytes[at]) { at += 1 }
                guard at < bytes.count else { throw ParseFailure("This tag has no closing >", start) }
                switch bytes[at] {
                case UInt8(ascii: ">"):
                    at += 1
                    return Tag(start: start, nameRange: nameRange, name: name, attributes: attributes, selfClosing: false)
                case UInt8(ascii: "/"):
                    guard at + 1 < bytes.count, bytes[at + 1] == UInt8(ascii: ">") else { throw ParseFailure("Expected > after /", at + 1) }
                    at += 2
                    return Tag(start: start, nameRange: nameRange, name: name, attributes: attributes, selfClosing: true)
                default:
                    attributes.append(try attribute())
                }
            }
        }

        private mutating func attribute() throws(ParseFailure) -> Attribute {
            let nameRange = name()
            guard !nameRange.isEmpty else { throw ParseFailure("Expected an attribute name", at) }
            while at < bytes.count, isSpace(bytes[at]) { at += 1 }
            guard at < bytes.count, bytes[at] == UInt8(ascii: "=") else { throw ParseFailure("Expected = after the attribute name", at) }
            at += 1
            while at < bytes.count, isSpace(bytes[at]) { at += 1 }
            guard at < bytes.count, bytes[at] == UInt8(ascii: "\"") || bytes[at] == UInt8(ascii: "'") else {
                throw ParseFailure("Expected a quoted attribute value", at)
            }
            let quote = bytes[at], open = at
            at += 1
            var plain = true
            while at < bytes.count, bytes[at] != quote {
                if bytes[at] == UInt8(ascii: "&") || bytes[at] == 0x0D { plain = false }
                at += 1
            }
            guard at < bytes.count else { throw ParseFailure("This attribute value has no closing quote", open) }
            at += 1
            return Attribute(name: nameRange, value: open + 1..<at - 1, plain: plain)
        }

        private mutating func endTag(of tag: Tag) throws(ParseFailure) {
            let start = at
            at += 2
            let nameRange = name()
            while at < bytes.count, isSpace(bytes[at]) { at += 1 }
            guard at < bytes.count else { throw ParseFailure("This tag has no closing >", start) }
            guard bytes[at] == UInt8(ascii: ">"), bytes[nameRange].elementsEqual(bytes[tag.nameRange]) else {
                throw ParseFailure("Expected </\(tag.name)> to close <\(tag.name)>", start)
            }
            at += 1
        }

        private mutating func name() -> Range<Int> {
            let start = at
            while at < bytes.count, isNameByte(bytes[at]) { at += 1 }
            return start..<at
        }

        private mutating func text(into run: inout Run) {
            let start = at
            var plain = true, visible: Int?
            while at < bytes.count {
                let byte = bytes[at]
                if byte == UInt8(ascii: "<") { break }
                if byte == UInt8(ascii: "&") || byte == 0x0D { plain = false }
                if visible == nil, !isSpace(byte) { visible = at }
                at += 1
            }
            run.add(start..<at, plain: plain, visible: visible)
        }

        private mutating func cdata(into run: inout Run) throws(ParseFailure) {
            let start = at
            guard let close = find(cdataClose, from: at + cdataOpen.count) else { throw ParseFailure("This CDATA section has no closing ]]>", start) }
            let blank = bytes[start + cdataOpen.count..<close].allSatisfy(isSpace)
            at = close + cdataClose.count
            run.add(start..<at, plain: false, visible: blank ? nil : start)
        }

        private mutating func skipComment() throws(ParseFailure) {
            guard let close = find(commentClose, from: at + commentOpen.count) else { throw ParseFailure("This comment has no closing -->", at) }
            at = close + commentClose.count
        }

        private mutating func skipInstruction() throws(ParseFailure) {
            guard let close = find(piClose, from: at + 2) else { throw ParseFailure("This processing instruction has no closing ?>", at) }
            at = close + piClose.count
        }

        /// Past the closing `>`, stepping over quoted strings, and an internal subset in `[...]` with its comments.
        private mutating func skipDoctype() throws(ParseFailure) {
            let start = at
            var inSubset = false
            at += doctypeOpen.count
            while at < bytes.count {
                let byte = bytes[at]
                if byte == UInt8(ascii: "\"") || byte == UInt8(ascii: "'") {
                    at += 1
                    while at < bytes.count, bytes[at] != byte { at += 1 }
                } else if inSubset, starts(commentOpen) {
                    try skipComment()
                    continue
                } else if byte == UInt8(ascii: "[") {
                    inSubset = true
                } else if byte == UInt8(ascii: "]") {
                    inSubset = false
                } else if byte == UInt8(ascii: ">"), !inSubset {
                    at += 1
                    return
                }
                at += 1
            }
            throw ParseFailure("This doctype has no closing >", start)
        }

        private func starts(_ pattern: [UInt8]) -> Bool { starts(pattern, at: at) }

        private func starts(_ pattern: [UInt8], at offset: Int) -> Bool {
            offset + pattern.count <= bytes.count && bytes[offset..<offset + pattern.count].elementsEqual(pattern)
        }

        private func find(_ pattern: [UInt8], from offset: Int) -> Int? {
            var index = offset
            while index + pattern.count <= bytes.count {
                if bytes[index] == pattern[0], starts(pattern, at: index) { return index }
                index += 1
            }
            return nil
        }

        // MARK: Decoding

        func string(_ run: Run, trim: Bool) -> String {
            guard let span = run.span else { return "" }
            if run.plain { return String(decoding: bytes[trim ? trimmed(span, in: bytes) : span], as: UTF8.self) }
            var out: [UInt8] = []
            out.reserveCapacity(span.count)
            decode(span, markup: true, into: &out)
            return String(decoding: out[trim ? trimmed(0..<out.count, in: out) : 0..<out.count], as: UTF8.self)
        }

        private func attributeValue(_ attribute: Attribute) -> String {
            guard !attribute.plain else { return String(decoding: bytes[attribute.value], as: UTF8.self) }
            var out: [UInt8] = []
            decode(attribute.value, markup: false, into: &out)
            return String(decoding: out, as: UTF8.self)
        }

        private func trimmed(_ range: Range<Int>, in bytes: [UInt8]) -> Range<Int> {
            var lower = range.lowerBound, upper = range.upperBound
            while lower < upper, isSpace(bytes[lower]) { lower += 1 }
            while upper > lower, isSpace(bytes[upper - 1]) { upper -= 1 }
            return lower..<upper
        }

        /// Entities expanded and line breaks made `\n`; with `markup`, CDATA kept literally and comments and
        /// processing instructions dropped. The span was checked when read.
        private func decode(_ span: Range<Int>, markup: Bool, into out: inout [UInt8]) {
            var index = span.lowerBound
            while index < span.upperBound {
                let byte = bytes[index]
                if byte == UInt8(ascii: "&") {
                    index = entity(at: index, end: span.upperBound, into: &out)
                } else if byte == 0x0D {
                    out.append(0x0A)
                    index += index + 1 < span.upperBound && bytes[index + 1] == 0x0A ? 2 : 1
                } else if markup, byte == UInt8(ascii: "<"), starts(cdataOpen, at: index), let close = find(cdataClose, from: index + cdataOpen.count) {
                    var inner = index + cdataOpen.count
                    while inner < close {
                        if bytes[inner] == 0x0D {
                            out.append(0x0A)
                            if inner + 1 < close, bytes[inner + 1] == 0x0A { inner += 1 }
                        } else {
                            out.append(bytes[inner])
                        }
                        inner += 1
                    }
                    index = close + cdataClose.count
                } else if markup, byte == UInt8(ascii: "<"), starts(commentOpen, at: index), let close = find(commentClose, from: index + commentOpen.count) {
                    index = close + commentClose.count
                } else if markup, byte == UInt8(ascii: "<"), let close = find(piClose, from: index + 2) {
                    index = close + piClose.count
                } else {
                    out.append(byte)
                    index += 1
                }
            }
        }

        /// The entity at `index` decoded, returning where reading goes on. One that isn't known, or isn't closed by
        /// `;`, stays as written.
        private func entity(at index: Int, end: Int, into out: inout [UInt8]) -> Int {
            var semicolon = index + 1
            while semicolon < end, semicolon - index <= 16, bytes[semicolon] != UInt8(ascii: ";") { semicolon += 1 }
            guard semicolon < end, bytes[semicolon] == UInt8(ascii: ";") else {
                out.append(UInt8(ascii: "&"))
                return index + 1
            }
            let body = bytes[index + 1..<semicolon]
            let named: UInt8? = switch String(decoding: body, as: UTF8.self) {
            case "lt": UInt8(ascii: "<")
            case "gt": UInt8(ascii: ">")
            case "amp": UInt8(ascii: "&")
            case "quot": UInt8(ascii: "\"")
            case "apos": UInt8(ascii: "'")
            default: nil
            }
            if let named {
                out.append(named)
                return semicolon + 1
            }
            if body.first == UInt8(ascii: "#") {
                let digits = body.dropFirst()
                let hex = digits.first == UInt8(ascii: "x")
                if let code = UInt32(String(decoding: hex ? digits.dropFirst() : digits, as: UTF8.self), radix: hex ? 16 : 10),
                   code != 0, let scalar = Unicode.Scalar(code) {
                    UTF8.encode(scalar) { out.append($0) }
                    return semicolon + 1
                }
            }
            out.append(UInt8(ascii: "&"))
            return index + 1
        }
    }
}
