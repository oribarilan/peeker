import AppKit
import CoreGraphics
import Testing

/// What the quick-look key monitor does with each key: Space must stay a space everywhere but Finder's file list.
@Suite struct HotkeyDecisions {
    private static let space: Int64 = 49, escape: Int64 = 53, down: Int64 = 125

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
        var swallowedKeyUp: Int64?
        let want: HotkeyMonitor.Decision
    }

    private static let cases: [Case] = [
        Case(name: "Space in Finder opens the panel", want: .trigger),
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
        Case(name: "Option-Space opens the panel from any app", shortcut: Shortcut(key: .space, modifiers: .option), flags: .maskAlternate,
             finderInFront: false, typing: true, want: .trigger),
    ]

    @Test func eachKeyIsSwallowedOrPassed() {
        for c in Self.cases {
            let key = HotkeyMonitor.KeyEvent(type: c.type, keyCode: c.keyCode, flags: c.flags, isRepeat: c.isRepeat, isOwn: c.isOwn)
            let decision = HotkeyMonitor.decide(key, shortcut: c.shortcut, panelVisible: c.panelVisible, finderInFront: c.finderInFront,
                                                typing: { c.typing }, swallowedKeyUp: c.swallowedKeyUp)
            #expect(decision == c.want, "\(c.name)")
        }
    }
}
