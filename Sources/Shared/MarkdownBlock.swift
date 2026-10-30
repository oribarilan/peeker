nonisolated indirect enum MarkdownBlock: Codable, Sendable, Equatable {
    case heading(level: Int, spans: [Span], line: Int)
    case paragraph([Span])
    case list(ordered: Bool, start: Int, items: [ListItem])
    case code(text: String, language: String?)
    case quote([MarkdownBlock])
    case rule
    case table([[[Span]]])
}

nonisolated struct ListItem: Codable, Sendable, Equatable {
    let blocks: [MarkdownBlock]
    let line: Int
    let checked: Bool?
}

nonisolated struct Span: Codable, Sendable, Equatable {
    let text: String
    let style: SpanStyle
    let link: String?
}

// The block tree is most of a large document's reply, and keyed containers doubled its decode time,
// so blocks, list items and spans travel as arrays: a block is [kind, fields…] (see `Kind`), a span
// [text, style, link?], a list item [line, blocks, checked?].
nonisolated extension MarkdownBlock {
    private enum Kind: String {
        case heading = "h", paragraph = "p", list = "l", code = "c", quote = "q", rule = "r", table = "t"
    }

    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let tag = try container.decode(String.self)
        guard let kind = Kind(rawValue: tag) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "unknown block kind \(tag)")
        }
        switch kind {
        case .heading:
            self = .heading(level: try container.decode(Int.self), spans: try container.decode([Span].self), line: try container.decode(Int.self))
        case .paragraph: self = .paragraph(try container.decode([Span].self))
        case .list:
            self = .list(ordered: try container.decode(Bool.self), start: try container.decode(Int.self), items: try container.decode([ListItem].self))
        case .code: self = .code(text: try container.decode(String.self), language: container.isAtEnd ? nil : try container.decode(String.self))
        case .quote: self = .quote(try container.decode([MarkdownBlock].self))
        case .rule: self = .rule
        case .table: self = .table(try container.decode([[[Span]]].self))
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        switch self {
        case .heading(let level, let spans, let line):
            try container.encode(Kind.heading.rawValue)
            try container.encode(level)
            try container.encode(spans)
            try container.encode(line)
        case .paragraph(let spans):
            try container.encode(Kind.paragraph.rawValue)
            try container.encode(spans)
        case .list(let ordered, let start, let items):
            try container.encode(Kind.list.rawValue)
            try container.encode(ordered)
            try container.encode(start)
            try container.encode(items)
        case .code(let text, let language):
            try container.encode(Kind.code.rawValue)
            try container.encode(text)
            if let language { try container.encode(language) }
        case .quote(let blocks):
            try container.encode(Kind.quote.rawValue)
            try container.encode(blocks)
        case .rule:
            try container.encode(Kind.rule.rawValue)
        case .table(let rows):
            try container.encode(Kind.table.rawValue)
            try container.encode(rows)
        }
    }
}

nonisolated extension Span {
    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        text = try container.decode(String.self)
        style = SpanStyle(rawValue: try container.decode(Int.self))
        link = container.isAtEnd ? nil : try container.decode(String.self)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(text)
        try container.encode(style.rawValue)
        if let link { try container.encode(link) }
    }
}

nonisolated extension ListItem {
    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        line = try container.decode(Int.self)
        blocks = try container.decode([MarkdownBlock].self)
        checked = container.isAtEnd ? nil : try container.decode(Bool.self)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(line)
        try container.encode(blocks)
        if let checked { try container.encode(checked) }
    }
}
