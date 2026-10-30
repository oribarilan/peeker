import Foundation
import Testing

/// The README's config example is the one most people copy, so it has to be valid.
@Suite struct ReadmeConfigTests {
    @Test func theReadmeExampleHasNoProblems() throws {
        let readme = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appending(path: "README.md")
        let text = try String(contentsOf: readme, encoding: .utf8)
        let section = try #require(text.range(of: "## Config\n")).upperBound
        let start = try #require(text.range(of: "```json\n", range: section..<text.endIndex)).upperBound
        let end = try #require(text.range(of: "```", range: start..<text.endIndex)).lowerBound
        let reading = Config.read(Data(text[start..<end].utf8), plugins: PluginCatalog.builtIn.map { PluginEntry($0) })
        #expect(reading.config != nil)
        #expect(reading.problems.isEmpty, "\(reading.problems)")
    }
}
