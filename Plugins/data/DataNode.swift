import Foundation

/// A key or value of a data file, with where it starts in the file's UTF-8 bytes. A JSON node reads its key and value
/// from the shared bytes and builds its children when first asked for; a node from another format's parser is built
/// whole, holding its decoded key and value. Never changed after the parse, so it's safe to hand to the view.
nonisolated final class DataNode: @unchecked Sendable {
    enum Kind: Sendable { case object, array, element, string, number, bool, null }
    /// Parsers stop at this depth: deep enough for any real file, shallow enough not to run out of stack on a hostile
    /// one.
    static let maxDepth = 512
    let kind: Kind
    /// JSON's key with its quotes; nil elsewhere.
    let keyRange: Range<Int>?
    /// JSON's value; a built node's is empty, at its start.
    let valueRange: Range<Int>
    var children: [DataNode] {
        if let builtChildren { return builtChildren }
        guard let source else { return [] }
        return JSONParser.children(of: self, in: source)
    }
    private(set) var builtChildren: [DataNode]?
    private(set) weak var parent: DataNode?
    /// Its place among its parent's children.
    private(set) var index = 0
    /// The parsed JSON bytes, shared by every node of the file: keys and strings are decoded only when asked for, which
    /// made parsing a 3 MB file several times faster. Nil for a built node.
    let source: JSONSource?
    private let builtKey: String?
    private let builtValue: String?

    /// A JSON node.
    init(kind: Kind, keyRange: Range<Int>?, valueRange: Range<Int>, source: JSONSource) {
        self.kind = kind
        self.keyRange = keyRange
        self.valueRange = valueRange
        self.source = source
        builtKey = nil
        builtValue = nil
        if !isContainer { builtChildren = [] }
    }

    /// A node built whole: `value` is nil for containers.
    init(kind: Kind, key: String?, value: String?, start: Int, children: [DataNode] = []) {
        self.kind = kind
        keyRange = nil
        valueRange = start..<start
        source = nil
        builtKey = key
        builtValue = value
        adopt(children)
    }

    func adopt(_ children: [DataNode]) {
        for (index, child) in children.enumerated() {
            child.parent = self
            child.index = index
        }
        builtChildren = children
    }

    /// The member's key, decoded; nil for array items and the top.
    var key: String? {
        guard let source else { return builtKey }
        return keyRange.map { JSONParser.decodeString(source.bytes[$0]) }
    }

    /// A string decoded, or a scalar's text as written; nil for containers.
    var value: String? {
        guard let source else { return builtValue }
        switch kind {
        case .object, .array, .element: return nil
        case .string: return JSONParser.decodeString(source.bytes[valueRange])
        default: return String(decoding: source.bytes[valueRange], as: UTF8.self)
        }
    }

    /// Where the member starts: its key, or its value in an array.
    var start: Int { keyRange?.lowerBound ?? valueRange.lowerBound }
    var isContainer: Bool { kind == .object || kind == .array || kind == .element }
}

/// The bytes a JSON tree was parsed from.
nonisolated final class JSONSource: Sendable {
    let bytes: [UInt8]
    init(_ bytes: [UInt8]) { self.bytes = bytes }
}

/// What a parser throws inside itself: a message and the byte offset it's about, made into a `SyntaxError` at the end.
nonisolated struct ParseFailure: Error {
    let message: String
    let offset: Int
    init(_ message: String, _ offset: Int) {
        self.message = message
        self.offset = offset
    }

    /// For a form a parser doesn't read, so a valid file isn't called broken.
    static func unsupported(_ form: String, at offset: Int) -> ParseFailure {
        ParseFailure("Uses \(form), which the tree can't show", offset)
    }
}

/// Why a file doesn't parse, and where: a message, the byte offset, and its line and column counted from 1.
nonisolated struct SyntaxError: Error, Equatable, Sendable {
    let message: String
    let offset: Int
    let line: Int
    let column: Int

    init(message: String, offset: Int, line: Int, column: Int) {
        self.message = message
        self.offset = offset
        self.line = line
        self.column = column
    }

    init(_ message: String, at offset: Int, in bytes: [UInt8]) {
        let before = bytes[..<min(max(offset, 0), bytes.count)]
        let lineStart = before.lastIndex(of: 0x0A).map { $0 + 1 } ?? 0
        self.init(message: message, offset: offset, line: before.count(where: { $0 == 0x0A }) + 1, column: before.count - lineStart + 1)
    }
}
