import Foundation
import PeekerSyntax
import Testing

/// One example per language: its comments, a string, a keyword, and what it calls a constant.
@Suite struct SyntaxLanguageTables {
    private func check(_ code: String, _ language: SyntaxLanguage, _ expected: [(String, SyntaxRole?)], sourceLocation: SourceLocation = #_sourceLocation) {
        for (piece, wanted) in expected {
            #expect(role(of: piece, in: code, language) == wanted, "\(language): \(piece)", sourceLocation: sourceLocation)
        }
    }

    @Test func javascriptAndTypescript() {
        let code = "// load\nexport async function load(url: string): Promise<Data> { /* fetch */ const msg = `got ${url.replace(\"a\", 'b')}`; return null }"
        check(code, .javascript, [("// load", .comment), ("/* fetch */", .comment), ("export", .keyword), ("function", .keyword),
                                  ("load(", .function), ("Promise", .type), ("`got", .string), ("'b'", .string), ("null", .number),
                                  ("string", .type)])
    }

    @Test func cFamily() {
        let code = "#include <stdio.h>\n// main\nint main(void) { /* x */ char *s = \"hi\\n\"; @autoreleasepool { return NULL; } }"
        check(code, .c, [("#include", .keyword), ("// main", .comment), ("int", .keyword), ("main(", .function), ("\"hi\\n\"", .string),
                         ("NULL", .number), ("@autoreleasepool", .keyword), ("/* x */", .comment)])
    }

    @Test func go() {
        let code = "// Package x\nfunc Sum(xs []int) error { s := `raw \"q\"`; return nil }"
        check(code, .go, [("// Package x", .comment), ("func", .keyword), ("Sum(", .function), ("int", .type), ("error", .type),
                          ("`raw \"q\"`", .string), ("nil", .number)])
    }

    @Test func rust() {
        let code = "/// docs\nfn main() -> Result<(), String> { let s: &'static str = \"hi\"; if true { None } else { Some(1u8) } }"
        check(code, .rust, [("/// docs", .comment), ("fn", .keyword), ("main(", .function), ("Result", .type), ("\"hi\"", .string),
                            ("true", .number), ("let", .keyword), ("str", .type)])
    }

    @Test func java() {
        let code = "// App\npublic final class App { static String NAME = \"app\"; void run() { if (x == null) return; } }"
        check(code, .java, [("// App", .comment), ("public", .keyword), ("class", .keyword), ("App {", .type), ("NAME", .number),
                            ("\"app\"", .string), ("run(", .function), ("null", .number)])
    }

    @Test func kotlin() {
        let code = "// main\nfun greet(name: String) = println(\"Hi ${name.uppercase()}!\")\nval x: Int? = null"
        check(code, .kotlin, [("// main", .comment), ("fun", .keyword), ("greet(", .function), ("String", .type),
                              ("\"Hi ${name.uppercase()}!\"", .string), ("val", .keyword), ("null", .number)])
    }

    @Test func ruby() {
        let code = "# greet\nclass Greeter\n  def hi(name)\n    puts \"Hi #{name.upcase}\" unless name.nil?\n  end\nend\nx = nil"
        check(code, .ruby, [("# greet", .comment), ("class", .keyword), ("Greeter", .type), ("def", .keyword), ("\"Hi #{name.upcase}\"", .string),
                            ("unless", .keyword), ("end", .keyword), ("= nil", .number)])
    }

    @Test func perl() {
        let code = "# count\nmy $n = scalar(@items); print \"n=$n\\n\" if $#items > 0;"
        check(code, .perl, [("# count", .comment), ("my", .keyword), ("\"n=$n\\n\"", .string), ("if", .keyword), ("$#items", nil)])
    }

    @Test func sql() {
        let code = "-- active users\nSELECT id, name FROM users WHERE active = TRUE and name LIKE 'a%' /* x */ LIMIT 10;"
        check(code, .sql, [("-- active users", .comment), ("SELECT", .keyword), ("FROM", .keyword), ("and", .keyword), ("TRUE", .number),
                           ("'a%'", .string), ("/* x */", .comment), ("10", .number)])
    }

    @Test func cssAndScss() {
        let code = "/* layout */\n@media (max-width: 600px) { .box { color: #fff; width: 50%; margin: 0 auto !important; } }\n// scss note"
        check(code, .css, [("/* layout */", .comment), ("@media", .keyword), ("600px", .number), ("#fff", .number), ("50%", .number),
                           ("!important", .keyword), ("// scss note", .comment)])
    }

    @Test func yaml() {
        let code = "# config\nname: \"peeker\"\nport: 8080\ndebug: true\nlist: [a, 'b']\nurl: http://x#frag"
        check(code, .yaml, [("# config", .comment), ("\"peeker\"", .string), ("8080", .number), ("true", .number), ("'b'", .string),
                            ("#frag", nil)])
    }

    @Test func toml() {
        let code = "# app\n[server]\nhost = \"localhost\"\nport = 8080\ntls = false\nnote = '''\nmulti\n'''"
        check(code, .toml, [("# app", .comment), ("\"localhost\"", .string), ("8080", .number), ("false", .number), ("'''\nmulti\n'''", .string)])
    }

    @Test func ini() {
        let code = "; settings\n[main]\nname = value; not a comment\n# also a comment\nenabled = true\nport=80"
        check(code, .ini, [("; settings", .comment), ("# also a comment", .comment), ("; not a comment", nil), ("true", .number), ("80", .number)])
    }

    @Test func jsonWithComments() {
        let code = "{\n  // a comment\n  \"a\": 1, /* b */ \"c\": false\n}"
        check(code, .json, [("// a comment", .comment), ("/* b */", .comment), ("\"a\"", .string), ("1", .number), ("false", .number)])
    }

    /// Syntax the tables don't follow stays plain or stops at the end of its line instead of coloring what follows.
    @Test func messySyntaxDoesntSpread() {
        let regex = "const re = /\"/g;\nconst after = 1"
        #expect(role(of: "const after", in: regex, .javascript) == .keyword, "a regex with a quote doesn't swallow the next line")
        let jsx = "return <div className=\"box\">Hi</div>"
        #expect(role(of: "div", in: jsx, .javascript) == nil, "JSX tags stay plain")
        #expect(role(of: "\"box\"", in: jsx, .javascript) == .string)
        let heredoc = "cat <<EOF\nif it rains\nEOF\nif true; then :; fi"
        #expect(role(of: "fi", in: heredoc, .shell) == .keyword, "a heredoc doesn't change what follows it")
    }

    @Test func aMegabytePerFamilyScansQuickly() {
        let samples: [(SyntaxLanguage, String)] = [
            (.c, "int f(int x) { /* c */ return x * 2; } // done\n"), (.javascript, "const x = `a ${b}`; function f() { return 'c' } // d\n"),
            (.python, "def f(x):  # c\n    return \"a\" + str(x)\n"), (.shell, "if [ -n \"$x\" ]; then echo 'a'; fi # c\n"),
            (.sql, "SELECT a FROM b WHERE c = 'd'; -- e\n"), (.css, ".a { color: #fff; width: 10px; } /* b */\n"),
            (.json, "{\"a\": [1, true, null, \"b\"]},\n"), (.yaml, "a: \"b\"  # c\n"),
        ]
        for (language, line) in samples {
            let text = String(repeating: line, count: 1_000_000 / line.utf8.count)
            _ = SyntaxScanner.spans(in: text, language: language)
            let clock = ContinuousClock()
            let took = clock.measure { _ = SyntaxScanner.spans(in: text, language: language) }
            // About three times what a scan takes on a recent Mac (6-8 ms), leaving room for CI's slower runner
            // (11-15 ms) while still catching a scanner that got several times slower.
            #expect(took < .milliseconds(25), "\(language): \(took)")
        }
    }
}
