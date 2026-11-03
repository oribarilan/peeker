import AppKit
import CoreServices
import PeekerKit
import Testing

private enum StubPDF: Plugin {
    static let id = "pdf"
    static let name = "PDF"
    static let defaultExtensions = ["pdf"]
    static let tools = [ToolSpec(id: "zoom-in", title: "Zoom In", shortcut: "cmd+="), ToolSpec(id: "highlight", title: "Highlight", shortcut: "ctrl+cmd+h")]
    static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument { throw PluginError("not used") }
}

private enum StubText: Plugin {
    static let id = "text"
    static let name = "Plain Text"
    static let defaultExtensions = ["txt"]
    static let tools: [ToolSpec] = []
    static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument { throw PluginError("not used") }
}

private let plugins = [PluginEntry(StubPDF.self), PluginEntry(StubText.self)]

@Suite struct SettingsPanes {
    @Test func theSidebarListsGeneralAppearanceThePluginsInOrderThenPermissionsAndConfigFile() {
        #expect(SettingsPane.all(plugins: plugins) == [.general, .appearance, .plugin("pdf"), .plugin("text"), .permissions, .configFile])
        #expect(SettingsPane.appearance.storageKey == "appearance")
    }

    @Test func aPaneRoundTripsThroughItsStorageKey() {
        for pane in SettingsPane.all(plugins: plugins) { #expect(SettingsPane(storageKey: pane.storageKey) == pane) }
        #expect(SettingsPane.plugin("pdf").storageKey == "plugin.pdf")
        #expect(SettingsPane(storageKey: "nonsense") == nil)
    }
}

/// Settings reopens on the pane last shown, kept in the app's preferences.
@Suite(.serialized) struct RememberedPane {
    private func model(_ defaults: UserDefaults) throws -> SettingsModel {
        let store = ConfigStore(url: try TempFile.make(Data("{}".utf8), name: "config.json"), plugins: plugins)
        store.stop()
        return SettingsModel(store: store, accessibility: AccessibilityStatus(), updater: Updater(version: "0.1.0", build: "100"), defaults: defaults)
    }

    /// Preferences only this test reads, removed afterwards.
    private func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let name = "dev.peeker.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        try body(defaults)
    }

    @Test func startsOnGeneralThenOnTheLastPane() throws {
        try withDefaults { defaults in
            let first = try model(defaults)
            #expect(first.selection == .general)
            first.selection = .plugin("pdf")
            let reopened = try model(defaults)
            #expect(reopened.selection == .plugin("pdf"))
        }
    }

    @Test func theWindowResizesButCannotZoom() throws {
        try withDefaults { defaults in
            let controller = SettingsWindowController(model: try model(defaults))
            defer { controller.close() }
            let window = try #require(controller.window)
            #expect(window.styleMask.contains(.resizable))
            #expect(window.standardWindowButton(.zoomButton)?.isEnabled == false)
        }
    }

    @Test func aPaneThatIsGoneFallsBackToGeneral() throws {
        try withDefaults { defaults in
            defaults.set("plugin.gone", forKey: "settingsPane")
            let reopened = try model(defaults)
            #expect(reopened.selection == .general)
        }
    }
}

@Suite struct RecorderRules {
    private func key(_ text: String) -> Shortcut { Shortcut(parsing: text)! }

    @Test func thePeekPanelKeyIsBareSpaceOrAKeyWithAModifier() {
        #expect(Shortcut.Rules.peekPanel.refusal(for: key("space")) == nil)
        #expect(Shortcut.Rules.peekPanel.refusal(for: key("opt+j")) == nil)
        #expect(Shortcut.Rules.peekPanel.refusal(for: key("j")) != nil)
    }

    @Test func aToolNeedsAModifier() {
        #expect(Shortcut.Rules.viewTool.refusal(for: key("j")) != nil)
        #expect(Shortcut.Rules.viewTool.refusal(for: key("space")) != nil)
        #expect(Shortcut.Rules.viewTool.refusal(for: key("cmd+j")) == nil)
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

    @Test func commandEIsFree() {
        #expect(conflict("cmd+e", for: "highlight") == nil)
    }

    @Test func anotherToolOfThePluginTakesItsKey() {
        #expect(conflict("cmd+=", for: "highlight") == "Zoom In")
        var config = Config()
        config.keys["pdf.zoom-in"] = Shortcut(parsing: "cmd+shift+z")
        #expect(conflict("cmd+shift+z", for: "highlight", config: config) == "Zoom In")
        #expect(conflict("cmd+=", for: "highlight", config: config) == nil, "Zoom In moved off cmd+=")
    }

    @Test func aToolKeepingItsOwnKeyIsNoClash() {
        #expect(conflict("ctrl+cmd+h", for: "highlight") == nil)
        #expect(conflict("cmd+j", for: "highlight") == nil)
    }

    @Test func theMenuShortcutsSkipPluginTools() {
        let main = NSMenu()
        let file = NSMenu(title: "File")
        file.addItem(NSMenuItem(title: "Save", action: nil, keyEquivalent: "s"))
        let redo = NSMenuItem(title: "Redo", action: nil, keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        file.addItem(redo)
        main.addItem(withTitle: "File", action: nil, keyEquivalent: "").submenu = file
        let view = NSMenu(title: "View")
        let sidebar = NSMenuItem(title: "Show Sidebar", action: nil, keyEquivalent: "s")
        sidebar.keyEquivalentModifierMask = [.control, .command]
        view.addItem(sidebar)
        view.addItem(NSMenuItem(title: "Zoom In", action: #selector(DocumentWindowController.runTool(_:)), keyEquivalent: "="))
        main.addItem(withTitle: "View", action: nil, keyEquivalent: "").submenu = view
        let shortcuts = menuShortcuts(in: main)
        #expect(shortcuts.map(\.title) == ["Save", "Redo", "Show Sidebar"])
        #expect(shortcuts.map(\.shortcut) == [Shortcut(parsing: "cmd+s"), Shortcut(parsing: "cmd+shift+z"), Shortcut(parsing: "ctrl+cmd+s")])
    }

    @Test func theFixedKeysCoverViewAndToolsButNoPluginDefault() {
        let fixed = MainMenu.fixedShortcuts
        #expect(fixed.contains { $0.title == "Show Sidebar" && $0.shortcut == Shortcut(parsing: "ctrl+cmd+s") })
        #expect(fixed.contains { $0.title == "Save" && $0.shortcut == Shortcut(parsing: "cmd+s") })
        for plugin in PluginCatalog.builtIn {
            for command in plugin.tools {
                guard let key = command.shortcut.flatMap(Shortcut.init(parsing:)) else { continue }
                #expect(!fixed.contains { $0.shortcut == key }, "\(plugin.id).\(command.id) defaults to a menu key")
            }
        }
    }

    @Test func settingsRefusesPrintAndFindPreviousForTools() {
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

@Suite struct ShortcutClearing {
    @Test func clearingAShortcutWritesOff() throws {
        let file = try TempFile.make(Data("{}".utf8), name: "config.json")
        let store = ConfigStore(url: file, plugins: plugins)
        defer { store.stop() }
        let model = SettingsModel(store: store, accessibility: AccessibilityStatus(), updater: Updater(version: "0.1.0", build: "100"))
        model.save { $0.clearShortcut(for: Config.keyID(plugin: "pdf", command: "zoom-in")) }
        let saved = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        let pdf = try #require((saved["plugins"] as? [String: [String: Any]])?["pdf"])
        #expect((pdf["tools"] as? [String: [String: String]])?["zoom-in"] == ["shortcut": "off"])
    }
}

/// A refused key's reason stays under the recorder until the next recording, and VoiceOver hears it.
@Suite struct RecorderRefusals {
    @Test func aRefusalIsAnnouncedAndStays() async throws {
        let note = RefusalNote()
        var announced: [String] = []
        note.announce = { announced.append($0) }
        note.show("⌘P is used by Print….")
        #expect(announced == ["⌘P is used by Print…."])
        try await Task.sleep(for: .seconds(3.5))
        #expect(note.text == "⌘P is used by Print….", "no longer clears itself after three seconds")
        note.clear()
        #expect(note.text == nil)
    }
}

@Suite struct KeyRecording {
    /// While any recorder listens, the Peek panel key is off; a second recorder taking over must not turn it back on.
    @Test func oneRecorderListensAtATime() throws {
        let file = try TempFile.make(Data("{}".utf8), name: "config.json")
        let store = ConfigStore(url: file, plugins: plugins)
        defer { store.stop() }
        let model = SettingsModel(store: store, accessibility: AccessibilityStatus(), updater: Updater(version: "0.1.0", build: "100"))
        var changes: [Bool] = []
        model.onRecordingChange = { changes.append($0) }
        model.recorder = "peekPanel"
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
        #expect(MenuBarItem.accessibilityTitle == "The Peek panel needs Accessibility…")
        #expect(MenuBarItem.State(problems: 0, needsAccessibility: false) == .init(dot: false, problemsLine: nil, accessibilityLine: false))
        #expect(MenuBarItem.State(problems: 2, needsAccessibility: false) == .init(dot: true, problemsLine: "Config has 2 problems", accessibilityLine: false))
        #expect(MenuBarItem.State(problems: 0, needsAccessibility: true) == .init(dot: true, problemsLine: nil, accessibilityLine: true))
        #expect(MenuBarItem.State(problems: 1, needsAccessibility: true) == .init(dot: true, problemsLine: "Config has 1 problem", accessibilityLine: true))
    }
}

@Suite struct TextThemeSettings {
    @Test func pickingAThemeRewritesTheConfig() throws {
        let file = try TempFile.make(Data("{}".utf8), name: "config.json")
        let store = ConfigStore(url: file, plugins: plugins)
        defer { store.stop() }
        let model = SettingsModel(store: store, accessibility: AccessibilityStatus(), updater: Updater(version: "0.1.0", build: "100"))
        model.textTheme = "paper"
        let saved = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        #expect(saved["textTheme"] as? String == "paper")
        #expect(model.textTheme == "paper")
    }

    @Test func pickingAppearancesRewritesTheConfig() throws {
        let file = try TempFile.make(Data("{}".utf8), name: "config.json")
        let store = ConfigStore(url: file, plugins: plugins)
        defer { store.stop() }
        let model = SettingsModel(store: store, accessibility: AccessibilityStatus(), updater: Updater(version: "0.1.0", build: "100"))
        model.appearance = "dark"
        model.textAppearance = "light"
        let saved = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        #expect(saved["appearance"] as? String == "dark")
        #expect(saved["textAppearance"] as? String == "light")
        #expect(model.appearance == "dark" && model.textAppearance == "light")
    }
}

@Suite @MainActor struct ThemeCards {
    @Test func cardsDrawTheVariantTextAppearancePicks() {
        #expect(ThemeCard.isDark(textAppearance: "dark", appIsDark: false))
        #expect(!ThemeCard.isDark(textAppearance: "light", appIsDark: true))
        #expect(ThemeCard.isDark(textAppearance: "app", appIsDark: true), "Match App follows the pane's own look")
        #expect(!ThemeCard.isDark(textAppearance: "app", appIsDark: false))
    }

    @Test func aCardsColorsAreTheThemesFixedLightOrDarkValues() {
        let paper = TextTheme.named("paper")!
        // Resolved in the opposite look to the one current, so the result can't come from the current appearance.
        #expect(hex(ThemeCard.resolve(paper.background, dark: true), in: .aqua) == 0x23211D)
        #expect(hex(ThemeCard.resolve(paper.background, dark: false), in: .darkAqua) == 0xF7F3EA)
        #expect(hex(ThemeCard.resolve(TextTheme.system.text, dark: true), in: .aqua) == hex(.labelColor, in: .darkAqua))
    }
}
