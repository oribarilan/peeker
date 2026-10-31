import SwiftUI

/// The quick-look key: on or off, and which key.
struct GeneralPane: View {
    let model: SettingsModel

    private var store: ConfigStore { model.store }

    var body: some View {
        Form {
            ConfigLockedSection(store: store)
            Section {
                Toggle("Quick look panel", isOn: Binding(
                    get: { store.config.quickLookKey != nil },
                    set: { on in model.save { $0.quickLookKey = on ? Shortcut(key: .space) : nil } }))
                LabeledContent("Key") {
                    KeyRecorder(shortcut: store.config.quickLookKey, rules: .quickLook,
                                onRecord: { key in model.save { $0.quickLookKey = key } },
                                onRecordingChange: { model.onRecordingChange?($0) })
                }
                .disabled(store.config.quickLookKey == nil)
            } footer: {
                Text("Space opens the panel only in Finder, and not while you type there. A key with Command, Option or Control opens it from any app. Off leaves Space to Finder's Quick Look.")
                    .foregroundStyle(.secondary)
            }
            .disabled(!store.isUsable)
        }
        .formStyle(.grouped)
    }
}
