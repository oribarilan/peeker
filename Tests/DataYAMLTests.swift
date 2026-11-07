import Foundation
@testable import PeekerData
import Testing

private func parse(_ text: String) throws -> DataNode { try YAMLParser.parse(text).get() }
private func error(_ text: String) -> SyntaxError? {
    guard case .failure(let error) = YAMLParser.parse(text) else { return nil }
    return error
}
/// The error as `line: message`.
private func failure(_ text: String) -> String? { error(text).map { "\($0.line): \($0.message)" } }
/// A compact form of a tree with kinds: `{key=…}`, `[…]`, and scalars as `s:`, `n:`, `b:` or `0:` (null) and their text.
private func outline(_ node: DataNode) -> String {
    let key = node.key.map { "\($0)=" } ?? ""
    switch node.kind {
    case .object: return key + "{" + node.children.map(outline).joined(separator: ",") + "}"
    case .array: return key + "[" + node.children.map(outline).joined(separator: ",") + "]"
    case .string: return key + "s:" + (node.value ?? "?")
    case .number: return key + "n:" + (node.value ?? "?")
    case .bool: return key + "b:" + (node.value ?? "?")
    case .null: return key + "0:" + (node.value ?? "?")
    case .element: return key + "?"
    }
}
private func outline(_ text: String) throws -> String { outline(try parse(text)) }

@Suite struct YAMLCollections {
    @Test func aNestedMappingKeepsKindsAndPlaces() throws {
        let text = "a:\n  bb: 1\n  cc: two\nok: true\nnone: null\nempty:\ntilde: ~\n"
        let root = try parse(text)
        #expect(outline(root) == "{a={bb=n:1,cc=s:two},ok=b:true,none=0:null,empty=0:,tilde=0:~}")
        #expect(root.key == nil && root.children[0].start == 0)
        #expect(root.children[0].children[0].start == 5 && root.children[0].children[1].start == 13)
        #expect(root.children[0].children[1].parent === root.children[0])
    }

    @Test func aSequenceOfMappings() throws {
        let text = "- name: a\n  port: 80\n- name: b\n  port: 81\n"
        let root = try parse(text)
        #expect(outline(root) == "[{name=s:a,port=n:80},{name=s:b,port=n:81}]")
        #expect(root.children[1].start == 21 && root.children[1].children[0].start == 23)
        #expect(try outline("- - x\n  - y\n- z") == "[[s:x,s:y],s:z]")
        #expect(try outline("-\n  a: 1\n-\n- c") == "[{a=n:1},0:,s:c]")
    }

    @Test func dashesAtTheKeysIndent() throws {
        #expect(try outline("key:\n- a\n- b\nother: 1\n") == "{key=[s:a,s:b],other=n:1}")
        #expect(try outline("key:\n  - a\n  - b\nother: 1\n") == "{key=[s:a,s:b],other=n:1}")
        #expect(try outline("- a:\n  - x\n  b: 2") == "[{a=[s:x],b=n:2}]")
    }

    @Test func flowCollections() throws {
        #expect(try outline("[a, b, {c: d}]") == "[s:a,s:b,{c=s:d}]")
        #expect(try outline("{a: 1, b: [x, y], 'q': \"z\",}") == "{a=n:1,b=[s:x,s:y],q=s:z}")
        #expect(try outline("k: [1,\n  2, # two\n  3]\nm: {}") == "{k=[n:1,n:2,n:3],m={}}")
        #expect(try outline("k: [http://x.com, a:b]") == "{k=[s:http://x.com,s:a:b]}")
        #expect(try outline("k: {\"a\":1, b}") == "{k={a=n:1,b=0:}}")
    }
}

@Suite struct YAMLScalarStyles {
    @Test func plainScalarsFoldTheirLines() throws {
        #expect(try outline("url: http://x.com/a#b # c") == "{url=s:http://x.com/a#b}")
        #expect(try outline("a: some text\n  goes on\n\n  here\nb: 1") == "{a=s:some text goes on\nhere,b=n:1}")
        #expect(try outline("- a\n  b\n- c") == "[s:a b,s:c]")
    }

    @Test func quotedScalars() throws {
        #expect(try outline(#"a: "x\ty\n\u00e9\x41\U0001F600\"""#) == "{a=s:x\ty\néA😀\"}")
        #expect(try outline("a: 'it''s'\nb: \"one\n  two\n\n  three\"\nc: \"join\\\n   ed\"") == "{a=s:it's,b=s:one two\nthree,c=s:joined}")
        #expect(try outline("\"quoted key\": 1\n'single': 2") == "{quoted key=n:1,single=n:2}")
    }

    @Test func blockScalarsWithChomping() throws {
        #expect(try outline("a: |\n  line 1\n  line 2\n\nb: 1") == "{a=s:line 1\nline 2\n,b=n:1}")
        #expect(try outline("a: |-\n  x\n  y\n\n") == "{a=s:x\ny}")
        #expect(try outline("a: |+\n  x\n\n\nb: 1") == "{a=s:x\n\n\n,b=n:1}")
        #expect(try outline("a: >\n  one\n  two\n\n  three\n    more\n  four\n") == "{a=s:one two\nthree\n  more\nfour\n}")
        #expect(try outline("a: |2\n    x\n  y\n") == "{a=s:  x\ny\n}")
        #expect(try outline("a: |\n  x\n  # kept\nb: 1") == "{a=s:x\n# kept\n,b=n:1}")
    }

    @Test func coreSchemaKinds() throws {
        let text = "[1, -2, +3, 0x1F, 0o17, 1.5, .5, 1e3, -1.5E-3, .inf, -.Inf, .NaN, \"true\", 'null', True, FALSE, Null, ~, yes, 1_000, 1.2.3]"
        #expect(try outline(text) == "[n:1,n:-2,n:+3,n:0x1F,n:0o17,n:1.5,n:.5,n:1e3,n:-1.5E-3,n:.inf,n:-.Inf,n:.NaN,"
            + "s:true,s:null,b:True,b:FALSE,0:Null,0:~,s:yes,s:1_000,s:1.2.3]")
    }
}

@Suite struct YAMLFiles {
    @Test func commentsAnywhere() throws {
        #expect(try outline("# top\na: 1 # one\n# mid\n  # indented\nb: [x] # flow\n") == "{a=n:1,b=[s:x]}")
        #expect(try outline("# only\n\n") == "{}" && (try outline("")) == "{}")
    }

    @Test func anchorsAndTagsAreDroppedAndAliasesShown() throws {
        #expect(try outline("base: &b\n  x: 1\nother: *b\nt: !!str 12\nu: !custom 5\n<<: *b") == "{base={x=n:1},other=s:*b,t=s:12,u=n:5,<<=s:*b}")
        #expect(try outline("- &a x\n- *a\n- !<tag:x> y") == "[s:x,s:*a,s:y]")
    }

    @Test func severalDocuments() throws {
        #expect(try outline("---\na: 1\n---\nb: 2\n") == "[{a=n:1},{b=n:2}]")
        #expect(try outline("%YAML 1.2\n---\na: 1\n...\n") == "{a=n:1}")
        #expect(try outline("--- 1\n--- two\n---\n") == "[n:1,s:two,0:]")
        #expect(try outline("--- |\n  text\n") == "s:text\n")
    }

    @Test func crlfAndBOM() throws {
        #expect(try outline("a: 1\r\nb:\r\n  - x\r\n  - \"y\"\r\nc: |\r\n  l1\r\n  l2\r\n") == "{a=n:1,b=[s:x,s:y],c=s:l1\nl2\n}")
        #expect(try outline("\u{FEFF}a: 1") == "{a=n:1}")
    }
}

@Suite struct YAMLErrors {
    @Test func errorsSayWhereAndWhat() {
        #expect(failure("a: \"open\nb: 1") == "1: This string has no closing quote")
        #expect(failure("a: [1,\n  2") == "2: Expected a comma or ]")
        #expect(failure("a: 1\n  b: 2") == "2: This line is indented more than the one above")
        #expect(failure("a:\n    b: 1\n  c: 2") == "3: This line doesn't line up with the lines above")
        #expect(failure("a:\n\tb: 1") == "2: Tabs can't indent YAML")
        #expect(error("a: 1\nnot a key\n")?.message == "Expected a key and a colon")
        #expect(error("a: b: c")?.message == "A nested key needs a line of its own")
        #expect(error("a: [1] x")?.message == "Unexpected text after the value")
    }

    @Test func aComplexKeyIsUnsupported() {
        #expect(error("a: 1\n? b\n: c") == SyntaxError("Uses a complex key (?), which the tree can't show", at: 5, in: Array("a: 1\n? b\n: c".utf8)))
        #expect(error("{? a : b}")?.message == "Uses a complex key (?), which the tree can't show")
    }

    @Test func nastyInputNeverCrashes() {
        for nasty in ["-", "- ", "---", "...", ":", "::", "? ", "[", "{", "]", "\"", "'", "|", ">", "&", "*", "!", "\t", "\r\n",
                      "a:\n- ", "[a,", "{a:", "- [", "a: 'x", "\"\\u12", "a: >\n\t\tx", "- - - -", "a: &", "--- [", "k: |+", "{,}", "[a, , b]"] {
            _ = YAMLParser.parse(nasty)
        }
        var generator = SystemRandomNumberGenerator()
        let alphabet = Array("-:?[]{},#&*!|>'\"%@` \t\r\nab01.~".utf8)
        for _ in 0..<2000 {
            let bytes = (0..<Int.random(in: 0..<40, using: &generator)).map { _ in alphabet.randomElement(using: &generator)! }
            _ = YAMLParser.parse(String(decoding: bytes, as: UTF8.self))
        }
    }

    /// On a thread with a big stack: an unoptimized build needs more per level than a test's thread has.
    @Test func deepNestingIsAnError() {
        var keys = ""
        for level in 0..<1000 { keys += String(repeating: " ", count: level) + "k:\n" }
        // Found in review: anchors or tags ending their lines nested without counting, and overflowed the stack.
        let inputs = [String(repeating: "- ", count: 2000) + "x", String(repeating: "[", count: 2000), keys,
                      String(repeating: "&a\n", count: 200_000) + "x", "key:\n" + String(repeating: "  !t\n", count: 200_000)]
        let messages = Messages()
        let done = DispatchSemaphore(value: 0)
        let thread = Thread {
            messages.list = inputs.map { text in
                guard case .failure(let error) = YAMLParser.parse(text) else { return nil }
                return error.message
            }
            done.signal()
        }
        thread.stackSize = 16 << 20
        thread.start()
        done.wait()
        #expect(messages.list == Array(repeating: "Nested too deeply", count: 5))
    }
}

private nonisolated final class Messages: @unchecked Sendable {
    var list: [String?] = []
}
