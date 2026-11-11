import Foundation
@testable import PeekerData
import Testing

private func parse(_ text: String) throws -> DataNode { try TOMLParser.parse(text).get() }
private func error(_ text: String) -> SyntaxError? {
    guard case .failure(let error) = TOMLParser.parse(text) else { return nil }
    return error
}
private func byteOffset(of needle: String, in text: String) -> Int {
    let bytes = Array(text.utf8), part = Array(needle.utf8)
    return (0...(bytes.count - part.count)).first { Array(bytes[$0..<$0 + part.count]) == part } ?? -1
}
/// A compact form of a tree: `{key=value,…}`, `[…]`, strings in single quotes, other scalars as written.
private func outline(_ node: DataNode) -> String {
    switch node.kind {
    case .object: "{" + node.children.map { "\($0.key ?? "?")=\(outline($0))" }.joined(separator: ",") + "}"
    case .array: "[" + node.children.map(outline).joined(separator: ",") + "]"
    case .string: "'\(node.value ?? "")'"
    default: node.value ?? "?"
    }
}
private func outline(_ text: String) throws -> String { outline(try parse(text)) }

@Suite struct TOMLTables {
    @Test func aCargoManifest() throws {
        let text = """
            # A crate
            [package]
            name = "peeker"
            edition = 2021

            [dependencies]
            serde = { version = "1.0", features = ["derive"] }
            anyhow = "1"
            """
        let root = try parse(text)
        #expect(root.kind == .object && root.key == nil && root.children.map(\.key) == ["package", "dependencies"])
        let package = root.children[0], serde = root.children[1].children[0]
        #expect(package.children.map(\.kind) == [.string, .number] && package.children[1].value == "2021")
        #expect(package.start == byteOffset(of: "[package]", in: text) && package.children[0].start == byteOffset(of: "name", in: text))
        #expect(serde.kind == .object && serde.value == nil && serde.start == byteOffset(of: "serde", in: text))
        #expect(outline(serde) == "{version='1.0',features=['derive']}")
        #expect(serde.children[1].children[0].start == byteOffset(of: "\"derive\"", in: text))
        #expect(serde.children[0].parent === serde)
    }

    @Test func dottedKeysMakeNestedTables() throws {
        #expect(
            try outline("a.b.c = 1\na.b.d = 2\na . \"x y\" . 'z' = 3\nsite.\"google.com\" = true")
                == "{a={b={c=1,d=2},x y={z=3}},site={google.com=true}}")
        let root = try parse("x = 0\na.b = 1")
        #expect(root.children[1].start == 6 && root.children[1].children[0].start == 8)
    }

    @Test func aTableReopenedByALaterHeader() throws {
        #expect(try outline("[a]\nx = 1\n[c]\ny = 2\n[a.b]\nz = 3") == "{a={x=1,b={z=3}},c={y=2}}")
        let text = "[a.b]\nz = 1\n[a]\nw = 2"
        let root = try parse(text)
        #expect(outline(root) == "{a={b={z=1},w=2}}" && root.children[0].start == byteOffset(of: "[a]", in: text))
    }

    @Test func arraysOfTablesWithSubTables() throws {
        let text = """
            [[fruit]]
            name = "apple"
            [fruit.physical]
            color = "red"
            [[fruit.variety]]
            name = "red delicious"
            [[fruit.variety]]
            name = "granny smith"
            [[fruit]]
            name = "banana"
            """
        let root = try parse(text)
        #expect(
            outline(root) == "{fruit=[{name='apple',physical={color='red'},variety=[{name='red delicious'},{name='granny smith'}]},{name='banana'}]}")
        let list = root.children[0]
        #expect(list.kind == .array && list.start == 0 && list.children[0].key == nil)
        #expect(list.children[1].start == byteOffset(of: "[[fruit]]\nname = \"banana\"", in: text))
    }

    @Test func inlineTablesOverLines() throws {
        #expect(
            try outline("p = { a = 1, b.c = 2, b.d = 3 }\nq = {}\nr = {\n  x = 1, # comment\n  y = 2,\n}")
                == "{p={a=1,b={c=2,d=3}},q={},r={x=1,y=2}}")
    }

    @Test func commentsCRLFAndABOM() throws {
        #expect(try outline("\u{FEFF}# top\r\n\r\na = 1 # trailing\r\n[t] # header comment\r\nb = 'x'\r\n") == "{a=1,t={b='x'}}")
        #expect(try parse("\u{FEFF}a = 1").children[0].start == 3)
        #expect(try outline("") == "{}" && outline("# only a comment") == "{}")
    }
}

@Suite struct TOMLValues {
    @Test func basicStringEscapes() throws {
        #expect(
            try outline(#"s = "tab\tquote\" back\\ \u00E9 \U0001F600 \e\x41 \b\f\r\n""#)
                == "{s='tab\tquote\" back\\ é 😀 \u{1B}A \u{8}\u{C}\r\n'}")
        #expect(try outline("\"\" = 1\n'a b' = 2\n\"a\\tb\" = 3") == "{=1,a b=2,a\tb=3}")
    }

    @Test func literalStringsKeepBackslashes() throws {
        #expect(try outline("s = 'C:\\path\\no \"escapes\"'") == "{s='C:\\path\\no \"escapes\"'}")
        #expect(try outline("s = '''\nFirst\n  raw \\n '' here'''") == "{s='First\n  raw \\n '' here'}")
        #expect(try outline("s = ''''quoted'''''") == "{s=''quoted'''}")
    }

    @Test func multiLineBasicStringsTrim() throws {
        #expect(try outline("s = \"\"\"\nRoses\nViolets\"\"\"") == "{s='Roses\nViolets'}")
        #expect(try outline("s = \"\"\"\r\nline\"\"\"") == "{s='line'}")
        #expect(try outline("s = \"\"\"\nThe quick \\\n    brown \\   \n\n  fox\"\"\"") == "{s='The quick brown fox'}")
        #expect(try outline("s = \"\"\"Two: \"\". One at the end: \"\"\"\"") == "{s='Two: \"\". One at the end: \"'}")
    }

    @Test func numbersAsWritten() throws {
        let numbers = [
            "+99", "-17", "1_000", "0xDEAD_beef", "0o755", "0b1101", "3.1415", "-0.01", "5e+22", "6.626e-34",
            "224_617.445_991", "inf", "-nan", "+inf", "0", "-0.0", "1E2",
        ]
        let root = try parse(numbers.enumerated().map { "n\($0) = \($1)" }.joined(separator: "\n"))
        #expect(root.children.map(\.value) == numbers && root.children.allSatisfy { $0.kind == .number })
        #expect(try parse("b = true\nc = false").children.map(\.kind) == [.bool, .bool])
    }

    @Test func datesAndTimesAsWritten() throws {
        let dates = [
            "1979-05-27T07:32:00Z", "1979-05-27T00:32:00.999999-07:00", "1979-05-27 07:32:00", "1979-05-27", "07:32:00",
            "00:32:00.999999", "1979-05-27t07:32",
        ]
        let root = try parse(dates.enumerated().map { "d\($0) = \($1)" }.joined(separator: "\n"))
        #expect(root.children.map(\.value) == dates && root.children.allSatisfy { $0.kind == .string })
        #expect(try outline("h = [1979-05-27 07:32:00Z, 07:32] # times") == "{h=['1979-05-27 07:32:00Z','07:32']}")
    }

    @Test func arraysOverLinesWithCommentsAndATrailingComma() throws {
        #expect(
            try outline("a = [\n  1, # one\n  # alone\n  2,\n]\nb = []\nc = [[1, 2], ['x', {k = 1}]]")
                == "{a=[1,2],b=[],c=[[1,2],['x',{k=1}]]}")
    }
}

@Suite struct TOMLErrors {
    @Test func duplicateKeysAndTables() throws {
        let cases: [(String, String, Int)] = [
            ("a = 1\nb = 2\na = 3", "Key a is defined twice", 3),
            ("[a]\n[a]", "Table [a] is defined twice", 2),
            ("[a]\nb = 1\n[a.b]", "Key b is defined twice", 3),
            ("[a.b]\nc = 1\n[a]\nb = 2", "Table [a.b] is defined twice", 4),
            ("[a]\nb.c = 1\n[a.b]", "Table [a.b] is defined twice", 3),
            ("a.b = 1\na.b.c = 2", "Key b is defined twice", 2),
            ("a.b = 1\na = 2", "Table [a] is defined twice", 2),
            ("[[a]]\n[a]", "Table [a] is defined twice", 2),
            ("[a]\n[[a]]", "Table [a] is defined twice", 2),
            ("a = []\n[[a]]", "Key a is defined twice", 2),
            ("[a.b.c]\nz = 9\n[a]\nb.c.t = 1", "Table [a.b.c] is defined twice", 4),
            ("p = { a = 1, a = 2 }", "Key a is defined twice", 1),
            ("p = { a = 1 }\np.b = 2", "Key p is defined twice", 2),
            ("p = { a = 1 }\n[p.b]", "Key p is defined twice", 2),
        ]
        for (text, message, line) in cases {
            let found = error(text)
            #expect(found?.message == message && found?.line == line, "\(text)")
        }
        #expect(try outline("[a]\nb.c = 1\n[a.b.d]\ne = 2") == "{a={b={c=1,d={e=2}}}}")
    }

    @Test func malformedLines() {
        let cases: [(String, String, Int)] = [
            ("=", "Expected a key", 1),
            ("a = 1\n= 2", "Expected a key", 2),
            ("a\n", "Expected = after the key", 1),
            ("a =\nb = 1", "Expected a value", 1),
            ("a = hello", "Expected a value", 1),
            ("a = 1 b = 2", "Expected the end of the line", 1),
            ("[a] b = 1", "Expected the end of the line", 1),
            ("x = 1\n\n  [t]\n  y = 2 3", "Expected the end of the line", 4),
            ("[", "Expected a key", 1),
            ("[]", "Expected a key", 1),
            ("a.b.", "Expected a key", 1),
            ("[a", "Expected ] after the table name", 1),
            ("[[a] ]", "Expected ]] after the table name", 1),
            ("a = [1, 2", "Expected a comma or ]", 1),
            ("a = [1 2]", "Expected a comma or ]", 1),
            ("a = [,]", "Expected a value", 1),
            ("p = { a = 1 b = 2 }", "Expected a comma or }", 1),
        ]
        for (text, message, line) in cases {
            let found = error(text)
            #expect(found?.message == message && found?.line == line, "\(text)")
        }
    }

    @Test func badStrings() {
        let cases: [(String, String)] = [
            ("s = \"open", "This string has no closing quote"),
            ("s = 'open\nt = 1", "This string has no closing quote"),
            ("s = \"\"\"\nopen", "This string has no closing quote"),
            ("s = '''", "This string has no closing quote"),
            ("s = \"a\\", "This string has no closing quote"),
            (#"s = "bad \q""#, "This escape isn't valid"),
            (#"s = "\uD800""#, "This escape isn't valid"),
            (#"s = "\u12""#, "This escape isn't valid"),
            ("s = \"a \\ \nb\"", "This escape isn't valid"),
        ]
        for (text, message) in cases { #expect(error(text)?.message == message, "\(text)") }
    }

    @Test func badNumbersAndDates() {
        for bad in [
            "01", "1__0", "1_", "1.", "1e", "0x", "+0x1", "0xG", "1.2.3", "--1", "0o8", "1979-05-2", "1979-05-27T", "07:3",
            "07:32Z", "1979-05-27T07:32:00+7",
        ] {
            #expect(error("a = \(bad)")?.message == "This isn't a number or a date", "\(bad)")
        }
    }

    @Test func hostileInputNeverCrashes() {
        #expect(error("a = " + String(repeating: "[", count: 100_000))?.message == "Nested too deeply")
        #expect(error("a = " + String(repeating: "{b=", count: 100_000))?.message == "Nested too deeply")
        #expect(error("[" + Array(repeating: "a", count: 100_000).joined(separator: ".") + "]")?.message == "Nested too deeply")
        #expect(error(Array(repeating: "a", count: 100_000).joined(separator: ".") + " = 1")?.message == "Nested too deeply")
        let alphabet = Array("[]{}=\"'.,#\n\r\t abc123_-+:\\eTZx".utf8)
        for _ in 0..<2_000 {
            let bytes = (0..<Int.random(in: 0..<40)).map { _ in Bool.random() ? alphabet.randomElement()! : UInt8.random(in: 0...255) }
            _ = TOMLParser.parse(String(decoding: bytes, as: UTF8.self))
        }
    }
}
