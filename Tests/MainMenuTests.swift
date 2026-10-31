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
