import AppKit
import PeekerKit
@testable import PeekerMarkdown
import PeekerText
import Testing

/// A folder of linked files for following links: README.md (with an Install heading far down), other.md (with a
/// Setup heading far down), notes.txt and report.numbers.
struct LinkedFiles {
    let folder: URL
    var readme: URL { folder.appending(path: "README.md") }
    var other: URL { folder.appending(path: "other.md") }
    var notes: URL { folder.appending(path: "notes.txt") }
    var report: URL { folder.appending(path: "report.numbers") }

    static let filler = (1...60).map { "Line \($0) of filler text.\n" }.joined()
    static let readmeText = "# Readme\n\n[i](#install) [o](other.md) [s](other.md#setup) [t](notes.txt)\n\n\(filler)\n## Install\n\nsteps\n"
    static let otherText = "# Other\n\n\(filler)\n## Setup\n\nmore\n"

    init() throws {
        folder = try TempFile.make(Data(Self.readmeText.utf8), name: "README.md").deletingLastPathComponent()
        try Data(Self.otherText.utf8).write(to: other)
        try Data("notes\n".utf8).write(to: notes)
        try Data("x".utf8).write(to: report)
    }

    /// `name` with `#place` when given, as a document hands a link to the host.
    func link(_ name: String, _ place: String? = nil) -> URL {
        let file = folder.appending(path: name)
        return place.map { URL(string: "#\($0)", relativeTo: file)!.absoluteURL } ?? file
    }
}

/// What a window's links did outside the tab.
@MainActor final class LinkEffects {
    var beeps = 0
    var ownTabs: [(URL, String?)] = []
    var asked: [URL] = []
    var broughtForward: [DocumentWindowController] = []
}

/// An off-screen Editor window on `file`, Markdown and Plain Text enabled, its effects recorded rather than shown.
@MainActor func linkedWindow(_ file: URL, effects: LinkEffects, config: Config = Config(),
                             recovery: RecoveryStore? = nil) async throws -> DocumentWindowController {
    let entries = [PluginEntry(MarkdownPlugin.self), PluginEntry(TextPlugin.self)]
    let controller = DocumentWindowController(url: file, catalog: PluginCatalog(entries: entries, config: config), config: config,
                                              recovery: recovery, recoveryClipboard: nil, sidebarMemory: SidebarMemory(defaults: nil))
    controller.beep = { effects.beeps += 1 }
    controller.openInOwnTab = { effects.ownTabs.append(($0, $1)) }
    controller.confirmOpenElsewhere = { _, url in
        effects.asked.append(url)
        return false
    }
    controller.bringForward = { effects.broughtForward.append($0) }
    controller.show(with: entries[0])
    try await waitUntil(seconds: 2) { controller.current?.hasShownContent == true }
    return controller
}

@MainActor extension DocumentWindowController {
    var editor: MarkdownEditor? { current?.pluginDocument as? MarkdownEditor }
    var cursor: Int? { (editor?.focusView as? NSTextView)?.selectedRange().location }
    var labels: [String] { history.entries.map(\.label) }

    /// Waits until the tab shows `file` with its content on screen.
    func waitForFile(_ file: URL, sourceLocation: SourceLocation = #_sourceLocation) async throws {
        try await waitUntil(seconds: 2, sourceLocation: sourceLocation) {
            url.path == file.path && current?.url.path == file.path && current?.hasShownContent == true
        }
    }

    /// Types `text` over the whole Markdown document.
    func typeMarkdown(_ text: String) throws {
        #expect(try #require(editor).restore(encoded: JSONEncoder().encode(TextEdits.text(text))))
    }
}

/// The UTF-16 offset of `needle` in `text`.
func offset(of needle: String, in text: String) -> Int { (text as NSString).range(of: needle).location }
