import SwiftUI
import PeekerKit

/// The Peek panel key (on or off, and which key), the text theme, Open at Login, the default app per plugin, and update
/// checks.
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
            } footer: {
                Text("Space opens the Peek panel only in Finder, and not while you type there. A key with Command, Option or Control opens it from any app. Off leaves Space to Finder's Quick Look.")
                    .foregroundStyle(.secondary)
            }
            .disabled(!store.isUsable)
            Section {
                Picker("Text theme", selection: $model.textTheme) {
                    // One section per group: the pop-up draws a separator between sections.
                    ForEach(Array(Set(TextTheme.all.map(\.group))).sorted(), id: \.self) { group in
                        Section {
                            ForEach(TextTheme.all.filter { $0.group == group }, id: \.id) { Text($0.name).tag($0.id) }
                        }
                    }
                }
            } footer: {
                Text("The colors of Markdown and text files, in windows and the Peek panel. Each theme has a light and a dark look and follows the system.")
                    .foregroundStyle(.secondary)
            }
            .disabled(!store.isUsable)
            LoginSection()
            DefaultAppSection(model: model)
            Section {
                Toggle("Check for updates automatically", isOn: $model.checkForUpdates)
                    .disabled(!store.isUsable)
                LabeledContent(model.updater.versionLine) {
                    Button("Check Now") { model.updater.checkNow() }
                }
            } header: {
                Text("Updates")
            } footer: {
                Text("Peeker checks once a day and shows what's new before installing anything.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
