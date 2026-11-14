import AppKit
import CoreGraphics
import Testing

/// What the Peek panel key monitor does with each key: Space must stay a space everywhere but Finder's file list.
@Suite struct HotkeyDecisions {
    private static let space: Int64 = 49, escape: Int64 = 53, down: Int64 = 125, o: Int64 = 31, r: Int64 = 15, c: Int64 = 8

    private struct Case {
        let name: String
        var shortcut = Shortcut(key: .space)
        var type = CGEventType.keyDown
        var keyCode = space
        var flags: CGEventFlags = []
        var isRepeat = false
        var isOwn = false
        var panelVisible = false
        var finderInFront = true
        var typing = false
        var menuOpen = false
        var openKey: Shortcut? = Shortcut(key: .character("o"), modifiers: .command)
        var showInFinderKey: Shortcut? = Shortcut(key: .character("r"), modifiers: .command)
        var swallowedKeyUp: Int64?
        var canCopy = false
        let want: HotkeyMonitor.Decision
    }

    private static let cases: [Case] = [
        Case(name: "Space in Finder opens the Peek panel", want: .trigger),
        Case(name: "Space while renaming in Finder stays a space", typing: true, want: .pass),
        Case(name: "Space in another app stays a space", finderInFront: false, want: .pass),
        Case(name: "Space with the panel up closes it", panelVisible: true, want: .dismiss),
        Case(name: "Cmd-Space isn't the key", flags: .maskCommand, want: .pass),
        Case(name: "a held Space with the panel up is swallowed", isRepeat: true, panelVisible: true, want: .swallowRepeat),
        Case(name: "a held Space without the panel passes", isRepeat: true, want: .pass),
        Case(name: "Escape with the panel up closes it", keyCode: escape, panelVisible: true, want: .dismiss),
        Case(name: "Escape without the panel passes", keyCode: escape, want: .pass),
        Case(name: "Escape in another app passes", keyCode: escape, panelVisible: true, finderInFront: false, want: .pass),
        Case(name: "an arrow moves Finder's selection, then the panel follows", keyCode: down, panelVisible: true, want: .followSelection),
        Case(name: "an arrow without the panel passes", keyCode: down, want: .pass),
        Case(name: "the key-up of a swallowed key is swallowed", type: .keyUp, swallowedKeyUp: space, want: .swallowKeyUp),
        Case(name: "another key-up passes", type: .keyUp, keyCode: escape, swallowedKeyUp: space, want: .pass),
        Case(name: "Peeker's own key passes", isOwn: true, want: .pass),
        Case(name: "Escape with the panel's menu open closes only the menu", keyCode: escape, panelVisible: true, menuOpen: true, want: .pass),
        Case(name: "an arrow with the panel's menu open moves in the menu", keyCode: down, panelVisible: true, menuOpen: true, want: .pass),
        Case(name: "Space with the panel's menu open goes to the menu", panelVisible: true, menuOpen: true, want: .pass),
        Case(name: "Cmd-O with the panel up opens the file", keyCode: o, flags: .maskCommand, panelVisible: true, want: .open),
        Case(name: "Cmd-R with the panel up shows it in Finder", keyCode: r, flags: .maskCommand, panelVisible: true, want: .showInFinder),
        Case(name: "Cmd-O without the panel reaches Finder", keyCode: o, flags: .maskCommand, want: .pass),
        Case(
            name: "Cmd-O with the panel up in another app passes", keyCode: o, flags: .maskCommand, panelVisible: true, finderInFront: false,
            want: .pass),
        Case(
            name: "a held Cmd-O with the panel up is swallowed", keyCode: o, flags: .maskCommand, isRepeat: true, panelVisible: true,
            want: .swallowRepeat),
        Case(name: "O alone with the panel up passes", keyCode: o, panelVisible: true, want: .pass),
        Case(name: "Cmd-R with its key off passes", keyCode: r, flags: .maskCommand, panelVisible: true, showInFinderKey: nil, want: .pass),
        Case(name: "Cmd-O with the menu open goes to the menu", keyCode: o, flags: .maskCommand, panelVisible: true, menuOpen: true, want: .pass),
        Case(
            name: "Cmd-C with something selected in the panel copies it", keyCode: c, flags: .maskCommand, panelVisible: true, canCopy: true,
            want: .copy),
        Case(
            name: "Cmd-C with nothing selected in the panel copies the file in Finder", keyCode: c, flags: .maskCommand, panelVisible: true,
            want: .pass),
        Case(name: "Cmd-C without the panel reaches Finder", keyCode: c, flags: .maskCommand, canCopy: true, want: .pass),
        Case(
            name: "Cmd-C in another app passes", keyCode: c, flags: .maskCommand, panelVisible: true, finderInFront: false, canCopy: true,
            want: .pass),
        Case(
            name: "a held Cmd-C that copies is swallowed", keyCode: c, flags: .maskCommand, isRepeat: true, panelVisible: true, canCopy: true,
            want: .swallowRepeat),
        Case(name: "C alone with the panel up passes", keyCode: c, panelVisible: true, canCopy: true, want: .pass),
        Case(
            name: "Option-Space opens the panel from any app", shortcut: Shortcut(key: .space, modifiers: .option), flags: .maskAlternate,
            finderInFront: false, typing: true, want: .trigger),
    ]

    @Test func eachKeyIsSwallowedOrPassed() {
        for c in Self.cases {
            let key = HotkeyMonitor.KeyEvent(type: c.type, keyCode: c.keyCode, flags: c.flags, isRepeat: c.isRepeat, isOwn: c.isOwn)
            let decision = HotkeyMonitor.decide(
                key, shortcut: c.shortcut, panelVisible: c.panelVisible, finderInFront: c.finderInFront,
                menuOpen: c.menuOpen, openKey: c.openKey, showInFinderKey: c.showInFinderKey,
                typing: { c.typing }, canCopy: { c.canCopy }, swallowedKeyUp: c.swallowedKeyUp)
            #expect(decision == c.want, "\(c.name)")
        }
    }

    /// Asking the panel costs a look at its responder chain, so only Cmd-C over the panel asks.
    @Test func onlyCmdCAsksWhetherThePanelCanCopy() {
        var asked = 0
        let keys: [(Int64, CGEventFlags)] = [(Self.space, []), (Self.down, []), (Self.o, .maskCommand), (Self.c, [])]
        for (code, flags) in keys {
            let key = HotkeyMonitor.KeyEvent(type: .keyDown, keyCode: code, flags: flags, isRepeat: false, isOwn: false)
            _ = HotkeyMonitor.decide(
                key, shortcut: Shortcut(key: .space), panelVisible: true, finderInFront: true, menuOpen: false,
                openKey: nil, showInFinderKey: nil, typing: { false },
                canCopy: {
                    asked += 1; return true
                }, swallowedKeyUp: nil)
        }
        #expect(asked == 0)
    }
}
