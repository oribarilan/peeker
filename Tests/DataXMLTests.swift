import Foundation
@testable import PeekerData
import Testing

private func parse(_ text: String) throws -> DataNode { try XMLReader.parse(text).get() }
private func error(_ text: String) -> SyntaxError? {
    guard case .failure(let error) = XMLReader.parse(text) else { return nil }
    return error
}
private func byteOffset(of needle: String, in text: String) -> Int {
    Array(text.utf8).firstRange(of: Array(needle.utf8))?.lowerBound ?? -1
}

@Suite struct XMLElements {
    @Test func aMavenFile() throws {
        let text = #"<project><version>1.0</version><build lang="java"><x/></build></project>"#
        let root = try parse(text)
        #expect(root.kind == .element && root.key == "project" && root.children.map(\.key) == ["version", "build"])
        #expect(root.children[0].kind == .string && root.children[0].value == "1.0")
        let build = root.children[1]
        #expect(build.kind == .element && build.value == nil && build.children.map(\.key) == ["@lang", "x"])
        #expect(build.children[0].value == "java" && build.children[1].kind == .string && build.children[1].value == "")
        #expect(build.start == byteOffset(of: "<build", in: text) && build.children[0].start == byteOffset(of: "lang=", in: text))
    }

    @Test func attributesKeepTheirOrder() throws {
        let root = try parse(#"<a z='1' b="2" m = "3"/>"#)
        #expect(root.children.map(\.key) == ["@z", "@b", "@m"] && root.children.map(\.value) == ["1", "2", "3"])
    }

    @Test func mixedTextShowsAsText() throws {
        let text = "<p>Hello <b>big</b> world<i/>  </p>"
        let root = try parse(text)
        #expect(root.children.map(\.key) == ["#text", "b", "#text", "i"])
        #expect(root.children.map(\.value) == ["Hello", "big", "world", ""])
        #expect(root.children[0].start == byteOffset(of: "Hello", in: text) && root.children[2].start == byteOffset(of: "world", in: text))
    }

    @Test func entitiesAndCDATA() throws {
        let root = try parse(
            """
            <r><e>a &lt;b&gt; &amp; &quot;c&quot; &apos;d&apos; &#65;&#x42;&#x1F600; &custom; & x</e>\
            <c><![CDATA[<raw> & stuff]]></c><m>x<!-- c -->y<![CDATA[z]]></m><t a="&amp;&#33;"/></r>
            """)
        #expect(root.children[0].value == "a <b> & \"c\" 'd' AB😀 &custom; & x")
        #expect(root.children[1].value == "<raw> & stuff")
        #expect(root.children[2].value == "xyz")
        #expect(root.children[3].children[0].value == "&!")
        #expect(try parse("<a>&#xD800;&#0;&#xZZ;&#;</a>").value == "&#xD800;&#0;&#xZZ;&#;")
    }

    @Test func commentsInstructionsAndTheDoctypeAreSkipped() throws {
        let root = try parse(
            """
            \u{FEFF}<?xml version="1.0" encoding="UTF-8"?>
            <!-- top -->
            <!DOCTYPE note [
              <!ENTITY writer "Some > one">
              <!-- a ] comment > -->
              <!ELEMENT note (to)>
            ]>
            <?pi stuff?>
            <note>
              <!-- inside -->
              <to>Tove &writer;</to>
              <?inner pi?>
            </note>
            <!-- after -->

            """)
        #expect(root.key == "note" && root.children.map(\.key) == ["to"] && root.children[0].value == "Tove &writer;")
        #expect(try parse(#"<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0//EN" "x.dtd"><html/>"#).key == "html")
    }

    @Test func crlfLineBreaksReadAsNewlines() throws {
        let root = try parse("<a>\r\n  <b>one\r\ntwo</b>\r\n  <c x=\"1\r\n2\"/>\r\n</a>\r\n")
        #expect(root.children[0].value == "one\ntwo" && root.children[1].children[0].value == "1\n2")
    }

    @Test func aTextOnlyRootAndPrefixedNames() throws {
        #expect(try parse("<a> hi </a>").kind == .string && parse("<a> hi </a>").value == "hi")
        #expect(try parse(#"<xs:element xmlns:xs="u"/>"#).key == "xs:element")
    }
}

@Suite struct XMLErrors {
    @Test func mismatchedAndUnclosedTagsSayWhere() throws {
        let mismatched = try #require(error("<a>\n  <b>\n  </c>\n</a>"))
        #expect(mismatched.message == "Expected </b> to close <b>" && mismatched.line == 3 && mismatched.offset == 12)
        let unclosed = try #require(error("<a>\n<b>x</b>\n"))
        #expect(unclosed.message == "The file ends before <a> closes" && unclosed.line == 1)
    }

    @Test func brokenInputIsAnErrorWithAPlainMessage() {
        let cases: [(String, String)] = [
            ("", "Expected an element"),
            ("hello", "Expected an element"),
            ("<", "Expected an element"),
            ("</a>", "Expected an element"),
            ("<a", "This tag has no closing >"),
            ("<a>", "The file ends before <a> closes"),
            ("<a b>", "Expected = after the attribute name"),
            ("<a b=c>", "Expected a quoted attribute value"),
            ("<a b=\"c>", "This attribute value has no closing quote"),
            ("<a><!-- open</a>", "This comment has no closing -->"),
            ("<a><![CDATA[x</a>", "This CDATA section has no closing ]]>"),
            ("<?xml", "This processing instruction has no closing ?>"),
            ("<!DOCTYPE x [ <!ENTITY a \"]>\">", "This doctype has no closing >"),
            ("<a/><b/>", "Unexpected text after the root element"),
            ("<a/>x", "Unexpected text after the root element"),
            ("<a></a b>", "Expected </a> to close <a>"),
            ("<a></", "This tag has no closing >"),
            ("<a>< b/></a>", "Expected an element name"),
            ("<a/ >", "Expected > after /"),
        ]
        for (text, message) in cases {
            #expect(error(text)?.message == message, "\(text)")
        }
    }

    @Test func deepNestingStopsAtTheLimit() throws {
        #expect(error(String(repeating: "<a>", count: 600) + String(repeating: "</a>", count: 600))?.message == "Nested too deeply")
        #expect(error(String(repeating: "<a x='1'>", count: 100_000))?.message == "Nested too deeply")
        _ = try parse(String(repeating: "<a>", count: 500) + String(repeating: "</a>", count: 500))
    }

    @Test func randomAndTruncatedInputNeverCrashes() {
        let alphabet = Array("<>/=\"'&;!?[]-abc# \n\r".utf8)
        for _ in 0..<5000 {
            let bytes = (0..<Int.random(in: 0..<40)).map { _ in Bool.random() ? alphabet.randomElement()! : UInt8.random(in: 0...255) }
            _ = XMLReader.parse(String(decoding: bytes, as: UTF8.self))
        }
        let sample = Array(#"<?xml version="1.0"?><!DOCTYPE a [<!-- x -->]><a k="v &amp; w"><b>t<![CDATA[c]]></b><!-- n --></a>"#.utf8)
        for cut in 0...sample.count {
            _ = XMLReader.parse(String(decoding: sample.prefix(cut), as: UTF8.self))
        }
    }
}

@Suite struct PlistTrees {
    @Test func anInfoPlist() throws {
        let text = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
            \t<key>CFBundleName</key>
            \t<string>Peeker</string>
            \t<key>Count</key>
            \t<integer> 42 </integer>
            \t<key>Ratio</key>
            \t<real>1.5</real>
            \t<key>On</key>
            \t<true/>
            \t<key>Off</key>
            \t<false></false>
            \t<key>When</key>
            \t<date>2026-11-07T10:00:00Z</date>
            \t<key>Blob</key>
            \t<data>
            \tAAEC
            \tAwQ=
            \t</data>
            \t<key>Types</key>
            \t<array>
            \t\t<string>public.json</string>
            \t\t<dict/>
            \t\t<array/>
            \t</array>
            \t<key>Spaced</key>
            \t<string>  a &amp; b  </string>
            </dict>
            </plist>
            """
        let root = try parse(text)
        #expect(root.kind == .object && root.key == nil)
        #expect(root.children.map(\.key) == ["CFBundleName", "Count", "Ratio", "On", "Off", "When", "Blob", "Types", "Spaced"])
        #expect(root.children.map(\.kind) == [.string, .number, .number, .bool, .bool, .string, .string, .array, .string])
        #expect(root.children.map(\.value) == ["Peeker", "42", "1.5", "true", "false", "2026-11-07T10:00:00Z", "AAECAwQ=", nil, "  a & b  "])
        let types = root.children[7]
        #expect(types.children.map(\.kind) == [.string, .object, .array] && types.children.map(\.key) == [nil, nil, nil])
        #expect(root.children[0].start == byteOffset(of: "<key>CFBundleName", in: text))
    }

    @Test func emptyAndScalarPlists() throws {
        #expect(try parse("<plist/>").kind == .object)
        #expect(try parse(#"<plist version="1.0"></plist>"#).children.isEmpty)
        #expect(try parse("<plist><string>top</string></plist>").value == "top")
    }

    @Test func plistErrors() {
        let cases: [(String, String)] = [
            ("<plist><dict><key>a</key></dict></plist>", "This key has no value"),
            ("<plist><dict><key>a</key><key>b</key><true/></dict></plist>", "This key has no value"),
            ("<plist><dict><string>x</string></dict></plist>", "This value has no <key> before it"),
            ("<plist><dict><key>a</key><foo/></dict></plist>", "A property list can't hold <foo>"),
            ("<plist><array>text</array></plist>", "Expected a value, not text"),
            ("<plist><dict>text</dict></plist>", "Expected a <key>, not text"),
            ("<plist><string><b/></string></plist>", "Expected text in <string>, not an element"),
            ("<plist><true>yes</true></plist>", "Expected nothing inside <true>"),
            ("<plist><key>a</key></plist>", "A <key> belongs in a <dict>"),
            ("<plist><true/><false/></plist>", "A property list holds only one value"),
        ]
        for (text, message) in cases {
            #expect(error(text)?.message == message, "\(text)")
        }
        #expect(error("<plist><dict><key>a</key></dict></plist>")?.offset == 13)
    }
}
