import AppKit
import Testing

@Suite struct ShortcutText {
    private static let keys: [Shortcut.Key] = [.space, .escape, .tab, .enter, .character("a"), .character("9"), .character("="), .character("-"), .character("/")]
    private static let modifierSets: [NSEvent.ModifierFlags] = [[], [.command], [.command, .shift], [.control, .option, .shift, .command], [.option]]

    @Test func configTextParsesBackToTheSameShortcut() {
        for key in Self.keys {
            for modifiers in Self.modifierSets {
                let shortcut = Shortcut(key: key, modifiers: modifiers)
                #expect(Shortcut(parsing: shortcut.configText) == shortcut, "\(shortcut.configText)")
            }
        }
    }

    @Test func configTextNamesModifiersInAFixedOrder() {
        #expect(Shortcut(key: .character("h"), modifiers: [.command, .shift, .control, .option]).configText == "ctrl+opt+shift+cmd+h")
        #expect(Shortcut(key: .space).configText == "space")
        #expect(Shortcut(key: .escape, modifiers: .option).configText == "opt+esc")
    }
}

@Suite struct ShortcutParsing {
    /// Without a key code the shortcut could never fire, so the config must list it as a problem.
    @Test func aCharacterWithNoKeyCodeIsRefused() {
        #expect(Shortcut(parsing: "opt+;") == nil)
        #expect(Shortcut(parsing: "cmd+é") == nil)
    }

    @Test func aSecondKeyIsRefusedInEitherOrder() {
        for text in ["a+esc", "esc+a", "a+space", "space+a", "tab+enter", "a+b"] {
            #expect(Shortcut(parsing: text) == nil, "\(text)")
        }
    }
}

@Suite struct ShortcutFromEvent {
    private func event(keyCode: UInt16, modifiers: NSEvent.ModifierFlags = [], characters: String = "") -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0, windowNumber: 0, context: nil,
                         characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: keyCode)!
    }

    @Test func aKeyEventBecomesTheShortcutItTypes() {
        #expect(Shortcut(event: event(keyCode: 4, modifiers: [.command, .shift], characters: "H")) == Shortcut(key: .character("h"), modifiers: [.command, .shift]))
        #expect(Shortcut(event: event(keyCode: 49, modifiers: .option, characters: " ")) == Shortcut(key: .space, modifiers: .option))
        #expect(Shortcut(event: event(keyCode: 49, characters: " ")) == Shortcut(key: .space))
    }

    @Test func otherFlagsAreIgnored() {
        #expect(Shortcut(event: event(keyCode: 0, modifiers: [.command, .capsLock, .numericPad], characters: "a")) == Shortcut(key: .character("a"), modifiers: .command))
    }

    @Test func keysTheConfigCantWriteGiveNothing() {
        #expect(Shortcut(event: event(keyCode: 123, modifiers: .command)) == nil)  // left arrow
        #expect(Shortcut(event: event(keyCode: 122)) == nil)  // F1
    }
}
