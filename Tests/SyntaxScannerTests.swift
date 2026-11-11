import Foundation
import PeekerSyntax
import Testing

/// The text each span covers, with its role, in order: easier to read in a failure than ranges.
func colored(_ text: String, _ language: SyntaxLanguage) -> [String] {
    let ns = text as NSString
    return SyntaxScanner.spans(in: text, language: language).map { "\($0.role.rawValue):\(ns.substring(with: $0.range))" }
}

/// The role of the first span covering `piece` (the first time it appears), or nil when it's uncolored.
func role(of piece: String, in text: String, _ language: SyntaxLanguage) -> SyntaxRole? {
    let target = (text as NSString).range(of: piece)
    return SyntaxScanner.spans(in: text, language: language).first { NSIntersectionRange($0.range, target).length > 0 }?.role
}

@Suite struct SyntaxScannerBasics {
    @Test func swift() {
        let code = """
            // count words
            func count(_ text: String) -> Int { /* nested /* still */ comment */
                let name = "say \\"hi\\" // not a comment"
                return text.split(separator: " ").count + 0x1F + 1_000 + 2.5e3
            }
            let shown = "\\(items.joined(separator: ", ")) done"
            let empty: String? = nil
            """
        #expect(role(of: "// count words", in: code, .swift) == .comment)
        #expect(role(of: "func", in: code, .swift) == .keyword)
        #expect(role(of: "count(", in: code, .swift) == .function)
        #expect(role(of: "String", in: code, .swift) == .type)
        #expect(colored(code, .swift).contains("comment:/* nested /* still */ comment */"))
        #expect(colored(code, .swift).contains("string:\"say \\\"hi\\\" // not a comment\""))
        #expect(
            colored(code, .swift).contains("number:0x1F") && colored(code, .swift).contains("number:1_000")
                && colored(code, .swift).contains("number:2.5e3"))
        #expect(
            colored(code, .swift).contains("string:\"\\(items.joined(separator: \", \")) done\""),
            "quotes inside an interpolation stay part of the string")
        #expect(role(of: "nil", in: code, .swift) == .number, "constants share the number color")
    }

    @Test func swiftMultilineStrings() {
        let code = "let text = \"\"\"\nline \"one\"\n\"\"\"\nlet x = 1"
        #expect(colored(code, .swift).first { $0.hasPrefix("string:") } == "string:\"\"\"\nline \"one\"\n\"\"\"")
        #expect(role(of: "1", in: code, .swift) == .number)
    }

    @Test func python() {
        let code = """
            # report
            import os
            LIMIT = 100
            def words(path: str) -> int:
                with open(path, "utf-8") as f:
                    return len(f.read().split()) if True else None
            doc = '''a "quoted"
            line'''
            name = f"{LIMIT} words"
            """
        #expect(role(of: "# report", in: code, .python) == .comment)
        #expect(role(of: "import", in: code, .python) == .keyword)
        #expect(role(of: "LIMIT", in: code, .python) == .number, "ALL_CAPS is a constant, not a type")
        #expect(role(of: "words(", in: code, .python) == .function)
        #expect(role(of: "True", in: code, .python) == .number && role(of: "None", in: code, .python) == .number)
        #expect(colored(code, .python).contains("string:'''a \"quoted\"\nline'''"))
        #expect(colored(code, .python).contains("string:f\"{LIMIT} words\""), "a prefix belongs to its string")
    }

    @Test func shell() {
        let code = """
            #!/bin/bash
            # build it
            if [ -n "$1" ]; then echo "$(date "+%F") done"; fi
            count=${#items[@]} # not this one: ${#
            echo a#b 'single $x'
            """
        #expect(role(of: "#!/bin/bash", in: code, .shell) == .comment)
        #expect(role(of: "if", in: code, .shell) == .keyword && role(of: "fi", in: code, .shell) == .keyword)
        #expect(colored(code, .shell).contains("string:\"$(date \"+%F\") done\""), "quotes inside $( ) stay part of the string")
        #expect(role(of: "a#b", in: code, .shell) == nil, "# inside a word isn't a comment")
        #expect(role(of: "{#items", in: code, .shell) == nil)
        #expect(colored(code, .shell).contains("string:'single $x'"))
    }

    @Test func json() {
        let code = "{\"name\": \"Peeker\", \"size\": 12.5, \"tags\": [true, null], \"n\": -3e2} // note"
        #expect(
            colored(code, .json) == [
                "string:\"name\"", "string:\"Peeker\"", "string:\"size\"", "number:12.5", "string:\"tags\"",
                "number:true", "number:null", "string:\"n\"", "number:3e2", "comment:// note",
            ])
    }

    @Test func offsetsCountUTF16() {
        let code = "let café = \"naïve 🙂\" // ok"
        #expect(colored(code, .swift) == ["keyword:let", "string:\"naïve 🙂\"", "comment:// ok"])
    }

    @Test func spansAreInOrderAndDontOverlap() throws {
        for language in SyntaxLanguage.allCases {
            let text = "a = \"x\" // c\n# d\n/* e */ 'f' 12 Foo bar() -- g ; h"
            let spans = SyntaxScanner.spans(in: text, language: language)
            for (a, b) in zip(spans, spans.dropFirst()) { #expect(NSMaxRange(a.range) <= b.range.location, "\(language)") }
        }
    }
}
