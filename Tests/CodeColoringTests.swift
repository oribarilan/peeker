import AppKit
import PeekerKit
import PeekerSyntax
@testable import PeekerText
import Testing

@MainActor private func openCode(_ text: String, name: String = "tool.py") async throws -> (TextDocument, NSTextView) {
    let document = try await openDocument(try TempFile.make(Data(text.utf8), name: name), with: TextPlugin.self, as: TextDocument.self)
    return (document, try #require(document.focusView as? NSTextView))
}

/// The foreground color a text view draws at the first `piece`, as hex in the light look, or nil when only the text
/// color applies.
@MainActor private func drawnColor(of piece: String, in view: NSTextView) -> UInt32? {
    let location = (view.string as NSString).range(of: piece).location
    return (view.layoutManager?.temporaryAttribute(.foregroundColor, atCharacterIndex: location, effectiveRange: nil) as? NSColor)
        .map { hex($0, in: .aqua) }
}

@MainActor private func syntax(_ keyPath: KeyPath<TextTheme.SyntaxColors, NSColor>) -> UInt32 {
    hex(TextTheme.current.syntax[keyPath: keyPath], in: .aqua)
}

/// Code coloring in Plain Text. These change the current theme, so they nest in `ThemeState`.
extension ThemeState { @Suite struct CodeColoringInText {
    @Test func aPythonFileOpensColored() async throws {
        let (_, view) = try await openCode("def size(path):\n    return len(\"x\")  # count\n")
        #expect(drawnColor(of: "def", in: view) == syntax(\.keyword))
        #expect(drawnColor(of: "\"x\"", in: view) == syntax(\.string))
        #expect(drawnColor(of: "# count", in: view) == syntax(\.comment))
        #expect(drawnColor(of: "size(", in: view) == syntax(\.function))
        #expect(drawnColor(of: "path):", in: view) == nil)
    }

    @Test func aScriptWithoutAnExtensionIsColoredByItsHashBang() async throws {
        let (_, view) = try await openCode("#!/bin/bash\nif true; then echo hi; fi\n", name: "deploy")
        #expect(drawnColor(of: "if", in: view) == syntax(\.keyword))
    }

    @Test func textLogsAndLargeFilesStayPlain() async throws {
        let (_, log) = try await openCode("def not code\n", name: "server.log")
        #expect(drawnColor(of: "def", in: log) == nil)
        let big = String(repeating: "x = 1\n", count: SyntaxScanner.maxBytes / 6 + 10) + "def last(): pass\n"
        let (_, large) = try await openCode(big)
        #expect(drawnColor(of: "def last", in: large) == nil)
    }

    @Test func aLongFileColorsTheFirstScreenThenTheRest() async throws {
        let (document, view) = try await openCode("import os\n" + String(repeating: "value = 1  # filler\n", count: 2000) + "def last(): pass\n")
        defer { withExtendedLifetime(document) {} }  // the window holds it in the app
        #expect(drawnColor(of: "import", in: view) == syntax(\.keyword), "the first screen is colored at once")
        #expect(drawnColor(of: "def last", in: view) == nil, "the rest follows on the next turn of the run loop")
        try await waitUntil(seconds: 2) { drawnColor(of: "def last", in: view) == syntax(\.keyword) }
    }

    @Test func typingIsColoredOnceItPauses() async throws {
        let (document, view) = try await openCode("x = 1\n")
        view.insertText("class Box: pass\n", replacementRange: NSRange(location: 0, length: 0))
        view.insertText("while True: pass\n", replacementRange: NSRange(location: 0, length: 0))
        try await waitUntil(seconds: 2) { drawnColor(of: "while", in: view) == syntax(\.keyword) && drawnColor(of: "class", in: view) == syntax(\.keyword) }
        #expect(document.text == "while True: pass\nclass Box: pass\nx = 1\n")
    }

    @Test func aThemeChangeRecolors() async throws {
        defer { TextTheme.current = .system }
        let (_, view) = try await openCode("def f(): return 1\n")
        TextTheme.current = TextTheme.named("paper")!
        #expect(drawnColor(of: "def", in: view) == hex(TextTheme.named("paper")!.syntax.keyword, in: .aqua))
    }

    @Test func printingUsesSystemsLightCodeColorsOverBlack() async throws {
        defer { TextTheme.current = .system }
        TextTheme.current = TextTheme.named("tokyo-night")!
        let (document, _) = try await openCode("def f(): return \"x\"\n")
        let job = try #require(document.printJob)
        let operation = job(NSPrintInfo())
        let view = try #require(operation?.view as? NSTextView)
        let storage = try #require(view.textStorage)
        func printed(_ piece: String) -> UInt32? {
            (storage.attribute(.foregroundColor, at: (storage.string as NSString).range(of: piece).location, effectiveRange: nil) as? NSColor)
                .map { hex($0, in: .aqua) }
        }
        #expect(printed("def") == 0x9B2393, "System's light keyword")
        #expect(printed("\"x\"") == 0xC41A16, "System's light string")
        #expect(printed("f()") == 0x326D74)
        #expect(printed(": return") == 0x000000, "the rest stays black")
    }

    @Test func coloringLeavesTheTextUndoAndFindMarksAlone() async throws {
        let (document, view) = try await openCode("def f(): return 1\n")
        #expect(document.unsavedEdits() == nil)
        #expect(view.undoManager?.canUndo != true)
        view.layoutManager?.addTemporaryAttribute(.backgroundColor, value: NSColor.yellow, forCharacterRange: NSRange(location: 0, length: 3))
        TextTheme.current = TextTheme.named("ink")!  // recolors twice
        TextTheme.current = .system
        #expect(view.layoutManager?.temporaryAttribute(.backgroundColor, atCharacterIndex: 1, effectiveRange: nil) != nil,
                "a find mark stays when the code is recolored")
    }
}}
