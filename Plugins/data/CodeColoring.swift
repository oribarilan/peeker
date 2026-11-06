import AppKit
import PeekerKit
import PeekerSyntax

/// Colors code in a text view by its syntax, as temporary attributes of the layout manager, so the text, undo and the
/// edited state never change. A copy of Plain Text's, the second; the third copy is the time to share it.
@MainActor final class CodeColoring {
    /// A file's language and its first scan, made off the main thread while the file loads.
    struct Scan: Sendable {
        let language: SyntaxLanguage
        let spans: [SyntaxSpan]
    }

    /// How much is colored before the window shows; the rest follows once it has drawn.
    static let firstScreen = 20_000
    /// How long after the first screen the rest is colored: past the window's first draw, so it never delays it.
    static let restDelay: TimeInterval = 0.05
    /// How long typing pauses before the text is scanned again.
    static let rescanDelay: TimeInterval = 0.2

    private let language: SyntaxLanguage
    private unowned let textView: NSTextView
    private var spans: [SyntaxSpan]
    /// Counts changes, so a scan of older text is dropped.
    private var generation = 0
    private var pendingScan: DispatchWorkItem?

    /// The file's language and spans, or nil for a file that isn't code or is too large to color.
    @concurrent nonisolated static func scan(_ url: URL, text: String) async -> Scan? {
        guard text.utf8.count <= SyntaxScanner.maxBytes, let language = language(of: url, text: text) else { return nil }
        return Scan(language: language, spans: SyntaxScanner.spans(in: text, language: language))
    }

    nonisolated static func language(of url: URL, text: String) -> SyntaxLanguage? {
        if !url.pathExtension.isEmpty { return SyntaxLanguage(fileExtension: url.pathExtension) }
        return SyntaxLanguage(hashBang: String(text.prefix { $0 != "\n" && $0 != "\r" }))
    }

    init(_ scan: Scan, in textView: NSTextView) {
        language = scan.language
        spans = scan.spans
        self.textView = textView
        add(spans.prefix { $0.range.location < Self.firstScreen })
        guard spans.last.map({ $0.range.location >= Self.firstScreen }) == true else { return }
        let opened = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.restDelay) { [weak self] in
            guard let self, generation == opened else { return }
            add(spans.drop { $0.range.location < Self.firstScreen })
        }
    }

    /// Scans again once typing pauses; a newer change drops an older scan.
    func textChanged() {
        generation += 1
        pendingScan?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.rescan() }
        pendingScan = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.rescanDelay, execute: work)
    }

    /// The current spans in the current theme's colors.
    func recolor() { color() }

    /// The text with its code in the System theme's colors, for printing.
    func printed(_ text: String, attributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
        let out = NSMutableAttributedString(string: text, attributes: attributes)
        let syntax = TextTheme.system.syntax
        for span in SyntaxScanner.spans(in: text, language: language) where NSMaxRange(span.range) <= out.length {
            out.addAttribute(.foregroundColor, value: syntax.color(for: span.role), range: span.range)
        }
        return out
    }

    private func rescan() {
        let text = textView.string, started = generation, language = language
        guard text.utf8.count <= SyntaxScanner.maxBytes else {
            spans = []
            return color()
        }
        Task { [weak self] in
            let fresh = await Self.spans(in: text, language: language)
            guard let self, generation == started else { return }
            spans = fresh
            color()
        }
    }

    @concurrent nonisolated private static func spans(in text: String, language: SyntaxLanguage) async -> [SyntaxSpan] {
        SyntaxScanner.spans(in: text, language: language)
    }

    /// Replaces every color with the current spans'.
    private func color() {
        let length = textView.textStorage?.length ?? 0
        textView.layoutManager?.removeTemporaryAttribute(.foregroundColor, forCharacterRange: NSRange(location: 0, length: length))
        add(spans[...])
    }

    private func add(_ spans: ArraySlice<SyntaxSpan>) {
        guard let layoutManager = textView.layoutManager else { return }
        let length = textView.textStorage?.length ?? 0
        let syntax = TextTheme.current.syntax
        for span in spans where NSMaxRange(span.range) <= length {
            layoutManager.addTemporaryAttribute(.foregroundColor, value: syntax.color(for: span.role), forCharacterRange: span.range)
        }
    }
}

extension TextTheme.SyntaxColors {
    func color(for role: SyntaxRole) -> NSColor {
        switch role {
        case .keyword: keyword
        case .string: string
        case .comment: comment
        case .number: number
        case .type: type
        case .function: function
        }
    }
}
