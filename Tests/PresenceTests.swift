import AppKit
import Testing

@Suite struct PresenceTests {
    @Test func menuBarOnlyWithoutWindows() {
        #expect(Presence.policy(documentWindows: 0, settingsOpen: false) == .accessory)
    }

    @Test func dockAndMenusWhileADocumentOrSettingsIsOpen() {
        #expect(Presence.policy(documentWindows: 1, settingsOpen: false) == .regular)
        #expect(Presence.policy(documentWindows: 0, settingsOpen: true) == .regular)
        #expect(Presence.policy(documentWindows: 3, settingsOpen: true) == .regular)
    }
}
