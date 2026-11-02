import AppKit
import Testing

@Suite struct MainMenuItems {
    @Test func thePeekerMenuHasSettingsButNotOpenAtLogin() throws {
        let delegate = AppDelegate()  // menu items hold their target weakly
        let menu = MainMenu.make(target: delegate)
        defer { withExtendedLifetime(delegate) {} }
        let peeker = try #require(menu.item(withTitle: "Peeker")?.submenu)
        #expect(peeker.item(withTitle: "Settings…") != nil)
        #expect(peeker.item(withTitle: "Open at Login") == nil)
    }

    @Test func thePeekerMenuChecksForUpdatesAfterAbout() throws {
        let delegate = AppDelegate()  // menu items hold their target weakly
        let menu = MainMenu.make(target: delegate)
        defer { withExtendedLifetime(delegate) {} }
        let peeker = try #require(menu.item(withTitle: "Peeker")?.submenu)
        #expect(Array(peeker.items.map(\.title).prefix(3)) == ["About Peeker", "Check for Updates…", "Settings…"])
        let check = try #require(peeker.item(withTitle: "Check for Updates…"))
        #expect(check.action == #selector(AppDelegate.checkForUpdates(_:)) && check.target === delegate)
    }

    @Test func fileHasPrintAndEditHasFindPrevious() throws {
        let delegate = AppDelegate()  // menu items hold their target weakly
        let main = MainMenu.make(target: delegate)
        defer { withExtendedLifetime(delegate) {} }
        let print = try #require(main.item(withTitle: "File")?.submenu?.item(withTitle: "Print…"))
        #expect(print.keyEquivalent == "p" && print.keyEquivalentModifierMask == .command)
        #expect(print.action == #selector(DocumentWindowController.printDocument(_:)))
        let previous = try #require(main.item(withTitle: "Edit")?.submenu?.item(withTitle: "Find Previous"))
        #expect(previous.keyEquivalent == "g" && previous.keyEquivalentModifierMask == [.command, .shift])
        #expect(previous.action == #selector(NSTextView.performFindPanelAction(_:)))
        #expect(previous.tag == Int(NSFindPanelAction.previous.rawValue))
    }
}

@Suite struct MenuBar {
    private func bar() -> (NSMenu, AppDelegate) {
        let delegate = AppDelegate()
        return (MainMenu.make(target: delegate), delegate)
    }

    private func titles(_ menu: NSMenu?) -> [String] {
        menu?.items.filter { !$0.isSeparatorItem }.map(\.title) ?? []
    }

    @Test func holdsTheStandardMenusInOrder() {
        let (main, delegate) = bar()
        defer { withExtendedLifetime(delegate) {} }
        #expect(main.items.map(\.title) == ["Peeker", "File", "Edit", "View", "Tools", "Window", "Help"])
    }

    @Test func viewHasTheSidebarToolbarAndOneFullScreenItem() throws {
        let (main, delegate) = bar()
        defer { withExtendedLifetime(delegate) {} }
        let view = try #require(main.item(withTitle: "View")?.submenu)
        let sidebar = try #require(view.items.first { $0.action == #selector(NSSplitViewController.toggleSidebar(_:)) })
        #expect(sidebar.keyEquivalent == "s" && sidebar.keyEquivalentModifierMask == [.control, .command])
        #expect(view.items.contains { $0.action == #selector(NSWindow.toggleToolbarShown(_:)) })
        #expect(view.items.filter { $0.action == #selector(NSWindow.toggleFullScreen(_:)) }.count == 1)
    }

    @Test func toolsStartsWithEditMode() throws {
        let (main, delegate) = bar()
        defer { withExtendedLifetime(delegate) {} }
        let edit = try #require(main.item(withTitle: "Tools")?.submenu?.items.first)
        #expect(edit.title == "Edit Mode" && edit.keyEquivalent == "e" && edit.keyEquivalentModifierMask == .command)
        #expect(edit.action == #selector(DocumentWindowController.toggleEditMode(_:)))
    }

    @Test func peekerWindowAndHelpHaveTheStandardItems() throws {
        let (main, delegate) = bar()
        defer { withExtendedLifetime(delegate) {} }
        let peeker = try #require(main.item(withTitle: "Peeker")?.submenu)
        let others = try #require(peeker.item(withTitle: "Hide Others"))
        #expect(others.keyEquivalent == "h" && others.keyEquivalentModifierMask == [.option, .command])
        #expect(others.action == #selector(NSApplication.hideOtherApplications(_:)))
        #expect(peeker.item(withTitle: "Show All")?.action == #selector(NSApplication.unhideAllApplications(_:)))
        let window = main.item(withTitle: "Window")?.submenu
        #expect(titles(window) == ["Minimize", "Zoom", "Show Previous Tab", "Show Next Tab", "Bring All to Front"])
        #expect(window?.item(withTitle: "Zoom")?.action == #selector(NSWindow.performZoom(_:)))
        #expect(window?.item(withTitle: "Bring All to Front")?.action == #selector(NSApplication.arrangeInFront(_:)))
        let help = try #require(main.item(withTitle: "Help")?.submenu?.item(withTitle: "Peeker Help"))
        #expect(help.action == #selector(AppDelegate.showHelp(_:)) && help.target === delegate)
    }

    @MainActor @Test func buildingTheMenuLeavesTheAppAlone() {
        let app = NSApplication.shared
        let windows = app.windowsMenu, help = app.helpMenu
        let (_, delegate) = bar()
        defer { withExtendedLifetime(delegate) {} }
        #expect(app.windowsMenu === windows && app.helpMenu === help)
    }

    @Test func helpOpensTheProjectPage() {
        #expect(AppDelegate.helpURL.absoluteString == "https://github.com/oribarilan/peeker")
    }
}

@Suite struct OpenRecent {
    @Test func fileHasOpenRecentAfterOpen() throws {
        let main = MainMenu.make(target: nil)
        let file = try #require(main.item(withTitle: "File")?.submenu)
        #expect(file.items.prefix(2).map(\.title) == ["Open…", "Open Recent"])
        #expect(file.item(withTitle: "Open Recent")?.submenu?.title == "Open Recent")
    }

    @Test func listsTheRecentFilesThenClearMenu() throws {
        let urls = [URL(filePath: "/tmp/a.md"), URL(filePath: "/tmp/b.pdf")]
        var opened: [URL] = []
        let recent = RecentFiles(urls: { urls }, open: { opened.append($0) })
        let menu = NSMenu(title: "Open Recent")
        recent.menuNeedsUpdate(menu)
        #expect(menu.items.map { $0.isSeparatorItem ? "-" : $0.title } == ["a.md", "b.pdf", "-", "Clear Menu"])
        #expect(menu.items.last?.action == #selector(NSDocumentController.clearRecentDocuments(_:)))
        let second = menu.items[1]
        _ = (second.target as? NSObject)?.perform(second.action, with: second)
        #expect(opened == [urls[1]])
        recent.menuNeedsUpdate(menu)
        #expect(menu.items.count == 4, "filling it again replaces the items")
    }
}
