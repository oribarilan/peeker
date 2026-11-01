import AppKit
import PeekerKit
import SwiftUI

/// One plugin's settings, all host rows: on/off, its extensions, its command shortcuts.
struct PluginPane: View {
    @Bindable var model: SettingsModel
    let plugin: PluginEntry

    private var store: ConfigStore { model.store }

    var body: some View {
        Form {
            ConfigLockedSection(store: store)
            Group {
                Section {
                    Toggle("Open files with \(plugin.name)", isOn: Binding(
                        get: { !store.config.disabled.contains(plugin.id) },
                        set: { on in model.save { if on { $0.disabled.remove(plugin.id) } else { $0.disabled.insert(plugin.id) } } }))
                } footer: {
                    Text("Off, \(plugin.name) opens nothing: its files go to Finder's Quick Look on Space, and no other plugin takes them.")
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
                if !plugin.commands.isEmpty {
                    Section("Shortcuts") {
                        ForEach(plugin.commands, id: \.id) { command in commandRow(command) }
                    }
                }
            }
            .disabled(!store.isUsable)
        }
        .formStyle(.grouped)
    }

    private func commandRow(_ command: CommandSpec) -> some View {
        let key = Config.keyID(plugin: plugin.id, command: command.id)
        let defaultShortcut = command.shortcut.flatMap(Shortcut.init(parsing:))
        let current = store.config.shortcut(for: command, of: plugin.id)
        return LabeledContent(command.title) {
            HStack(alignment: .firstTextBaseline) {
                KeyRecorder(shortcut: current, rules: command.isEditTool ? .editTool : .command,
                            conflict: { shortcutConflict($0, command: command.id, plugin: plugin, config: store.config, menu: menuShortcuts(in: NSApp.mainMenu ?? NSMenu())) },
                            listening: $model.recorder, id: key,
                            onRecord: { shortcut in model.save { $0.recordShortcut(shortcut, for: key) } })
                Button("Reset") { model.save { $0.resetShortcut(for: key) } }
                    .disabled(current == defaultShortcut)
                    .help("Back to \(defaultShortcut.map(\.displayText) ?? "no shortcut")")
            }
        }
    }
}
