import AppKit
import PeekerKit
import PeekerSyntax
@testable import PeekerMarkdown
import Testing

private let source = """
# Notes

```python
def size(path):
    return len("x")  # count
```

```
def untagged(): pass
```

```mermaid
graph def
```
"""

@Suite struct MarkdownFenceStyling {
    @Test func aTaggedBlockGetsSyntaxRunsInsideItsFences() {
        let style = MarkdownStyler.style(source)
        let ns = source as NSString
        let syntax = style.runs.compactMap { run -> String? in
            guard case .syntax(let role) = run.kind else { return nil }
            return "\(role.rawValue):\(ns.substring(with: run.range))"
        }
        #expect(syntax.contains("keyword:def") && syntax.contains("string:\"x\"") && syntax.contains("comment:# count")
                && syntax.contains("function:size"))
        #expect(!syntax.contains { $0.contains("untagged") || $0.contains("graph") || $0.contains("python") },
                "untagged and unknown blocks, and the fence line itself, aren't scanned")
    }
}

/// The color the Editor or the Peek panel draws `piece` in, as hex in the light look.
@MainActor private func color(of piece: String, in view: NSTextView) -> UInt32? {
    guard let storage = view.textStorage else { return nil }
    let location = (storage.string as NSString).range(of: piece).location
    return (storage.attribute(.foregroundColor, at: location, effectiveRange: nil) as? NSColor).map { hex($0, in: .aqua) }
}

/// These change the current theme, so they nest in `ThemeState`.
extension ThemeState { @Suite struct MarkdownCodeColoring {
    @Test func theEditorColorsTaggedBlocksAndFollowsTheTheme() async throws {
        defer { TextTheme.current = .system }
        let editor = try await openDocument(try TempFile.make(Data(source.utf8), name: "f.md"), with: MarkdownPlugin.self, as: MarkdownEditor.self)
        let view = try #require(editor.focusView as? NSTextView)
        #expect(color(of: "def size", in: view) == hex(TextTheme.current.syntax.keyword, in: .aqua))
        #expect(color(of: "\"x\"", in: view) == hex(TextTheme.current.syntax.string, in: .aqua))
        #expect(color(of: "def untagged", in: view) == hex(TextTheme.current.text, in: .aqua))
        let code = (view.string as NSString).range(of: "def size").location
        #expect(view.textStorage?.attribute(.backgroundColor, at: code, effectiveRange: nil) != nil, "on the code background still")
        let paper = TextTheme.named("paper")!
        TextTheme.current = paper
        #expect(color(of: "def size", in: view) == hex(paper.syntax.keyword, in: .aqua))
    }

    @Test func thePeekPanelColorsTaggedBlocks() async throws {
        let document = try await openDocument(try TempFile.make(Data(source.utf8), name: "f.md"), with: MarkdownPlugin.self,
                                              as: MarkdownDocument.self, editing: false)
        let view = try #require(document.focusView as? NSTextView)
        #expect(color(of: "def size", in: view) == hex(TextTheme.current.syntax.keyword, in: .aqua))
        #expect(color(of: "def untagged", in: view) == hex(TextTheme.current.text, in: .aqua))
    }

    @Test func printingUsesSystemsLightCodeColors() async throws {
        defer { TextTheme.current = .system }
        TextTheme.current = TextTheme.named("tokyo-night")!
        let editor = try await openDocument(try TempFile.make(Data(source.utf8), name: "f.md"), with: MarkdownPlugin.self, as: MarkdownEditor.self)
        let printed = editor.printText(for: NSPrintInfo())
        let location = (printed.string as NSString).range(of: "def size").location
        let keyword = try #require(printed.attribute(.foregroundColor, at: location, effectiveRange: nil) as? NSColor)
        #expect(hex(keyword, in: .aqua) == 0x9B2393)
    }
}}
