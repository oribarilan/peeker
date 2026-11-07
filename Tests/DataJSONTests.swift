import Foundation
@testable import PeekerData
import Testing

private func parse(_ text: String) throws -> DataNode { try JSONParser.parse(text).get() }
private func slice(_ text: String, _ range: Range<Int>) -> String { String(decoding: Array(text.utf8)[range], as: UTF8.self) }
private func applyAll(_ changes: [TextChange], to text: String) -> String {
    changes.sorted { $0.range.lowerBound > $1.range.lowerBound }.reduce(text) { apply($1, to: $0) }
}
private func apply(_ change: TextChange, to text: String) -> String {
    var bytes = Array(text.utf8)
    bytes.replaceSubrange(change.range, with: Array(change.replacement.utf8))
    return String(decoding: bytes, as: UTF8.self)
}

@Suite struct JSONParsing {
    @Test func nodesKeepTheirKindsKeysAndPlaces() throws {
        let text = #"{"name": "app", "n": 1.5, "ok": true, "none": null, "list": [1, "x"], "deps": {"a": 1}}"#
        let root = try parse(text)
        #expect(root.kind == .object && root.children.map(\.key) == ["name", "n", "ok", "none", "list", "deps"])
        #expect(root.children.map(\.kind) == [.string, .number, .bool, .null, .array, .object])
        let name = root.children[0]
        #expect(slice(text, try #require(name.keyRange)) == "\"name\"" && slice(text, name.valueRange) == "\"app\"")
        #expect(name.value == "app" && root.children[1].value == "1.5")
        #expect(root.children[4].children.map(\.key) == [nil, nil] && root.children[4].children[1].value == "x")
        #expect(root.children[5].children[0].parent === root.children[5])
    }

    @Test func stringEscapesAreDecodedForShowing() throws {
        let root = try parse(#"{"k\"ey": "line\nbreak é 😀"}"#)
        #expect(root.children[0].key == "k\"ey" && root.children[0].value == "line\nbreak é 😀")
    }

    @Test func commentsAndTrailingCommasAreAccepted() throws {
        let root = try parse("{\n  // a comment\n  \"a\": 1, /* inline */\n  \"b\": [2,],\n}\n")
        #expect(root.children.map(\.key) == ["a", "b"] && root.children[1].children.count == 1)
    }

    @Test func errorsSayWhereAndWhat() {
        guard case .failure(let error) = JSONParser.parse("{\n  \"a\": 1\n  \"b\": 2\n}") else { Issue.record("parsed"); return }
        #expect(error.line == 3 && error.message == "Expected a comma or }")
        guard case .failure(let open) = JSONParser.parse("[1, \"open") else { Issue.record("parsed"); return }
        #expect(open.message == "This string has no closing quote")
        guard case .failure(let extra) = JSONParser.parse("{} x") else { Issue.record("parsed"); return }
        #expect(extra.message == "Unexpected text after the end")
    }

    @Test func scalarsAtTheTop() throws {
        #expect(try parse("  42 ").kind == .number)
        #expect(try parse("\"s\"").value == "s")
    }
}

@Suite struct JSONTreeEdits {
    @Test func settingAValueKeepsStringsStrings() throws {
        let text = #"{"a": "x", "b": 1, "c": null}"#
        let root = try parse(text)
        #expect(apply(JSONEdits.setValue(root.children[0], typed: "5"), to: text) == #"{"a": "5", "b": 1, "c": null}"#)
        #expect(apply(JSONEdits.setValue(root.children[1], typed: "5"), to: text) == #"{"a": "x", "b": 5, "c": null}"#)
        #expect(apply(JSONEdits.setValue(root.children[1], typed: "five \"5\""), to: text) == #"{"a": "x", "b": "five \"5\"", "c": null}"#)
        #expect(apply(JSONEdits.setValue(root.children[2], typed: "true"), to: text) == #"{"a": "x", "b": 1, "c": true}"#)
    }

    @Test func renamingAKey() throws {
        let text = #"{"a": 1}"#
        #expect(apply(JSONEdits.rename(try parse(text).children[0], to: "b c"), to: text) == #"{"b c": 1}"#)
    }

    @Test func deletingKeepsCommasLinesAndComments() throws {
        let text = "{\n  \"a\": 1,\n  // about b\n  \"b\": 2,\n  \"c\": 3\n}\n"
        let root = try parse(text)
        #expect(applyAll(JSONEdits.delete(root.children[0], in: text), to: text) == "{\n  // about b\n  \"b\": 2,\n  \"c\": 3\n}\n")
        #expect(applyAll(JSONEdits.delete(root.children[1], in: text), to: text) == "{\n  \"a\": 1,\n  // about b\n  \"c\": 3\n}\n")
        #expect(applyAll(JSONEdits.delete(root.children[2], in: text), to: text) == "{\n  \"a\": 1,\n  // about b\n  \"b\": 2\n}\n")
        let compact = #"[1, 2, 3]"#
        #expect(applyAll(JSONEdits.delete(try parse(compact).children[1], in: compact), to: compact) == "[1, 3]")
        let only = #"{"a": 1}"#
        #expect(applyAll(JSONEdits.delete(try parse(only).children[0], in: only), to: only) == "{}")
    }

    @Test func addingAfterASiblingFollowsTheIndentation() throws {
        let text = "{\n    \"a\": 1,\n    \"b\": 2\n}"
        let root = try parse(text)
        #expect(apply(JSONEdits.insert(after: root.children[0], key: "new", in: text), to: text) == "{\n    \"a\": 1,\n    \"new\": null,\n    \"b\": 2\n}")
        #expect(apply(JSONEdits.insert(after: root.children[1], key: "new", in: text), to: text) == "{\n    \"a\": 1,\n    \"b\": 2,\n    \"new\": null\n}")
        let compact = #"[1, 2]"#
        #expect(apply(JSONEdits.insert(after: try parse(compact).children[0], key: nil, in: compact), to: compact) == "[1, null, 2]")
    }

    @Test func addingAChild() throws {
        let empty = #"{"a": {}}"#
        #expect(apply(JSONEdits.addChild(to: try parse(empty).children[0], key: "k", in: empty), to: empty) == #"{"a": {"k": null}}"#)
        let lines = "{\n  \"list\": [\n    1\n  ]\n}"
        #expect(apply(JSONEdits.addChild(to: try parse(lines).children[0], key: nil, in: lines), to: lines) == "{\n  \"list\": [\n    1,\n    null\n  ]\n}")
        let emptyLines = "{\n  \"o\": {\n  }\n}"
        #expect(apply(JSONEdits.addChild(to: try parse(emptyLines).children[0], key: "k", in: emptyLines), to: emptyLines) == "{\n  \"o\": {\n    \"k\": null\n  }\n}")
    }

    @Test func movingKeepsTheSeparatorsInPlace() throws {
        let text = "{\n  \"a\": 1, // one\n  \"b\": 2,\n  \"c\": 3\n}"
        let root = try parse(text)
        #expect(apply(JSONEdits.move(root.children[2], to: 0, in: text), to: text) == "{\n  \"c\": 3, // one\n  \"a\": 1,\n  \"b\": 2\n}")
    }

    @Test func aFreshKeyIsUnique() throws {
        let root = try parse(#"{"key": 1, "key 2": 2}"#)
        #expect(JSONEdits.freshKey(in: root) == "key 3")
    }
}

/// Found in review: comments and commas around deletes, CRLF, comment-only containers, strict numbers, surrogates.
@Suite struct JSONReviewFixes {
    @Test func deletingTheLastItemKeepsThePreviousComment() throws {
        let text = "{\n  \"a\": 1, // about a\n  \"b\": 2\n}"
        let root = try parse(text)  // a node holds its parent weakly, so the tree is kept
        let result = applyAll(JSONEdits.delete(root.children[1], in: text), to: text)
        #expect(result == "{\n  \"a\": 1 // about a\n}")
    }

    @Test func aCommentBeforeTheCommaStillLeavesValidJSON() throws {
        let text = "[1 /* one */, 2]"
        let result = applyAll(JSONEdits.delete(try parse(text).children[0], in: text), to: text)
        #expect(try parse(result).children.count == 1)
    }

    @Test func crlfLinesGoWhole() throws {
        let text = "{\r\n  \"a\": 1,\r\n  \"b\": 2\r\n}"
        #expect(applyAll(JSONEdits.delete(try parse(text).children[0], in: text), to: text) == "{\r\n  \"b\": 2\r\n}")
    }

    @Test func aChildGoesBesideAComment() throws {
        let text = #"{"o": { /* todo */ }}"#
        #expect(apply(JSONEdits.addChild(to: try parse(text).children[0], key: "k", in: text), to: text) == #"{"o": { /* todo */ "k": null }}"#)
    }

    @Test func malformedNumbersAreErrors() {
        for bad in ["[01]", "[1.]", "[-]", "[1.2.3]", "[1e]"] {
            if case .success = JSONParser.parse(bad) { Issue.record("\(bad) parsed") }
        }
    }

    @Test func aLoneHighSurrogateKeepsWhatFollows() throws {
        #expect(try parse(#"["\ud83dA"]"#).children[0].value == "\u{FFFD}A")
    }
}
