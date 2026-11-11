import AppKit
import PeekerKit
@testable import PeekerMarkdown
@testable import PeekerText
import Testing

@MainActor private func pointSize(_ document: any PluginDocument) -> CGFloat? {
    let view = document.focusView as? NSTextView
    return view?.textStorage?.length ?? 0 > 0
        ? view?.textStorage?.attribute(.font, at: 0, effectiveRange: nil).flatMap { ($0 as? NSFont)?.pointSize } : view?.font?.pointSize
}

@Suite struct PluginPreferenceStore {
    @Test func keysAreKeptUnderThePluginID() {
        let scratch = ScratchDefaults()
        defer { scratch.close() }
        let preferences = scratch.preferences("text")
        #expect(preferences.double("fontSize") == nil && preferences.bool("wraps") == nil)
        preferences.set(15.0, for: "fontSize")
        preferences.set(false, for: "wraps")
        #expect(preferences.double("fontSize") == 15 && preferences.bool("wraps") == false)
        #expect(scratch.defaults.double(forKey: "plugins.text.fontSize") == 15)
        #expect(scratch.preferences("markdown").double("fontSize") == nil, "another plugin's are its own")
    }

    @Test func anOpenContextHasNoneUnlessGiven() {
        #expect(OpenContext(maxPixels: 0, allowsEditing: true).preferences == nil)
    }
}

/// Records the context it's opened with.
private enum ContextProbe: Plugin {
    static let id = "probe", name = "Probe", defaultExtensions = ["probe"], tools: [ToolSpec] = []
    nonisolated(unsafe) static var context: OpenContext?
    static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument {
        self.context = context
        return ProbeDocument()
    }
}

@MainActor private final class ProbeDocument: PluginDocument {
    let contentView = NSView()
}

@Suite(.serialized) struct HostPluginPreferences {
    @Test func theHostPassesItsPreferencesUnderThePluginID() async throws {
        let scratch = ScratchDefaults()
        defer { scratch.close() }
        let url = try TempFile.make(Data("x".utf8), name: "f.probe")
        let document = DocumentViewController(
            url: url, entry: PluginEntry(ContextProbe.self), config: Config(), allowsEditing: false,
            recovery: nil, preferences: scratch.defaults)
        document.loadViewIfNeeded()
        await document.load()
        ContextProbe.context?.preferences?.set(3.0, for: "x")
        #expect(scratch.defaults.double(forKey: "plugins.probe.x") == 3)
    }

    @Test func withoutPreferencesThePluginGetsNone() async throws {
        let url = try TempFile.make(Data("x".utf8), name: "f.probe")
        let document = DocumentViewController(url: url, entry: PluginEntry(ContextProbe.self), config: Config(), allowsEditing: false, recovery: nil)
        document.loadViewIfNeeded()
        await document.load()
        #expect(ContextProbe.context != nil && ContextProbe.context?.preferences == nil)
    }
}

@Suite(.serialized) struct RememberedPlainText {
    @Test func zoomAndWrapCarryToTheNextFile() async throws {
        let scratch = ScratchDefaults()
        defer { scratch.close() }
        let first = try await openDocument(
            try TempFile.make(Data("a\n".utf8), name: "a.log"), with: TextPlugin.self, as: TextDocument.self,
            preferences: scratch.preferences("text"))
        #expect(first.perform("zoom-in") && first.perform("zoom-in") && first.perform("toggle-wrap"))
        let next = try await openDocument(
            try TempFile.make(Data("b\n".utf8), name: "b.log"), with: TextPlugin.self, as: TextDocument.self,
            editing: false, preferences: scratch.preferences("text"))
        #expect(pointSize(next) == 14)
        #expect(next.isOn("toggle-wrap") == false)
    }

    @Test func aStoredSizeOutOfRangeIsIgnored() async throws {
        let scratch = ScratchDefaults()
        defer { scratch.close() }
        scratch.preferences("text").set(500.0, for: "fontSize")
        let document = try await openDocument(
            try TempFile.make(Data("a\n".utf8), name: "a.txt"), with: TextPlugin.self, as: TextDocument.self,
            preferences: scratch.preferences("text"))
        #expect(pointSize(document) == 12)
    }

    @Test func actualSizeGoesToTheDefaultAndIsKept() async throws {
        let scratch = ScratchDefaults()
        defer { scratch.close() }
        scratch.preferences("text").set(20.0, for: "fontSize")
        let document = try await openDocument(
            try TempFile.make(Data("a\n".utf8), name: "a.txt"), with: TextPlugin.self, as: TextDocument.self,
            preferences: scratch.preferences("text"))
        #expect(pointSize(document) == 20)
        #expect(document.perform("zoom-actual"))
        #expect(pointSize(document) == 12 && scratch.preferences("text").double("fontSize") == 12)
    }

    @Test func withoutPreferencesNothingIsKept() async throws {
        let before = UserDefaults.standard.object(forKey: "plugins.text.fontSize") as? Double
        let document = try await openDocument(try TempFile.make(Data("a\n".utf8), name: "a.txt"), with: TextPlugin.self, as: TextDocument.self)
        #expect(document.perform("zoom-in"))
        #expect(UserDefaults.standard.object(forKey: "plugins.text.fontSize") as? Double == before)
    }
}

@Suite(.serialized) struct RememberedMarkdownSize {
    @Test func aZoomInTheEditorCarriesToTheNextFileAndThePeekPanel() async throws {
        let scratch = ScratchDefaults()
        defer { scratch.close() }
        let editor = try await openDocument(
            try TempFile.make(Data("Hello\n".utf8), name: "a.md"), with: MarkdownPlugin.self, as: MarkdownEditor.self,
            preferences: scratch.preferences("markdown"))
        #expect(editor.perform("zoom-in") && editor.perform("zoom-in"))
        #expect(scratch.preferences("markdown").double("textSize") == 16)
        let next = try await openDocument(
            try TempFile.make(Data("Hi\n".utf8), name: "b.md"), with: MarkdownPlugin.self, as: MarkdownEditor.self,
            preferences: scratch.preferences("markdown"))
        #expect(pointSize(next) == 16)
        let panel = try await openDocument(
            try TempFile.make(Data("Hi\n".utf8), name: "c.md"), with: MarkdownPlugin.self, as: MarkdownDocument.self,
            editing: false, preferences: scratch.preferences("markdown"))
        #expect(pointSize(panel) == 16, "body text at the remembered size")
    }

    @Test func actualSizeGoesTo14() async throws {
        let scratch = ScratchDefaults()
        defer { scratch.close() }
        scratch.preferences("markdown").set(20.0, for: "textSize")
        let editor = try await openDocument(
            try TempFile.make(Data("Hello\n".utf8), name: "a.md"), with: MarkdownPlugin.self, as: MarkdownEditor.self,
            preferences: scratch.preferences("markdown"))
        #expect(pointSize(editor) == 20)
        #expect(editor.perform("zoom-actual"))
        #expect(pointSize(editor) == 14 && scratch.preferences("markdown").double("textSize") == 14)
    }
}
