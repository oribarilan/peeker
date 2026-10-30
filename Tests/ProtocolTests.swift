import Foundation
import Testing

@Suite struct ProtocolTests {
    @Test func requestRoundTrips() throws {
        let request = Request(id: 7, doc: "d1", call: .save(.text(SharedFileRef(path: "/tmp/x", byteCount: 3), convertToUTF8: true)))
        let decoded = try JSONDecoder().decode(Request.self, from: JSONEncoder().encode(request))
        #expect(decoded.id == 7)
        guard case .save(.text(let ref, let convert)) = decoded.call else { Issue.record("wrong call"); return }
        #expect(ref.byteCount == 3 && convert)
    }

    @Test func failureCarriesItsCode() throws {
        let response = Response(id: 1, outcome: .failure(PluginFailure("no", code: .cannotEncode)))
        let decoded = try JSONDecoder().decode(Response.self, from: JSONEncoder().encode(response))
        guard case .failure(let failure) = decoded.outcome else { Issue.record("wrong outcome"); return }
        #expect(failure == PluginFailure("no", code: .cannotEncode))
    }

    @Test func markdownTreeRoundTrips() throws {
        let blocks: [MarkdownBlock] = [.heading(level: 1, spans: [Span(text: "T", style: .strong, link: nil)], line: 1),
                                       .list(ordered: false, start: 1, items: [ListItem(blocks: [.paragraph([])], line: 2, checked: true)]),
                                       .code(text: "x", language: nil), .code(text: "y", language: "swift"), .quote([.rule]),
                                       .table([[[Span(text: "c", style: [], link: nil)]]])]
        #expect(try JSONDecoder().decode([MarkdownBlock].self, from: JSONEncoder().encode(blocks)) == blocks)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(MarkdownBlock.self, from: Data(#"["z"]"#.utf8)) }
    }

    @Test func spansAndListItemsUseCompactArrays() throws {
        let spans = [Span(text: "a", style: .strong, link: nil), Span(text: "b", style: [], link: "https://x")]
        #expect(String(decoding: try JSONEncoder().encode(spans), as: UTF8.self) == #"[["a",1],["b",0,"https:\/\/x"]]"#)
        #expect(try JSONDecoder().decode([Span].self, from: JSONEncoder().encode(spans)) == spans)
        let items = [ListItem(blocks: [.paragraph(spans)], line: 3, checked: nil), ListItem(blocks: [], line: 4, checked: false)]
        #expect(try JSONDecoder().decode([ListItem].self, from: JSONEncoder().encode(items)) == items)
    }

    @Test func unknownCallIsRejected() {
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(Request.self, from: Data(#"{"id":1,"doc":"d","call":{"explode":{}}}"#.utf8)) }
    }

    @Test func pluginFallbackFailureDecodesWithTheRequestID() throws {
        let response = try JSONDecoder().decode(Response.self, from: PluginMain.fallbackFailure(id: 42))
        #expect(response.id == 42)
        guard case .failure(let failure) = response.outcome else { Issue.record("wrong outcome"); return }
        #expect(!failure.message.isEmpty)
    }

    @Test func unreadableRequestWithAnIDGetsAFailureReply() throws {
        let line = #"{"id":5,"doc":"d","call":{"explode":{}}}"#
        let data = try #require(PluginMain.response(to: line, NoHandler(), JSONDecoder(), JSONEncoder()))
        let response = try JSONDecoder().decode(Response.self, from: data)
        #expect(response.id == 5)
        guard case .failure(let failure) = response.outcome else { Issue.record("wrong outcome"); return }
        #expect(failure.message.hasPrefix("unreadable request"))
    }

    @Test func unreadableRequestWithoutAnIDGetsNoReply() {
        #expect(PluginMain.response(to: "not json", NoHandler(), JSONDecoder(), JSONEncoder()) == nil)
    }
}

private struct NoHandler: PluginHandler {
    func open(_ doc: DocumentID, path: String, maxPixels: Int) throws(PluginFailure) -> Reply { Reply() }
}
