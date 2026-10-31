import AppKit
import SwiftUI

/// The panes in the Settings sidebar.
enum SettingsPane: Hashable {
    case general, plugin(String), permissions, configFile

    /// In sidebar order: General, each plugin in catalog order, Permissions, Config File.
    static func all(plugins: [PluginEntry]) -> [SettingsPane] {
        [.general] + plugins.map { .plugin($0.id) } + [.permissions, .configFile]
    }
}

/// What every pane works with: the config store, the Accessibility status, and the selected pane.
@Observable
final class SettingsModel {
    let store: ConfigStore
    let accessibility: AccessibilityStatus
    var selection: SettingsPane? = .general
    /// The key recorder listening for keys, by an id such as `quickLook` or `pdf.zoom-in`. One at a time: starting
    /// another stops this one.
    var recorder: String? {
        didSet { if (recorder == nil) != (oldValue == nil) { onRecordingChange?(recorder != nil) } }
    }
    /// Told when recording starts or stops, so the quick-look key doesn't fire meanwhile.
    @ObservationIgnored var onRecordingChange: ((Bool) -> Void)?

    init(store: ConfigStore, accessibility: AccessibilityStatus) {
        self.store = store
        self.accessibility = accessibility
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
                Section("Plugins") {
                    ForEach(model.plugins, id: \.id) { plugin in
                        Label(plugin.name, systemImage: "puzzlepiece.extension").tag(SettingsPane.plugin(plugin.id))
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
        case .plugin(let id):
            if let plugin = model.plugins.first(where: { $0.id == id }) { PluginPane(model: model, plugin: plugin).id(id) }
        case .permissions: PermissionsPane(model: model)
        case .configFile: ConfigFilePane(store: model.store)
        }
    }

    private var title: String {
        switch model.selection ?? .general {
        case .general: "General"
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
