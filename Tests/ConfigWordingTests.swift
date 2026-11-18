import Foundation
import PeekerKit
import PeekerMarkdown
import PeekerText
import Testing

/// Config problems call a plugin a format, as Settings does; key paths keep `plugins`.
@Suite struct ConfigWordingTests {
    private let plugins = [PluginEntry(MarkdownPlugin.self), PluginEntry(TextPlugin.self)]

    private func problems(_ json: String) -> [ConfigProblem] {
        Config.read(Data(json.utf8), plugins: plugins).problems
    }

    @Test func anExtensionInTwoListsBelongsToAFormat() {
        let found = problems(#"{"plugins": {"text": {"extensions": ["txt", "md"]}}}"#)
        #expect(found.map(\.path) == ["plugins.text.extensions"])
        #expect(found.first?.message == "“md” belongs to the Markdown format, so Plain Text doesn't open it.")
    }

    @Test func anUnknownIdIsNoFormat() {
        let found = problems(#"{"plugins": {"mardown": {"enabled": false}}}"#)
        #expect(found.map(\.path) == ["plugins.mardown"])
        #expect(found.first?.message == "There's no format “mardown”. Formats: markdown, text.")
    }

    @Test func anUnknownToolNamesTheFormat() {
        let found = problems(#"{"plugins": {"markdown": {"tools": {"nope": {"shortcut": "cmd+j"}}}}}"#)
        #expect(found.first?.message.hasPrefix("The Markdown format has no tool “nope”") == true)
    }
}
