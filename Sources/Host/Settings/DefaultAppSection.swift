import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Whether Peeker is the default app for each plugin's files, with Make Default. It doesn't change the config, so it
/// stays usable while the config is locked.
struct DefaultAppSection: View {
    let model: SettingsModel

    @State private var defaults: [String: [ExtensionDefault]] = [:]

    var body: some View {
        Section {
            ForEach(model.plugins, id: \.id) { plugin in
                DefaultAppRow(plugin: plugin, extensions: defaults[plugin.id] ?? []) { types in makeDefault(types) }
            }
        } header: {
            Text("Default app")
        } footer: {
            Text("Extensions without a system file type, such as conf, can only be set with Get Info in Finder.").foregroundStyle(.secondary)
        }
        .onAppear(perform: refresh)
        // Another app may have taken a file type over while Settings was in the background.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in refresh() }
    }

    private func refresh() {
        let config = model.store.config
        defaults = Dictionary(
            uniqueKeysWithValues: model.plugins.map { ($0.id, DefaultApps.check(config.effectiveExtensions(of: $0, among: model.plugins))) })
    }

    private func makeDefault(_ types: [UTType]) {
        Task {
            do {
                try await DefaultApps.makePeekerDefault(for: types)
            } catch {
                let alert = NSAlert()
                alert.messageText = "Couldn't make Peeker the default app"
                alert.informativeText = error.localizedDescription
                alert.runModal()
            }
            refresh()
        }
    }
}

/// One plugin's default-app status, expanding to each extension when Peeker is the default for only some.
private struct DefaultAppRow: View {
    let plugin: PluginEntry
    let extensions: [ExtensionDefault]
    let makeDefault: ([UTType]) -> Void

    private var summary: DefaultAppSummary { DefaultAppSummary(of: extensions) }
    private var missing: [UTType] { extensions.filter { !$0.isPeeker }.compactMap(\.type) }

    var body: some View {
        if case .some = summary {
            DisclosureGroup {
                ForEach(extensions, id: \.ext) { ext in extensionRow(ext) }
            } label: {
                header
            }
        } else {
            header
        }
    }

    private var header: some View {
        LabeledContent {
            HStack {
                Text(summaryText).foregroundStyle(.secondary)
                if summary != .all && summary != .cantSet { Button("Make Default") { makeDefault(missing) } }
            }
        } label: {
            Text(plugin.name)
        }
    }

    private var summaryText: String {
        switch summary {
        case .all: "Default"
        case .some(let count, let total): "Default for \(count) of \(total)"
        case .none: "Not the default"
        case .cantSet: "Can't be set here"
        }
    }

    private func extensionRow(_ ext: ExtensionDefault) -> some View {
        LabeledContent {
            HStack {
                if ext.type == nil {
                    Text("Can't be set here").foregroundStyle(.secondary)
                } else if ext.isPeeker {
                    Text("Peeker").foregroundStyle(.secondary)
                } else {
                    Text(ext.appName ?? "No app").foregroundStyle(.secondary)
                    if let type = ext.type { Button("Make Default") { makeDefault([type]) } }
                }
            }
        } label: {
            Text(".\(ext.ext)").font(.body.monospaced())
        }
    }
}
