import AppKit
import PeekerKit
@testable import PeekerImage
@testable import PeekerMarkdown
@testable import PeekerText
import Testing

/// With "Show scroll bars: Always" in System Settings, a scroll view that doesn't hide its scroll bars draws an empty
/// track beside content that fits, as the Peek panel did under its Open in Peeker button.
@MainActor private func scrollViews(in document: any PluginDocument) -> [NSScrollView] {
    func all(_ view: NSView) -> [NSScrollView] { (view as? NSScrollView).map { [$0] } ?? [] + view.subviews.flatMap(all) }
    return ([document.contentView] + document.makeSidebar().map(\.view)).flatMap(all)
}

@Suite(.serialized) struct ScrollBarsHideWhenNothingScrolls {
    @Test(arguments: [true, false])
    func markdownInTheEditorAndThePanel(editing: Bool) async throws {
        let url = try TempFile.make(Data("# Notes\n\nShort.\n\n## Later\n".utf8), name: "notes.md")
        let document = try await openDocument(url, with: MarkdownPlugin.self, as: (any PluginDocument).self, editing: editing)
        let views = scrollViews(in: document)
        #expect(!views.isEmpty)
        #expect(views.filter { !$0.autohidesScrollers }.isEmpty, "\(views)")
    }

    @Test(arguments: [true, false])
    func plainText(editing: Bool) async throws {
        let url = try TempFile.make(Data("short\n".utf8), name: "notes.txt")
        let document = try await openDocument(url, with: TextPlugin.self, as: (any PluginDocument).self, editing: editing)
        #expect(scrollViews(in: document).filter { !$0.autohidesScrollers }.isEmpty)
    }

    @Test func anImageAndATIFFsPages() async throws {
        let image = try await openDocument(
            try imageFile(try cornerImage(), type: .png), with: ImagePlugin.self,
            as: (any PluginDocument).self, maxPixels: 1000)
        #expect(scrollViews(in: image).filter { !$0.autohidesScrollers }.isEmpty)
        let pages = try await openDocument(
            try multiPageTIFF([(40, 20), (20, 40)]), with: ImagePlugin.self,
            as: (any PluginDocument).self, maxPixels: 1000)
        let views = scrollViews(in: pages)
        #expect(views.count >= 2, "the image and the page list")
        #expect(views.filter { !$0.autohidesScrollers }.isEmpty, "\(views)")
    }
}
