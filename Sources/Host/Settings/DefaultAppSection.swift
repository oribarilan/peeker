import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The app macOS opens a plugin's files with, with Make Default. It doesn't change the config, so it
/// stays usable while the config is locked.
struct DefaultAppSection: View {
    let model: SettingsModel
    let plugin: PluginEntry

    @State private var extensions: [ExtensionDefault] = []

    private var listed: [String] { model.store.config.effectiveExtensions(of: plugin, among: model.plugins) }
    private var summary: DefaultAppSummary { DefaultAppSummary(of: extensions) }
    private var missing: [UTType] { extensions.filter { !$0.isPeeker }.compactMap(\.type) }

    var body: some View {
        Section {
            if DefaultAppSummary.expands(extensions) {
                DisclosureGroup {
                    ForEach(extensions, id: \.ext) { ext in extensionRow(ext) }
                } label: {
                    header
                }
            } else {
                header
            }
        } header: {
            Text("Default App")
        } footer: {
            Text(
                "The app macOS opens these files with, from Finder and other apps. Extensions without a system file type, such as conf, can only be set with Get Info in Finder."
            ).foregroundStyle(.secondary)
        }
        // Again when the extensions above change, since each one has a row.
        .task(id: [plugin.id] + listed) { refresh() }
        // Another app may have taken a file type over while Settings was in the background.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in refresh() }
    }

    private var header: some View {
        LabeledContent("Opens in") {
            HStack {
                Text(summaryText).foregroundStyle(.secondary)
                if summary != .peeker && summary != .cantSet { Button("Make Default") { makeDefault(missing) } }
            }
        }
    }

    private var summaryText: String {
        switch summary {
        case .peeker: ExtensionDefault.peekerName
        case .app(let name): name
        case .several: "Several apps"
        case .cantSet: "Can't be set here"
        }
    }

    private func extensionRow(_ ext: ExtensionDefault) -> some View {
        LabeledContent {
            HStack {
                if ext.type == nil {
                    Text("Can't be set here").foregroundStyle(.secondary)
                } else {
                    Text(ext.displayApp).foregroundStyle(.secondary)
                    if !ext.isPeeker, let type = ext.type { Button("Make Default") { makeDefault([type]) } }
                }
            }
        } label: {
            Text(".\(ext.ext)").font(.body.monospaced())
        }
    }

    private func refresh() {
        extensions = DefaultApps.check(listed)
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
