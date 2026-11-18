import AppKit
import PeekerKit
import SwiftUI

/// One plugin's settings, all host rows: on/off, its extensions, the app that opens them in Finder, its tools' shortcuts.
struct PluginPane: View {
    @Bindable var model: SettingsModel
    let plugin: PluginEntry

    private var store: ConfigStore { model.store }

    var body: some View {
        Form {
            ConfigLockedSection(store: store)
            Group {
                Section {
                    Toggle(
                        "Open \(plugin.name) files in Peeker",
                        isOn: Binding(
                            get: { !store.config.disabled.contains(plugin.id) },
                            set: { on in model.save { if on { $0.disabled.remove(plugin.id) } else { $0.disabled.insert(plugin.id) } } }))
                } footer: {
                    Text(
                        "When this is off, Peeker opens no \(plugin.name) files and no other format takes them. Space shows Finder's Quick Look instead."
                    )
                    .foregroundStyle(.secondary)
                }
                Section {
                    ExtensionTokens(model: model, plugin: plugin)
                } header: {
                    Text("Extensions")
                } footer: {
                    Text("Without the dot. noExtension stands for files that have none, such as Makefile or .zshrc.")
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(!store.isUsable)
            // Outside the lock: it doesn't change the config.
            if !store.config.disabled.contains(plugin.id) {
                DefaultAppSection(model: model, plugin: plugin)
            }
            if !plugin.tools.isEmpty {
                Section("Tools") {
                    ForEach(plugin.tools, id: \.id) { tool in toolRow(tool) }
                }
                .disabled(!store.isUsable)
            }
        }
        .formStyle(.grouped)
    }

    private func toolRow(_ command: ToolSpec) -> some View {
        let key = Config.keyID(plugin: plugin.id, command: command.id)
        let defaultShortcut = command.shortcut.flatMap(Shortcut.init(parsing:))
        let current = store.config.shortcut(for: command, of: plugin.id)
        return LabeledContent(command.title) {
            HStack(alignment: .firstTextBaseline) {
                KeyRecorder(
                    shortcut: current, rules: command.isEditTool ? .editTool : .viewTool,
                    conflict: { shortcutConflict($0, command: command.id, plugin: plugin, config: store.config, menu: MainMenu.fixedShortcuts) },
                    listening: $model.recorder, id: key,
                    onRecord: { shortcut in model.save { $0.recordShortcut(shortcut, for: key) } })
                if current != nil {
                    Button {
                        model.save { $0.clearShortcut(for: key) }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("No shortcut")
                    .accessibilityLabel("Clear the shortcut for \(command.title)")
                }
                Button("Reset") { model.save { $0.resetShortcut(for: key) } }
                    .disabled(current == defaultShortcut)
                    .help("Back to \(defaultShortcut.map(\.displayText) ?? "no shortcut")")
            }
        }
    }
}
