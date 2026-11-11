import AppKit
import PeekerKit
@testable import PeekerMarkdown
import PeekerPDF
import PeekerText
import Testing

@Suite(.serialized) struct BackAndForwardButtons {
    private func identifiers(_ controller: DocumentWindowController) -> [String] {
        controller.window?.toolbar?.items.map(\.itemIdentifier.rawValue) ?? []
    }

    private func item(_ controller: DocumentWindowController, _ id: NSToolbarItem.Identifier) throws -> NSToolbarItem {
        try #require(controller.window?.toolbar?.items.first { $0.itemIdentifier == id })
    }

    @Test func aMarkdownWindowHasBackThenForwardBeforeOpenWith() async throws {
        let files = try LinkedFiles()
        let controller = try await linkedWindow(files.readme, effects: LinkEffects())
        defer { controller.close() }
        try await waitUntil(seconds: 1) { identifiers(controller).contains("back") }
        let items = identifiers(controller)
        let sidebar = try #require(items.firstIndex(of: NSToolbarItem.Identifier.sidebarTrackingSeparator.rawValue))
        #expect(Array(items[(sidebar + 1)...(sidebar + 4)]) == ["back", "forward", "openWith", "showInFinder"])
        let back = try item(controller, DocumentWindowController.back), forward = try item(controller, DocumentWindowController.forward)
        #expect(back.label == "Back" && back.toolTip == "Back (⌘[)" && forward.label == "Forward" && forward.toolTip == "Forward (⌘])")
        #expect(!controller.validateToolbarItem(back) && !controller.validateToolbarItem(forward))
    }

    @Test func pdfAndTextWindowsHaveNeither() async throws {
        for plugin in [PDFPlugin.self, TextPlugin.self] as [any Plugin.Type] {
            let file = plugin == PDFPlugin.self ? try TempFile.makePDF(pages: 1) : try TempFile.make(Data("x\n".utf8), name: "f.txt")
            let controller = try await documentWindow(for: plugin, file: file)
            defer { controller.close() }
            #expect(!identifiers(controller).contains("back") && !identifiers(controller).contains("forward"), "\(plugin.id)")
        }
    }

    @Test func backEnablesAfterAJumpAndForwardAfterBack() async throws {
        let files = try LinkedFiles()
        let controller = try await linkedWindow(files.readme, effects: LinkEffects())
        defer { controller.close() }
        try await waitUntil(seconds: 1) { identifiers(controller).contains("back") }
        let back = try item(controller, DocumentWindowController.back), forward = try item(controller, DocumentWindowController.forward)
        await controller.follow(files.link("README.md", "install"))
        #expect(controller.validateToolbarItem(back) && !controller.validateToolbarItem(forward))
        await controller.move(to: 0)
        #expect(!controller.validateToolbarItem(back) && controller.validateToolbarItem(forward))
    }

    @Test func aSameTabSwitchHasBothBeforeTheNewContentShows() async throws {
        let files = try LinkedFiles()
        let controller = try await linkedWindow(files.readme, effects: LinkEffects())
        defer { controller.close() }
        var atSwitch: [String] = []
        controller.onDocument = { _ in DispatchQueue.main.async { atSwitch = identifiers(controller) } }
        await controller.follow(files.link("other.md"))
        #expect(identifiers(controller).contains("back") && identifiers(controller).contains("forward"))
        try await controller.waitForFile(files.other)
        #expect(atSwitch.contains("back"))
    }
}

@Suite(.serialized) struct GoMenu {
    private func goMenu() throws -> (NSMenu, AppDelegate) {
        let delegate = AppDelegate()
        return (try #require(MainMenu.make(target: delegate).item(withTitle: "Go")?.submenu), delegate)
    }

    @Test func holdsBackAndForwardWithTheirKeys() throws {
        let (go, delegate) = try goMenu()
        defer { withExtendedLifetime(delegate) {} }
        let back = try #require(go.item(withTitle: "Back")), forward = try #require(go.item(withTitle: "Forward"))
        #expect(back.keyEquivalent == "[" && back.keyEquivalentModifierMask == .command)
        #expect(forward.keyEquivalent == "]" && forward.keyEquivalentModifierMask == .command)
        #expect(back.action == #selector(DocumentWindowController.goBack(_:)) && back.target == nil)
        #expect(forward.action == #selector(DocumentWindowController.goForward(_:)) && forward.target == nil)
    }

    @MainActor @Test func greyedOutWithNoEditorWindowInFront() throws {
        let (go, delegate) = try goMenu()
        defer { withExtendedLifetime(delegate) {} }
        let back = try #require(go.item(withTitle: "Back"))
        #expect(NSApp.target(forAction: try #require(back.action), to: nil, from: back) == nil)
    }

    @Test func greyedOutWhereTheHistoryHasNoPlaceThatWay() async throws {
        let files = try LinkedFiles()
        let controller = try await linkedWindow(files.readme, effects: LinkEffects())
        defer { controller.close() }
        let (go, delegate) = try goMenu()
        defer { withExtendedLifetime(delegate) {} }
        let back = try #require(go.item(withTitle: "Back")), forward = try #require(go.item(withTitle: "Forward"))
        #expect(!controller.validateMenuItem(back) && !controller.validateMenuItem(forward))
        await controller.follow(files.link("README.md", "install"))
        #expect(controller.validateMenuItem(back) && !controller.validateMenuItem(forward))
    }

    @Test func theFixedKeysIncludeBackAndForward() {
        let titles = MainMenu.fixedShortcuts.map(\.title)
        #expect(titles.contains("Back") && titles.contains("Forward"))
        #expect(MainMenu.fixedShortcuts.contains { $0.title == "Save" && $0.shortcut == Shortcut(parsing: "cmd+s") })
    }
}

@Suite(.serialized) struct TheTrail {
    private func trail(_ controller: DocumentWindowController) -> HistoryTrail? { controller.trailAccessory?.view as? HistoryTrail }

    @Test func hiddenWithOnePlaceAndShownWithTwo() async throws {
        let files = try LinkedFiles()
        let controller = try await linkedWindow(files.readme, effects: LinkEffects())
        defer { controller.close() }
        #expect(controller.trailAccessory == nil || controller.trailAccessory?.isHidden == true)
        await controller.follow(files.link("README.md", "install"))
        #expect(controller.trailAccessory?.isHidden == false && controller.trailAccessory?.layoutAttribute == .bottom)
    }

    @Test func crumbsNameEachPlaceAndMarkTheCurrentOne() async throws {
        let files = try LinkedFiles()
        let controller = try await linkedWindow(files.readme, effects: LinkEffects())
        defer { controller.close() }
        await controller.follow(files.link("README.md", "install"))
        await controller.follow(files.link("other.md"))
        let crumbs = try #require(trail(controller)?.crumbs)
        #expect(crumbs.map(\.title) == ["README.md", "Install", "other.md"])
        #expect(crumbs.map(\.toolTip) == ["README.md", "README.md › Install", "other.md"])
        #expect(crumbs.map { $0.accessibilityLabel() ?? "" } == ["README.md", "README.md › Install", "other.md, current"])
    }

    @Test func clickingACrumbGoesThereAsBackWould() async throws {
        let files = try LinkedFiles()
        let controller = try await linkedWindow(files.readme, effects: LinkEffects())
        defer { controller.close() }
        await controller.follow(files.link("README.md", "install"))
        await controller.follow(files.link("other.md"))
        try await controller.waitForFile(files.other)
        let readme = try #require(trail(controller)?.crumbs.first)
        readme.performClick(nil)
        try await controller.waitForFile(files.readme)
        #expect(controller.history.index == 0)
        #expect(trail(controller)?.crumbs.map { $0.accessibilityLabel() ?? "" } == ["README.md, current", "README.md › Install", "other.md"])
    }
}

@Suite struct TrailHover {
    @Test func aPlaceShowsTheTintUnderThePointerButTheCurrentOneDoesNot() {
        var history = NavigationHistory(.init(url: URL(fileURLWithPath: "/a/README.md"), pluginID: "markdown"))
        history.push(.init(url: URL(fileURLWithPath: "/a/README.md"), pluginID: "markdown", place: "install", title: "Install"))
        history.push(.init(url: URL(fileURLWithPath: "/a/other.md"), pluginID: "markdown"))
        let trail = HistoryTrail()
        let window = offscreenWindow(holding: trail, width: 400, height: 24)
        defer { window.close() }
        trail.show(history)
        trail.layoutSubtreeIfNeeded()
        func move(over crumb: Int?) {
            let point = crumb.map {
                trail.convert(NSPoint(x: trail.crumbs[$0].frame.midX, y: trail.crumbs[$0].frame.midY), from: trail.crumbs[$0].superview)
            }
            let event = NSEvent.mouseEvent(
                with: .mouseMoved, location: trail.convert(point ?? NSPoint(x: -50, y: -50), to: nil), modifierFlags: [],
                timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 0, pressure: 0)!
            crumb == nil ? trail.mouseExited(with: event) : trail.mouseMoved(with: event)
        }
        move(over: 1)
        let fill = trail.hoverFill
        let crumb = trail.convert(trail.crumbs[1].frame, from: trail.crumbs[1].superview)
        #expect(fill.isHovered && fill.frame.contains(crumb), "behind Install")
        move(over: 2)
        #expect(!fill.isHovered, "the current place keeps its own look")
        move(over: 0)
        #expect(fill.isHovered)
        move(over: nil)
        #expect(!fill.isHovered)
    }
}

@Suite(.serialized) struct PeekPanelLinks {
    /// The panel's view of README.md, with what the panel did.
    private func panelDocument(_ files: LinkedFiles) async -> (PeekPanel, DocumentViewController, LinkEffects, () -> [(URL, String?)]) {
        let panel = PeekPanel(defaults: UserDefaults(suiteName: "dev.peeker.tests.links")!), effects = LinkEffects()
        var opened: [(URL, String?)] = []
        panel.owner = { url in ["md": "markdown", "txt": "text"][url.pathExtension] }
        panel.beep = { effects.beeps += 1 }
        panel.onOpenInWindow = { opened.append(($0, $1)) }
        panel.confirmOpenElsewhere = { _, url in
            effects.asked.append(url)
            return false
        }
        let document = await loadedDocument(files.readme, with: MarkdownPlugin.self, allowsEditing: false)
        return (panel, document, effects, { opened })
    }

    @Test func aHeadingLinkScrollsAndOpensNothing() async throws {
        let files = try LinkedFiles()
        let (panel, document, effects, opened) = await panelDocument(files)
        defer { document.close(); panel.close() }
        await panel.follow(files.link("README.md", "install"), from: document)
        #expect(opened().isEmpty && effects.beeps == 0)
    }

    @Test func aFileLinkOpensAnEditorWindowAtItsHeading() async throws {
        let files = try LinkedFiles()
        let (panel, document, _, opened) = await panelDocument(files)
        defer { document.close(); panel.close() }
        await panel.follow(files.link("other.md", "setup"), from: document)
        await panel.follow(files.link("notes.txt"), from: document)
        #expect(opened().map(\.0.path) == [files.other.path, files.notes.path])
        #expect(opened().map(\.1) == ["setup", nil])
    }

    @Test func aMissingFileOrHeadingBeepsAndThePanelStays() async throws {
        let files = try LinkedFiles()
        let (panel, document, effects, opened) = await panelDocument(files)
        defer { document.close(); panel.close() }
        await panel.follow(files.link("gone.md"), from: document)
        await panel.follow(files.link("README.md", "missing"), from: document)
        #expect(effects.beeps == 2 && opened().isEmpty)
    }

    @Test func aFileNoPluginOpensAsksFirst() async throws {
        let files = try LinkedFiles()
        let (panel, document, effects, opened) = await panelDocument(files)
        defer { document.close(); panel.close() }
        await panel.follow(files.link("report.numbers"), from: document)
        #expect(effects.asked.map(\.path) == [files.report.path] && opened().isEmpty)
    }
}
