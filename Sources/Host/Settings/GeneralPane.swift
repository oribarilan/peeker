import SwiftUI

/// The Peek panel key (on or off, and which key), Open at Login, the default app per plugin, and update checks.
struct GeneralPane: View {
    @Bindable var model: SettingsModel

    private var store: ConfigStore { model.store }

    var body: some View {
        Form {
            ConfigLockedSection(store: store)
            Section {
                Toggle("Peek panel", isOn: Binding(
                    get: { store.config.peekPanelKey != nil },
                    set: { on in model.save { $0.peekPanelKey = on ? Shortcut(key: .space) : nil } }))
                LabeledContent("Key") {
                    KeyRecorder(shortcut: store.config.peekPanelKey, rules: .peekPanel, listening: $model.recorder, id: "peekPanel",
                                onRecord: { key in model.save { $0.peekPanelKey = key } })
                }
                .disabled(store.config.peekPanelKey == nil)
                Group {
                    buttonKeyRow("Open key", id: "peekPanel.open", current: store.config.peekPanelOpenKey,
                                 other: store.config.peekPanelShowInFinderKey, default: Config.defaultOpenKey) { $0.peekPanelOpenKey = $1 }
                    buttonKeyRow("Show in Finder key", id: "peekPanel.showInFinder", current: store.config.peekPanelShowInFinderKey,
                                 other: store.config.peekPanelOpenKey, default: Config.defaultShowInFinderKey) { $0.peekPanelShowInFinderKey = $1 }
                }
                .disabled(store.config.peekPanelKey == nil)
                PeekPanelReset(model: model)
            } footer: {
                Text("Space opens the Peek panel only in Finder, and not while you type there. A key with Command, Option or Control opens it from any app. Off leaves Space to Finder's Quick Look. The Open and Show in Finder keys work while the panel is up over Finder.")
                    .foregroundStyle(.secondary)
            }
            .disabled(!store.isUsable)
            LoginSection()
            DefaultAppSection(model: model)
            Section {
                Group {
                    Picker("Automatic updates", selection: $model.automaticUpdates) {
                        ForEach(SettingsModel.automaticUpdateChoices, id: \.mode) { Text($0.title).tag($0.mode) }
                    }
                    Toggle("Show what's new after updating", isOn: $model.showWhatsNew)
                }
                .disabled(!store.isUsable)
                LabeledContent(model.updater.versionLine) {
                    Button("Check Now") { model.updater.checkNow() }
                }
            } header: {
                Text("Updates")
            } footer: {
                Text(SettingsModel.automaticUpdateChoices.first { $0.mode == model.automaticUpdates }?.footer ?? "")
                    .foregroundStyle(.secondary)
            }
            TipsSection(model: model)
        }
        .formStyle(.grouped)
    }
}

extension GeneralPane {
    /// A key for one of the panel's buttons: a recorder, a button that leaves it without a key, and Reset.
    private func buttonKeyRow(_ title: String, id: String, current: Shortcut?, other: Shortcut?, default defaultKey: Shortcut,
                              set: @escaping (inout Config, Shortcut?) -> Void) -> some View {
        let panelKey = store.config.peekPanelKey
        return LabeledContent(title) {
            HStack(alignment: .firstTextBaseline) {
                KeyRecorder(shortcut: current, rules: .panelAction,
                            conflict: { $0 == panelKey ? "That's the Peek panel key." : $0 == other ? "The other button has that key." : nil },
                            listening: $model.recorder, id: id,
                            onRecord: { key in model.save { set(&$0, key) } })
                if current != nil {
                    Button { model.save { set(&$0, nil) } } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                        .help("No key")
                        .accessibilityLabel("Clear the \(title)")
                }
                Button("Reset") { model.save { set(&$0, defaultKey) } }
                    .disabled(current == defaultKey)
                    .help("Back to \(defaultKey.displayText)")
            }
        }
    }
}

/// Reset Panel Size, greyed out until the user has moved or resized the Peek panel. It follows the saved frame live.
private struct PeekPanelReset: View {
    let model: SettingsModel
    @AppStorage private var savedFrame: String?

    init(model: SettingsModel) {
        self.model = model
        _savedFrame = AppStorage(PeekPanel.frameKey, store: model.defaults)
    }

    var body: some View {
        LabeledContent("Size and position") {
            Button("Reset Panel Size") { model.resetPeekPanelFrame() }
                .disabled(savedFrame == nil)
        }
    }
}

/// Show Tips Again, greyed out until a first-use tip has been shown. It follows the saved tips live.
private struct TipsSection: View {
    let model: SettingsModel
    @AppStorage private var seen: String?

    init(model: SettingsModel) {
        self.model = model
        _seen = AppStorage(TipStore.key, store: model.defaults)
    }

    var body: some View {
        Section {
            LabeledContent("Tips for tools such as Highlight and Crop") {
                Button("Show Tips Again") { model.showTipsAgain() }
                    .disabled(seen == nil)
            }
        } header: {
            Text("Tips")
        }
    }
}
