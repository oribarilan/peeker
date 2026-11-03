import Foundation
@testable import PeekerMarkdown
import Testing

/// The source text a run covers, so expectations read as Markdown rather than offsets.
private func covered(_ source: String, _ kind: StyleKind) -> [String] {
    MarkdownStyler.style(source).runs.filter { $0.kind == kind }.map { (source as NSString).substring(with: $0.range) }
}

@Suite struct MarkdownStyling {
    @Test func headingIsStyledWithItsHashesDimmed() {
        #expect(covered("## Title\n", .heading(2)) == ["## Title"])
        #expect(covered("## Title\n", .marker) == ["## "])
    }

    @Test func inlineStylesDimTheirMarkers() {
        let source = "a **bold** _it_ ~~gone~~ `code`\n"
        #expect(covered(source, .strong) == ["**bold**"])
        #expect(covered(source, .emphasis) == ["_it_"])
        #expect(covered(source, .strikethrough) == ["~~gone~~"])
        #expect(covered(source, .code) == ["`code`"])
        #expect(covered(source, .marker) == ["**", "**", "_", "_", "~~", "~~", "`", "`"])
    }

    @Test func linkTextIsColoredAndItsBracketsDimmed() {
        let source = "see [the site](https://example.com) now\n"
        #expect(covered(source, .link) == ["the site"])
        #expect(covered(source, .marker) == ["[", "](https://example.com)"])
        let style = MarkdownStyler.style(source)
        #expect(style.links.map(\.destination) == ["https://example.com"])
        #expect(style.links.map { (source as NSString).substring(with: $0.range) } == ["[the site](https://example.com)"])
    }

    @Test func fencedBlockDimsBothFences() {
        let source = "```swift\nlet x = 1\n```\n"
        #expect(covered(source, .codeBlock).count == 1)
        #expect(covered(source, .marker) == ["```swift", "```"])
    }

    @Test func quoteAndRuleAreMarked() {
        #expect(covered("> said\n> more\n", .quote).count == 1)
        #expect(covered("> said\n> more\n", .marker) == ["> ", "> "])
        #expect(covered("---\n", .marker) == ["---"])
    }

    @Test func listMarkersAndTaskBoxes() {
        let source = "- plain\n- [ ] open\n- [x] done\n1. first\n"
        #expect(covered(source, .marker) == ["- ", "- ", "- ", "1. "])
        #expect(covered(source, .taskBox) == ["[ ]", "[x]"])
        let style = MarkdownStyler.style(source)
        #expect(style.taskBoxes.map { (source as NSString).substring(with: $0) } == ["[ ]", "[x]"])
        #expect(style.tasks == (done: 1, total: 2))
    }

    @Test func tablePipesAndDelimiterRowAreDimmed() {
        let source = "| a | b |\n|---|---|\n| 1 | 2 |\n"
        let markers = covered(source, .marker)
        #expect(markers.filter { $0 == "|" }.count == 6)
        #expect(markers.contains("|---|---|"))
    }

    @Test func rangesCountUTF16WithNonASCIIAndCRLF() {
        let source = "# Café 🙂\r\n\r\nñ **bold**\r\n"
        #expect(covered(source, .heading(1)) == ["# Café 🙂"])
        #expect(covered(source, .strong) == ["**bold**"])
        #expect(MarkdownStyler.lineStarts(in: source) == [0, 11, 13, 25])
    }

    @Test func outlineAndCounts() {
        let style = MarkdownStyler.style("# One\n\ntwo words\n\n## Two *b*\n")
        #expect(style.outline == [OutlineItem(title: "One", level: 1, line: 1), OutlineItem(title: "Two b", level: 2, line: 5)])
        #expect(style.words == 7)
    }
}
