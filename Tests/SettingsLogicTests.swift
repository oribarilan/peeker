import AppKit
import CoreServices
import PeekerKit
import Testing

private enum StubPDF: Plugin {
    static let id = "pdf"
    static let name = "PDF"
    static let defaultExtensions = ["pdf"]
    static let commands = [CommandSpec(id: "zoom-in", title: "Zoom In", shortcut: "cmd+="), CommandSpec(id: "highlight", title: "Highlight Selection", shortcut: "ctrl+cmd+h")]
    static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument { throw PluginError("not used") }
}

private enum StubText: Plugin {
    static let id = "text"
    static let name = "Plain Text"
    static let defaultExtensions = ["txt"]
    static let commands: [CommandSpec] = []
    static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument { throw PluginError("not used") }
}

private let plugins = [PluginEntry(StubPDF.self), PluginEntry(StubText.self)]

@Suite struct SettingsPanes {
    @Test func theSidebarListsGeneralThePluginsInOrderThenPermissionsAndConfigFile() {
        #expect(SettingsPane.all(plugins: plugins) == [.general, .plugin("pdf"), .plugin("text"), .permissions, .configFile])
    }
}

@Suite struct RecorderRules {
    private func key(_ text: String) -> Shortcut { Shortcut(parsing: text)! }

    @Test func theQuickLookKeyIsBareSpaceOrAKeyWithAModifier() {
        #expect(Shortcut.Rules.quickLook.refusal(for: key("space")) == nil)
        #expect(Shortcut.Rules.quickLook.refusal(for: key("opt+j")) == nil)
        #expect(Shortcut.Rules.quickLook.refusal(for: key("j")) != nil)
    }

    @Test func aCommandNeedsAModifier() {
        #expect(Shortcut.Rules.command.refusal(for: key("j")) != nil)
        #expect(Shortcut.Rules.command.refusal(for: key("space")) != nil)
        #expect(Shortcut.Rules.command.refusal(for: key("cmd+j")) == nil)
    }
}

@Suite struct ShortcutConflicts {
    private let menu: [(title: String, shortcut: Shortcut)] = [("Save", Shortcut(parsing: "cmd+s")!), ("Close", Shortcut(parsing: "cmd+w")!)]

    private func conflict(_ text: String, for command: String, config: Config = Config()) -> String? {
        shortcutConflict(Shortcut(parsing: text)!, command: command, plugin: plugins[0], config: config, menu: menu)
    }

    @Test func aMenuItemsKeyIsTaken() {
        #expect(conflict("cmd+s", for: "highlight") == "Save")
    }

    @Test func editModeKeepsCommandE() {
        #expect(conflict("cmd+e", for: "highlight") == "Edit Mode")
    }

    @Test func anotherCommandOfThePluginTakesItsKey() {
        #expect(conflict("cmd+=", for: "highlight") == "Zoom In")
        var config = Config()
        config.keys["pdf.zoom-in"] = Shortcut(parsing: "cmd+shift+z")
        #expect(conflict("cmd+shift+z", for: "highlight", config: config) == "Zoom In")
        #expect(conflict("cmd+=", for: "highlight", config: config) == nil, "Zoom In moved off cmd+=")
    }

    @Test func aCommandKeepingItsOwnKeyIsNoClash() {
        #expect(conflict("ctrl+cmd+h", for: "highlight") == nil)
        #expect(conflict("cmd+j", for: "highlight") == nil)
    }

    @Test func theAppMenuShortcutsAreReadFromTheMenuOutsideCommands() {
        let main = NSMenu()
        let file = NSMenu(title: "File")
        file.addItem(NSMenuItem(title: "Save", action: nil, keyEquivalent: "s"))
        let redo = NSMenuItem(title: "Redo", action: nil, keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        file.addItem(redo)
        main.addItem(withTitle: "File", action: nil, keyEquivalent: "").submenu = file
        let commands = NSMenu(title: "Commands")
        commands.addItem(NSMenuItem(title: "Zoom In", action: nil, keyEquivalent: "="))
        main.addItem(withTitle: "Commands", action: nil, keyEquivalent: "").submenu = commands
        let shortcuts = menuShortcuts(in: main)
        #expect(shortcuts.map(\.title) == ["Save", "Redo"])
        #expect(shortcuts.map(\.shortcut) == [Shortcut(parsing: "cmd+s"), Shortcut(parsing: "cmd+shift+z")])
    }

    @Test func settingsRefusesPrintAndFindPreviousForCommands() {
        let delegate = AppDelegate()  // menu items hold their target weakly
        defer { withExtendedLifetime(delegate) {} }
        let shortcuts = menuShortcuts(in: MainMenu.make(target: delegate))
        #expect(shortcutConflict(Shortcut(parsing: "cmd+p")!, command: "highlight", plugin: plugins[0], config: Config(), menu: shortcuts) == "Print…")
        #expect(shortcutConflict(Shortcut(parsing: "cmd+shift+g")!, command: "highlight", plugin: plugins[0], config: Config(), menu: shortcuts) == "Find Previous")
    }
}

@Suite struct PermissionStates {
    @Test func appleEventResultsMapToStatuses() {
        #expect(PermissionState(appleEventStatus: noErr) == .granted)
        #expect(PermissionState(appleEventStatus: OSStatus(errAEEventNotPermitted)) == .notGranted)
        #expect(PermissionState(appleEventStatus: OSStatus(errAEEventWouldRequireUserConsent)) == .notAsked)
        #expect(PermissionState(appleEventStatus: OSStatus(procNotFound)) == nil, "Finder isn't running: keep the last status")
    }
}

@Suite struct DefaultAppSummaries {
    private func ext(_ name: String, _ isPeeker: Bool?) -> ExtensionDefault {
        ExtensionDefault(ext: name, type: isPeeker == nil ? nil : .plainText, appName: isPeeker == true ? "Peeker" : "TextEdit", isPeeker: isPeeker ?? false)
    }

    @Test func allSomeOrNoneCountOnlyExtensionsThatCanBeSet() {
        #expect(DefaultAppSummary(of: [ext("md", true), ext("markdown", true)]) == .all)
        #expect(DefaultAppSummary(of: [ext("md", true), ext("markdown", false)]) == .some(1, of: 2))
        #expect(DefaultAppSummary(of: [ext("md", false), ext("conf", nil)]) == .none)
        #expect(DefaultAppSummary(of: [ext("md", true), ext("conf", nil)]) == .all)
        #expect(DefaultAppSummary(of: [ext("conf", nil)]) == .cantSet)
    }
}

@Suite struct UpdateSettings {
    @Test func clearingTheCheckboxRewritesTheConfig() throws {
        let file = try TempFile.make(Data("{}".utf8), name: "config.json")
        let store = ConfigStore(url: file, plugins: plugins)
        defer { store.stop() }
        let model = SettingsModel(store: store, accessibility: AccessibilityStatus(), updater: Updater(version: "0.1.0", build: "100"))
        model.checkForUpdates = false
        let saved = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        #expect((saved["updates"] as? [String: Any])?["check"] as? Bool == false)
        #expect(!model.checkForUpdates)
    }
}

@Suite struct KeyRecording {
    /// While any recorder listens, the quick-look key is off; a second recorder taking over must not turn it back on.
    @Test func oneRecorderListensAtATime() throws {
        let file = try TempFile.make(Data("{}".utf8), name: "config.json")
        let store = ConfigStore(url: file, plugins: plugins)
        defer { store.stop() }
        let model = SettingsModel(store: store, accessibility: AccessibilityStatus(), updater: Updater(version: "0.1.0", build: "100"))
        var changes: [Bool] = []
        model.onRecordingChange = { changes.append($0) }
        model.recorder = "quickLook"
        model.recorder = "pdf.zoom-in"
        #expect(changes == [true])
        model.recorder = nil
        #expect(changes == [true, false])
    }
}

@Suite struct MenuBarMenu {
    @Test func itOffersSettingsUpdatesLoginAndQuit() {
        let delegate = AppDelegate()  // menu items hold their target weakly
        defer { withExtendedLifetime(delegate) {} }
        let menu = MenuBarItem.menu(target: delegate, lines: [])
        #expect(menu.items.map(\.title) == ["Settings…", "Check for Updates…", "Open at Login", "", "Quit Peeker"])
        #expect(menu.items[1].action == #selector(AppDelegate.checkForUpdates(_:)) && menu.items[1].target === delegate)
    }
}

@Suite struct MenuBarStates {
    @Test func theDotShowsForProblemsOrMissingAccessibility() {
        #expect(MenuBarItem.State(problems: 0, needsAccessibility: false) == .init(dot: false, problemsLine: nil, accessibilityLine: false))
        #expect(MenuBarItem.State(problems: 2, needsAccessibility: false) == .init(dot: true, problemsLine: "Config has 2 problems", accessibilityLine: false))
        #expect(MenuBarItem.State(problems: 0, needsAccessibility: true) == .init(dot: true, problemsLine: nil, accessibilityLine: true))
        #expect(MenuBarItem.State(problems: 1, needsAccessibility: true) == .init(dot: true, problemsLine: "Config has 1 problem", accessibilityLine: true))
    }
}
