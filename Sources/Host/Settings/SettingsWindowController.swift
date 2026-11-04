import AppKit
import SwiftUI

/// The panes in the Settings sidebar.
enum SettingsPane: Hashable {
    case general, appearance, plugin(String), permissions, configFile

    /// In sidebar order: General, Appearance, each plugin in catalog order, Permissions, Config File.
    static func all(plugins: [PluginEntry]) -> [SettingsPane] {
        [.general, .appearance] + plugins.map { .plugin($0.id) } + [.permissions, .configFile]
    }

    /// How the pane is kept in preferences: `general`, `appearance`, `plugin.pdf`, `permissions` or `configFile`.
    var storageKey: String {
        switch self {
        case .general: "general"
        case .appearance: "appearance"
        case .plugin(let id): "plugin.\(id)"
        case .permissions: "permissions"
        case .configFile: "configFile"
        }
    }

    init?(storageKey: String) {
        switch storageKey {
        case "general": self = .general
        case "appearance": self = .appearance
        case "permissions": self = .permissions
        case "configFile": self = .configFile
        case let key where key.hasPrefix("plugin.") && key.count > "plugin.".count: self = .plugin(String(key.dropFirst("plugin.".count)))
        default: return nil
        }
    }
}

/// What every pane works with: the config store, the Accessibility status, and the selected pane.
@Observable
final class SettingsModel {
    let store: ConfigStore
    let accessibility: AccessibilityStatus
    @ObservationIgnored let updater: Updater
    /// Where the last pane shown is kept, so Settings reopens on it, and where the Peek panel keeps its frame; nil
    /// remembers nothing.
    @ObservationIgnored let defaults: UserDefaults?
    private static let paneKey = "settingsPane"
    var selection: SettingsPane? = .general {
        didSet { if let selection { defaults?.set(selection.storageKey, forKey: Self.paneKey) } }
    }
    /// The key recorder listening for keys, by an id such as `peekPanel` or `pdf.zoom-in`. One at a time: starting
    /// another stops this one.
    var recorder: String? {
        didSet { if (recorder == nil) != (oldValue == nil) { onRecordingChange?(recorder != nil) } }
    }
    /// Told when recording starts or stops, so the Peek panel key doesn't fire meanwhile.
    @ObservationIgnored var onRecordingChange: ((Bool) -> Void)?
    /// Forgets the Peek panel's saved frame; the app sets it.
    @ObservationIgnored var resetPeekPanel: () -> Void = {}
    /// Forgets which first-use tips were shown; the app sets it.
    @ObservationIgnored var resetTips: () -> Void = {}

    /// Whether any first-use tip has been shown, which Show Tips Again undoes.
    var hasShownTips: Bool { defaults.map { TipStore(defaults: $0).hasShownAny } ?? false }

    func showTipsAgain() { resetTips() }

    /// Whether the user has moved or resized the Peek panel, which Reset Panel Size undoes.
    var hasSavedPeekPanelFrame: Bool { defaults.map(PeekPanel.hasSavedFrame(in:)) ?? false }

    func resetPeekPanelFrame() { resetPeekPanel() }

    init(store: ConfigStore, accessibility: AccessibilityStatus, updater: Updater, defaults: UserDefaults? = nil) {
        self.store = store
        self.accessibility = accessibility
        self.updater = updater
        self.defaults = defaults
        let stored = defaults?.string(forKey: Self.paneKey).flatMap(SettingsPane.init(storageKey:))
        if let stored, SettingsPane.all(plugins: store.plugins).contains(stored) { selection = stored }
    }

    /// The Automatic updates pop-up's choices, one per `Config.automaticUpdateModes`.
    static let automaticUpdateChoices = [(mode: "off", title: "Off", footer: "Peeker checks for a new version only when you click Check Now."),
                                         (mode: "check", title: "Check and Ask", footer: "Peeker checks once a day and shows what's new before installing anything."),
                                         (mode: "download", title: "Download and Install", footer: "Peeker checks once a day, downloads a new version and installs it once no Peeker window is open.")]

    /// The Automatic updates pop-up: the config's `updates.automatic`.
    var automaticUpdates: String {
        get { store.config.automaticUpdates }
        set { save { $0.automaticUpdates = newValue } }
    }

    /// The "Show what's new after updating" checkbox: the config's `updates.showWhatsNew`.
    var showWhatsNew: Bool {
        get { store.config.showWhatsNew }
        set { save { $0.showWhatsNew = newValue } }
    }

    /// The theme cards: the config's `textTheme`.
    var textTheme: String {
        get { store.config.textTheme }
        set { save { $0.textTheme = newValue } }
    }

    /// The Appearance control: the config's `appearance`.
    var appearance: String {
        get { store.config.appearance }
        set { save { $0.appearance = newValue } }
    }

    /// The Text appearance control: the config's `textAppearance`.
    var textAppearance: String {
        get { store.config.textAppearance }
        set { save { $0.textAppearance = newValue } }
    }

    /// The "Show shortcuts in the toolbar" checkbox: the config's `showShortcuts`.
    var showShortcuts: Bool {
        get { store.config.showShortcuts }
        set { save { $0.showShortcuts = newValue } }
    }

    var plugins: [PluginEntry] { store.plugins }

    /// Saves a change to the config, reporting a failure; the controls then show the settings still in use.
    func save(_ change: (inout Config) -> Void) {
        do {
            try store.save(change)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't save the settings"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
}

/// The Settings window: a sidebar of panes, modeled on Tinycast's.
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    var onClose: (() -> Void)?
    let model: SettingsModel

    init(model: SettingsModel) {
        self.model = model
        let hosting = NSHostingController(rootView: SettingsView(model: model))
        hosting.sizingOptions = []  // the window sets the size, not the pane's content
        let window = NSWindow(contentViewController: hosting)
        window.title = "Settings"
        window.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
        window.toolbarStyle = .unified
        window.setContentSize(NSSize(width: 720, height: 520))
        window.contentMinSize = NSSize(width: 620, height: 420)
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("SettingsWindow")
        window.standardWindowButton(.zoomButton)?.isEnabled = false  // it resizes, but there's nothing to zoom to
        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func select(_ pane: SettingsPane) { model.selection = pane }

    func windowWillClose(_ notification: Notification) { onClose?() }
}

struct SettingsView: View {
    @Bindable var model: SettingsModel

    var body: some View {
        NavigationSplitView {
            List(selection: $model.selection) {
                Label("General", systemImage: "gearshape").tag(SettingsPane.general)
                Label("Appearance", systemImage: "paintpalette").tag(SettingsPane.appearance)
                Section("Plugins") {
                    ForEach(model.plugins, id: \.id) { plugin in
                        Label(plugin.name, systemImage: plugin.symbol).tag(SettingsPane.plugin(plugin.id))
                    }
                }
                Section {
                    Label {
                        HStack {
                            Text("Permissions")
                            if model.accessibility.isMissing {
                                Circle().fill(.red).frame(width: 7, height: 7).accessibilityLabel("A permission is missing")
                            }
                        }
                    } icon: {
                        Image(systemName: "lock.shield")
                    }
                    .tag(SettingsPane.permissions)
                    Label("Config File", systemImage: "doc.text").tag(SettingsPane.configFile)
                }
            }
            .navigationSplitViewColumnWidth(200)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            pane.navigationTitle(title)
        }
    }

    @ViewBuilder private var pane: some View {
        switch model.selection ?? .general {
        case .general: GeneralPane(model: model)
        case .appearance: AppearancePane(model: model)
        case .plugin(let id):
            if let plugin = model.plugins.first(where: { $0.id == id }) { PluginPane(model: model, plugin: plugin).id(id) }
        case .permissions: PermissionsPane(model: model)
        case .configFile: ConfigFilePane(store: model.store)
        }
    }

    private var title: String {
        switch model.selection ?? .general {
        case .general: "General"
        case .appearance: "Appearance"
        case .plugin(let id): model.plugins.first { $0.id == id }?.name ?? "Plugin"
        case .permissions: "Permissions"
        case .configFile: "Config File"
        }
    }
}

/// Shown at the top of panes that change the config while the file can't be used; their controls are disabled.
struct ConfigLockedSection: View {
    let store: ConfigStore

    var body: some View {
        if !store.isUsable {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Label("config.json can't be used, so these settings are locked until it's fixed.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    if let problem = store.problems.first { Text(problem.message).foregroundStyle(.secondary).textSelection(.enabled) }
                    Button("Open in Editor") { ConfigFile.openInEditor(store.url, plugins: store.plugins) }
                }
            }
        }
    }
}
