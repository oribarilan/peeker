import AppKit
import Testing

@Suite(.serialized) struct PeekPanelButton {
    /// The name tells the panel apart from Quick Look, whose button opens Preview.
    @Test func theButtonReadsOpenInPeeker() {
        let (defaults, name) = scratchDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let panel = PeekPanel(defaults: defaults)
        defer { panel.close() }
        #expect(panel.openButton.title == "Open in Peeker")
    }

    @Test func bothButtonsShowTheirKeysWhileCaptionsAreOn() {
        let (defaults, name) = scratchDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let panel = PeekPanel(defaults: defaults)
        defer { panel.close() }
        let file = URL(filePath: "/tmp/notes.md")
        panel.openKey = Shortcut(key: .character("o"), modifiers: .command)
        panel.showInFinderKey = Shortcut(key: .character("r"), modifiers: .command)
        let plainWidth = panel.finderButton.frame.width
        panel.showsKeys = true
        panel.updateOpenButton(for: file)
        #expect(panel.openButton.title == "Open in Peeker  ⌘O")
        #expect(panel.openButton.toolTip == "Open in Peeker (⌘O)" && panel.finderButton.toolTip == "Show in Finder (⌘R)")
        #expect(panel.finderButton.frame.width > plainWidth, "the key beside the icon")
        #expect(panel.finderButton.frame.maxX < panel.openButton.frame.minX)
        panel.showsKeys = false
        panel.updateOpenButton(for: file)
        #expect(panel.openButton.title == "Open in Peeker" && panel.finderButton.frame.width == plainWidth)
        #expect(panel.openButton.toolTip == "Open in Peeker (⌘O)", "the tooltip names the key either way")
    }

    @Test func aFolderButtonBesideItShowsTheFileInFinder() {
        let (defaults, name) = scratchDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let panel = PeekPanel(defaults: defaults)
        defer { panel.close() }
        let button = panel.finderButton
        #expect(button.toolTip == "Show in Finder" && button.superview === panel.openButton.superview)
        #expect(button.target === panel && button.action == #selector(PeekPanel.showFileInFinder(_:)))
        #expect(button.frame.maxX < panel.openButton.frame.minX, "left of Open in Peeker")
    }
}

@Suite(.serialized) struct PeekPanelFrame {
    @Test func itCantBeMadeSmallerThan400By300() {
        let (defaults, name) = scratchDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let panel = PeekPanel(defaults: defaults)
        defer { panel.close() }
        #expect(panel.minSize == NSSize(width: 400, height: 300))
    }

    @Test func aFrameTheUserGivesItIsSavedButItsOwnPlacementIsNot() {
        let (defaults, name) = scratchDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let panel = PeekPanel(defaults: defaults)
        defer { panel.close() }
        panel.placeOnScreen()
        #expect(defaults.string(forKey: PeekPanel.frameKey) == nil, "placing itself isn't the user's choice")
        let chosen = NSRect(x: 60, y: 80, width: 600, height: 500)
        panel.setFrame(chosen, display: false)  // as a drag or a resize would
        #expect(defaults.string(forKey: PeekPanel.frameKey) == NSStringFromRect(chosen))
        #expect(PeekPanel.hasSavedFrame(in: defaults))
    }

    @Test func aNewPanelOpensAtTheSavedFrame() {
        let (defaults, name) = scratchDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let screen = PeekPanel.pointerScreenFrame()
        let saved = NSRect(x: screen.minX + 20, y: screen.minY + 20, width: 600, height: 500)
        defaults.set(NSStringFromRect(saved), forKey: PeekPanel.frameKey)
        let panel = PeekPanel(defaults: defaults)
        defer { panel.close() }
        panel.placeOnScreen()
        #expect(panel.frame == saved)
    }

    @Test func resetForgetsTheFrameAndGoesBackToTheDefault() {
        let (defaults, name) = scratchDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let panel = PeekPanel(defaults: defaults)
        defer { panel.close() }
        panel.setFrame(NSRect(x: 60, y: 80, width: 600, height: 500), display: false)
        panel.resetFrame()
        #expect(!PeekPanel.hasSavedFrame(in: defaults))
        #expect(panel.frame == PanelPlacement.frame(saved: nil, screen: PeekPanel.pointerScreenFrame()))
    }
}

private func app(_ id: String, _ name: String) -> AppChoice {
    AppChoice(bundleID: id, name: name, url: URL(filePath: "/Applications/\(name).app"))
}

@Suite struct PeekPanelOpenWithMenu {
    private let peeker = "dev.peeker.Peeker"
    private let xcode = app("com.apple.dt.Xcode", "Xcode")
    private let textEdit = app("com.apple.TextEdit", "TextEdit")
    private let bbedit = app("com.barebones.bbedit", "BBEdit")

    @Test func theMacsDefaultComesFirstThenTheRestAToZThenOtherThenShowInFinder() {
        let items = PeekOpenWithMenu.items(
            apps: [textEdit, xcode, bbedit], systemDefault: xcode.bundleID, buttonApp: nil, hasDefault: false, peekerID: peeker)
        #expect(items == [.app(xcode), .app(bbedit), .app(textEdit), .separator, .other, .separator, .showInFinder])
    }

    @Test func peekerAndDuplicateCopiesAreLeftOut() {
        let peekerApp = app(peeker, "Peeker")
        let otherXcode = AppChoice(bundleID: xcode.bundleID, name: "Xcode", url: URL(filePath: "/Users/x/Xcode.app"))
        let items = PeekOpenWithMenu.items(
            apps: [peekerApp, xcode, otherXcode], systemDefault: peeker, buttonApp: nil, hasDefault: false, peekerID: peeker)
        #expect(items == [.app(xcode), .separator, .other, .separator, .showInFinder])
    }

    @Test func withAnotherAppAsDefaultPeekerAndAlwaysOpenInPeekerAreOffered() {
        let items = PeekOpenWithMenu.items(
            apps: [xcode, textEdit], systemDefault: nil, buttonApp: xcode.bundleID, hasDefault: true, peekerID: peeker)
        #expect(items == [.app(textEdit), .separator, .peeker, .alwaysPeeker, .separator, .other, .separator, .showInFinder])
    }

    @Test func aDefaultWhoseAppIsGoneCanStillBeDropped() {
        let items = PeekOpenWithMenu.items(apps: [textEdit], systemDefault: nil, buttonApp: nil, hasDefault: true, peekerID: peeker)
        #expect(items == [.app(textEdit), .separator, .alwaysPeeker, .separator, .other, .separator, .showInFinder])
    }

    @Test func noAppsLeavesOtherAndShowInFinder() {
        #expect(
            PeekOpenWithMenu.items(apps: [], systemDefault: nil, buttonApp: nil, hasDefault: false, peekerID: peeker) == [
                .other, .separator, .showInFinder,
            ])
    }

    @Test func theAlwaysCheckboxNamesTheExtensionAndIsAbsentWithoutOne() {
        #expect(PeekOpenWithMenu.alwaysTitle(for: URL(filePath: "/tmp/Notes.TXT")) == "Always open .txt files with this app")
        #expect(PeekOpenWithMenu.alwaysTitle(for: URL(filePath: "/tmp/Makefile")) == nil)
    }
}

@Suite(.serialized) struct PeekPanelOpenWith {
    private let file = URL(filePath: "/tmp/main.swift")
    private let xcode = app("com.apple.dt.Xcode", "Xcode")

    private func panel(_ defaults: UserDefaults, openWith: [String: String], installed: [AppChoice]) -> PeekPanel {
        let panel = PeekPanel(defaults: defaults)
        panel.openWith = openWith
        panel.appFor = { id in installed.first { $0.bundleID == id } }
        return panel
    }

    @Test func theButtonNamesTheDefaultApp() {
        let (defaults, name) = scratchDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let panel = panel(defaults, openWith: ["swift": xcode.bundleID], installed: [xcode])
        defer { panel.close() }
        panel.updateOpenButton(for: file)
        #expect(panel.openButton.title == "Open in Xcode")
        panel.updateOpenButton(for: URL(filePath: "/tmp/notes.txt"))
        #expect(panel.openButton.title == "Open in Peeker")
    }

    @Test func aMissingAppFallsBackToPeeker() {
        let (defaults, name) = scratchDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let panel = panel(defaults, openWith: ["swift": xcode.bundleID], installed: [])
        defer { panel.close() }
        panel.updateOpenButton(for: file)
        #expect(panel.openButton.title == "Open in Peeker")
    }

    @Test func pickingAnAppOpensItThereWithoutChangingDefaults() {
        let (defaults, name) = scratchDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let panel = panel(defaults, openWith: [:], installed: [])
        defer { panel.close() }
        var opened: [(URL, URL)] = []
        var defaultsSet = 0
        panel.openInApp = { opened.append(($0, $1)) }
        panel.onSetDefault = { _, _ in defaultsSet += 1 }
        panel.choose(.app(xcode), for: file)
        #expect(opened.map(\.0) == [file] && opened.map(\.1) == [xcode.url])
        #expect(defaultsSet == 0)
    }

    @Test func alwaysOpenInPeekerDropsTheDefaultAndOpensTheEditor() {
        let (defaults, name) = scratchDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let panel = panel(defaults, openWith: ["swift": xcode.bundleID], installed: [xcode])
        defer { panel.close() }
        var set: [(String, String?)] = []
        var editor: [URL] = []
        panel.onSetDefault = { set.append(($0, $1)) }
        panel.onOpenInWindow = { url, _ in editor.append(url) }
        panel.choose(.alwaysPeeker, for: file)
        #expect(set.count == 1 && set.first?.0 == "swift" && set.first?.1 == nil)
        #expect(editor == [file])
    }

    @Test func theMainButtonOpensTheDefaultApp() {
        let (defaults, name) = scratchDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let panel = panel(defaults, openWith: ["swift": xcode.bundleID], installed: [xcode])
        defer { panel.close() }
        var opened: [URL] = []
        var editor: [URL] = []
        panel.openInApp = { _, app in opened.append(app) }
        panel.onOpenInWindow = { url, _ in editor.append(url) }
        panel.openDefault(file)
        #expect(opened == [xcode.url] && editor.isEmpty)
    }

    @Test func showInFinderRevealsTheFileAndOpensNothing() {
        let (defaults, name) = scratchDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let panel = panel(defaults, openWith: [:], installed: [])
        defer { panel.close() }
        var revealed: [URL] = []
        var opened = 0
        panel.revealInFinder = { revealed.append($0) }
        panel.openInApp = { _, _ in opened += 1 }
        panel.onOpenInWindow = { _, _ in opened += 1 }
        panel.choose(.showInFinder, for: file)
        #expect(revealed == [file] && opened == 0)
    }
}
