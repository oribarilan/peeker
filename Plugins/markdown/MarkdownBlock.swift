/// The parsed document: blocks with the 1-based source lines that outline anchors and task toggling need.
nonisolated indirect enum MarkdownBlock: Sendable, Equatable {
    case heading(level: Int, spans: [Span], line: Int)
    case paragraph([Span])
    case list(ordered: Bool, start: Int, items: [ListItem])
    case code(text: String, language: String?)
    case quote([MarkdownBlock])
    case rule
    case table([[[Span]]])
}

nonisolated struct ListItem: Sendable, Equatable {
    let blocks: [MarkdownBlock]
    let line: Int
    let checked: Bool?
}

nonisolated struct Span: Sendable, Equatable {
    let text: String
    let style: SpanStyle
    let link: String?
}

/// Style bits for spans.
nonisolated struct SpanStyle: OptionSet, Sendable, Hashable {
    let rawValue: Int
    static let strong = SpanStyle(rawValue: 1)
    static let emphasis = SpanStyle(rawValue: 2)
    static let code = SpanStyle(rawValue: 4)
    static let strikethrough = SpanStyle(rawValue: 8)
    static let image = SpanStyle(rawValue: 16)
}

/// A heading in the sidebar outline. `line` is its 1-based source line.
nonisolated struct OutlineItem: Sendable, Equatable {
    let title: String
    let level: Int
    let line: Int
}
