import AppKit
import PeekerKit
@testable import PeekerMarkdown
import PeekerText
import Testing

@Suite(.serialized) struct DocumentLinkForwarding {
    @Test func aDocumentThatFollowsLinksHandsThemToTheHost() async throws {
        let files = try LinkedFiles()
        let document = await loadedDocument(files.readme, with: MarkdownPlugin.self)
        defer { document.close() }
        var followed: [URL] = []
        document.onFollowLink = { _, link in followed.append(link) }
        let following = try #require(document.pluginDocument as? any LinkFollowing)
        following.onFollowLink?(files.other)
        #expect(followed == [files.other])
    }

    @Test func aDocumentThatDoesntIsLeftAlone() async throws {
        let files = try LinkedFiles()
        let document = await loadedDocument(files.notes, with: TextPlugin.self)
        defer { document.close() }
        #expect(document.pluginDocument != nil && !(document.pluginDocument is any LinkFollowing))
    }
}

@Suite(.serialized) struct FollowingLinksInAWindow {
    @Test func aHeadingLinkMovesTheViewAndAddsAPlace() async throws {
        let files = try LinkedFiles(), effects = LinkEffects()
        let controller = try await linkedWindow(files.readme, effects: effects)
        defer { controller.close() }
        await controller.follow(files.link("README.md", "install"))
        #expect(controller.cursor == offset(of: "## Install", in: LinkedFiles.readmeText))
        #expect(controller.labels == ["README.md", "Install"])
        await controller.follow(files.link("README.md", "missing"))
        #expect(effects.beeps == 1 && controller.history.entries.count == 2)
    }

    /// Like a browser: the heading lands at the top of the text, below the toolbar and the trail.
    @Test func aHeadingLinkPutsTheHeadingAtTheTop() async throws {
        let text = "# Top\n\n" + LinkedFiles.filler + "\n## Middle\n\n" + LinkedFiles.filler
        let file = try TempFile.make(Data(text.utf8), name: "middle.md")
        let controller = try await linkedWindow(file, effects: LinkEffects())
        defer { controller.close() }
        try #require(controller.window).setContentSize(NSSize(width: 700, height: 300))
        await controller.follow(URL(string: "#middle", relativeTo: file)!.absoluteURL)
        let textView = try #require(controller.editor?.focusView as? NSTextView)
        let layoutManager = try #require(textView.layoutManager)
        let heading = layoutManager.lineFragmentRect(forGlyphAt: layoutManager.glyphIndexForCharacter(at: offset(of: "## Middle", in: text)),
                                                     effectiveRange: nil).minY + textView.textContainerOrigin.y
        let clip = try #require(controller.editor?.contentView as? NSScrollView).contentView
        #expect(abs(heading - (clip.bounds.minY + clip.contentInsets.top)) < 1)
    }

    @Test func aMarkdownLinkShowsTheFileInTheSameTab() async throws {
        let files = try LinkedFiles(), effects = LinkEffects()
        let controller = try await linkedWindow(files.readme, effects: effects)
        defer { controller.close() }
        await controller.follow(files.link("other.md"))
        try await controller.waitForFile(files.other)
        #expect(controller.window?.title == "other.md" && controller.window?.representedURL?.path == files.other.path)
        #expect(controller.editor?.text == LinkedFiles.otherText)
        #expect(controller.labels == ["README.md", "other.md"])
        #expect(AppDelegate.window(showing: files.other, in: [controller]) === controller)
        #expect(AppDelegate.window(showing: files.readme, in: [controller]) == nil)
        let openWith = NSMenu()
        controller.fillOpenWith(openWith)
        #expect(openWith.items.map(\.title) == ["Markdown", "Plain Text"])
    }

    @Test func aLinkToAHeadingInAnotherFileLandsOnIt() async throws {
        let files = try LinkedFiles(), effects = LinkEffects()
        let controller = try await linkedWindow(files.readme, effects: effects)
        defer { controller.close() }
        await controller.follow(files.link("other.md", "setup"))
        try await controller.waitForFile(files.other)
        try await waitUntil(seconds: 2) { controller.cursor == offset(of: "## Setup", in: LinkedFiles.otherText) }
        #expect(controller.labels == ["README.md", "Setup"])
    }

    @Test func aTextFileOpensInItsOwnTab() async throws {
        let files = try LinkedFiles(), effects = LinkEffects()
        let controller = try await linkedWindow(files.readme, effects: effects)
        defer { controller.close() }
        await controller.follow(files.link("notes.txt"))
        #expect(effects.ownTabs.map(\.0.path) == [files.notes.path])
        #expect(controller.url == files.readme && controller.history.entries.count == 1)
    }

    @Test func aFileNoPluginOpensAsksFirst() async throws {
        let files = try LinkedFiles(), effects = LinkEffects()
        let controller = try await linkedWindow(files.readme, effects: effects)
        defer { controller.close() }
        await controller.follow(files.link("report.numbers"))
        #expect(effects.asked.map(\.path) == [files.report.path] && controller.history.entries.count == 1)
        await controller.follow(files.link("gone.md"))
        #expect(effects.beeps == 1 && controller.url == files.readme)
    }

    @Test func aFileOpenInAnotherWindowComesForward() async throws {
        let files = try LinkedFiles(), effects = LinkEffects()
        let controller = try await linkedWindow(files.readme, effects: effects)
        let other = try await linkedWindow(files.other, effects: LinkEffects())
        defer { controller.close(); other.close() }
        controller.otherWindow = { AppDelegate.window(showing: $0, in: [other]) }
        await controller.follow(files.link("other.md"))
        #expect(effects.broughtForward.map(ObjectIdentifier.init) == [ObjectIdentifier(other)])
        #expect(controller.url == files.readme && controller.history.entries.count == 1)
    }
}

@Suite(.serialized) struct BackAndForward {
    @Test func backReturnsToTheEarlierFileWhereItWasLeft() async throws {
        let files = try LinkedFiles(), effects = LinkEffects()
        let controller = try await linkedWindow(files.readme, effects: effects)
        defer { controller.close() }
        let window = try #require(controller.window)
        window.setContentSize(NSSize(width: 700, height: 300))
        let textView = try #require(controller.editor?.focusView as? NSTextView)
        textView.scrollRangeToVisible(NSRange(location: offset(of: "Line 40 ", in: LinkedFiles.readmeText), length: 0))
        // The top of the text below the toolbar and the trail, which shows only once there's history.
        let visibleTop = { () -> CGFloat in
            guard let clip = (controller.editor?.contentView as? NSScrollView)?.contentView else { return 0 }
            return clip.bounds.minY + clip.contentInsets.top
        }
        let top = visibleTop()
        #expect(top > 0)
        await controller.follow(files.link("other.md"))
        try await controller.waitForFile(files.other)
        await controller.move(to: 0)
        try await controller.waitForFile(files.readme)
        try await waitUntil(seconds: 2) {
            abs(visibleTop() - top) < 1
        }
        #expect(window.title == "README.md" && controller.history.canGoForward)
    }

    @Test func severalStepsLandOnTheRightPlace() async throws {
        let files = try LinkedFiles(), effects = LinkEffects()
        let controller = try await linkedWindow(files.readme, effects: effects)
        defer { controller.close() }
        await controller.follow(files.link("README.md", "install"))
        await controller.follow(files.link("other.md"))
        try await controller.waitForFile(files.other)
        await controller.move(to: 1)
        try await controller.waitForFile(files.readme)
        await controller.move(to: 0)
        await controller.move(to: 1)
        #expect(controller.history.index == 1 && controller.url == files.readme)
        #expect(controller.cursor == offset(of: "## Install", in: LinkedFiles.readmeText))
    }

    @Test func aNewJumpAfterBackDropsWhatWasAhead() async throws {
        let files = try LinkedFiles(), effects = LinkEffects()
        let controller = try await linkedWindow(files.readme, effects: effects)
        defer { controller.close() }
        await controller.follow(files.link("other.md"))
        try await controller.waitForFile(files.other)
        await controller.move(to: 0)
        try await controller.waitForFile(files.readme)
        await controller.follow(files.link("README.md", "install"))
        #expect(controller.labels == ["README.md", "Install"] && !controller.history.canGoForward)
    }

    @Test func backWithinOneFileOnlyMovesTheView() async throws {
        let files = try LinkedFiles(), effects = LinkEffects()
        let controller = try await linkedWindow(files.readme, effects: effects)
        defer { controller.close() }
        let editor = try #require(controller.editor)
        await controller.follow(files.link("README.md", "install"))
        await controller.move(to: 0)
        #expect(controller.editor === editor && controller.cursor == 0)
        await controller.move(to: 1)
        #expect(controller.cursor == offset(of: "## Install", in: LinkedFiles.readmeText))
    }

    @Test func backToADeletedFileBeepsAndStays() async throws {
        let files = try LinkedFiles(), effects = LinkEffects()
        let controller = try await linkedWindow(files.readme, effects: effects)
        defer { controller.close() }
        await controller.follow(files.link("other.md"))
        try await controller.waitForFile(files.other)
        try FileManager.default.removeItem(at: files.readme)
        await controller.move(to: 0)
        #expect(effects.beeps == 1 && controller.history.index == 1 && controller.url == files.other)
    }

    @Test func backToAFileWhosePluginIsOffBeepsAndStays() async throws {
        let files = try LinkedFiles(), effects = LinkEffects()
        let controller = try await linkedWindow(files.readme, effects: effects)
        defer { controller.close() }
        await controller.follow(files.link("other.md"))
        try await controller.waitForFile(files.other)
        await controller.reopen(with: try #require(controller.catalog.enabled.first { $0.id == "text" }))
        var config = Config()
        config.disabled = ["markdown"]
        controller.catalog.reload(config: config)
        await controller.move(to: 0)
        #expect(effects.beeps == 1 && controller.history.index == 1)
    }

    @Test func backReturnsWithThePluginAFileWasShownWith() async throws {
        let files = try LinkedFiles(), effects = LinkEffects()
        let controller = try await linkedWindow(files.readme, effects: effects)
        defer { controller.close() }
        await controller.follow(files.link("other.md"))
        try await controller.waitForFile(files.other)
        await controller.reopen(with: try #require(controller.catalog.enabled.first { $0.id == "text" }))
        #expect(controller.current?.entry.id == "text")
        await controller.move(to: 0)
        try await controller.waitForFile(files.readme)
        #expect(controller.current?.entry.id == "markdown")
        await controller.move(to: 1)
        try await controller.waitForFile(files.other)
        #expect(controller.current?.entry.id == "text")
    }
}

@Suite(.serialized) struct LeavingEditedFiles {
    private func edited(_ answer: DocumentWindowController.UnsavedChoice) async throws -> (LinkedFiles, DocumentWindowController, () -> Int) {
        let files = try LinkedFiles(), effects = LinkEffects()
        let controller = try await linkedWindow(files.readme, effects: effects)
        var asked = 0
        controller.askToSave = { _ in
            asked += 1
            return answer
        }
        try controller.typeMarkdown("# Typed\n")
        #expect(controller.current?.isEdited == true)
        return (files, controller, { asked })
    }

    @Test func cancelKeepsTheFileItsEditsAndTheHistory() async throws {
        let (files, controller, asked) = try await edited(.cancel)
        defer { controller.close() }
        await controller.follow(files.link("other.md"))
        #expect(asked() == 1)
        #expect(controller.url == files.readme && controller.editor?.text == "# Typed\n" && controller.history.entries.count == 1)
    }

    @Test func dontSaveGoesOnAndBackShowsTheSavedText() async throws {
        let (files, controller, asked) = try await edited(.discard)
        defer { controller.close() }
        await controller.follow(files.link("other.md"))
        try await controller.waitForFile(files.other)
        #expect(asked() == 1)
        await controller.move(to: 0)
        try await controller.waitForFile(files.readme)
        #expect(controller.editor?.text == LinkedFiles.readmeText)
    }

    @Test func saveWritesThenGoesOn() async throws {
        let (files, controller, _) = try await edited(.save)
        defer { controller.close() }
        await controller.follow(files.link("other.md"))
        try await controller.waitForFile(files.other)
        #expect(try String(contentsOf: files.readme, encoding: .utf8) == "# Typed\n")
    }

    @Test func backForwardAndCrumbsAskToo() async throws {
        let files = try LinkedFiles(), effects = LinkEffects()
        let controller = try await linkedWindow(files.readme, effects: effects)
        defer { controller.close() }
        var asked = 0
        controller.askToSave = { _ in
            asked += 1
            return .cancel
        }
        await controller.follow(files.link("other.md"))
        try await controller.waitForFile(files.other)
        try controller.typeMarkdown("# Typed\n")
        await controller.move(to: 0)
        #expect(asked == 1 && controller.url == files.other && controller.history.index == 1)
    }

    @Test func aHeadingInAnEditedFileNeverAsks() async throws {
        let files = try LinkedFiles(), effects = LinkEffects()
        let controller = try await linkedWindow(files.readme, effects: effects)
        defer { controller.close() }
        var asked = 0
        controller.askToSave = { _ in
            asked += 1
            return .cancel
        }
        try controller.typeMarkdown(LinkedFiles.readmeText + "more\n")
        await controller.restyleEditor()
        await controller.follow(files.link("README.md", "install"))
        await controller.move(to: 0)
        #expect(asked == 0 && controller.history.entries.count == 2)
    }
}

@Suite(.serialized) struct HistoryAndRecovery {
    @Test func aRecoveredWindowStartsWithNoHistory() async throws {
        let files = try LinkedFiles(), store = RecoveryStore.temporary()
        let controller = try await linkedWindow(files.readme, effects: LinkEffects(), recovery: store)
        await controller.follow(files.link("README.md", "install"))
        await controller.follow(files.link("other.md"))
        try await controller.waitForFile(files.other)
        try controller.typeMarkdown("# Edited other\n")
        controller.window?.close()  // closed without the prompt keeps the edits, as a crash's journal would
        try await waitUntil(seconds: 2) { !store.all().isEmpty }
        let record = try #require(store.all().first)
        #expect(record.url.path == files.other.path && store.all().count == 1)
        let entries = [PluginEntry(MarkdownPlugin.self), PluginEntry(TextPlugin.self)]
        let recovered = DocumentWindowController(url: record.url, catalog: PluginCatalog(entries: entries, config: Config()), config: Config(),
                                                 recovery: store, recoveryClipboard: nil, sidebarMemory: SidebarMemory(defaults: nil))
        defer { recovered.close() }
        recovered.show(with: entries[0], restoring: record)
        try await waitUntil(seconds: 2) { recovered.editor?.text == "# Edited other\n" }
        #expect(recovered.history.entries.count == 1 && !recovered.history.canGoBack)
    }
}

@MainActor private extension DocumentWindowController {
    func restyleEditor() async { await editor?.restyle() }
}
