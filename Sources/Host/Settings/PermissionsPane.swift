import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// What Space in Finder needs, Open at Login, and whether Peeker is the default app for each plugin's files. These
/// controls don't change the config, so they stay usable while it's locked.
struct PermissionsPane: View {
    let model: SettingsModel

    @State private var finder: PermissionState?
    @State private var loginEnabled = LoginItem.isEnabled
    @State private var loginNeedsApproval = LoginItem.needsApproval
    @State private var defaults: [String: [ExtensionDefault]] = [:]

    var body: some View {
        Form {
            Section {
                PermissionRow(title: "Accessibility", detail: "Lets Peeker see the quick-look key while you're in Finder.",
                              state: model.accessibility.isTrusted ? .granted : .notGranted) {
                    PermissionChecks.openPrivacySettings("Privacy_Accessibility")
                }
                PermissionRow(title: "Control Finder", detail: "Lets Peeker read which files are selected in Finder.", state: finder) {
                    if finder == .notAsked {
                        Task.detached { _ = PermissionChecks.finderStatus(asking: true) }
                    } else {
                        PermissionChecks.openPrivacySettings("Privacy_Automation")
                    }
                }
            } header: {
                Text("Space in Finder")
            }
            Section {
                Toggle("Open at Login", isOn: Binding(get: { loginEnabled || loginNeedsApproval }, set: { _ in
                    LoginItem.toggleReportingErrors()
                    refreshLogin()
                }))
                if loginNeedsApproval {
                    LabeledContent {
                        Button("Open Login Items") { LoginItem.openSystemSettings() }
                    } label: {
                        Text("macOS needs your approval in Login Items.").foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text("Space in Finder works only while Peeker is running.").foregroundStyle(.secondary)
            }
            Section {
                ForEach(model.plugins, id: \.id) { plugin in
                    DefaultAppRow(plugin: plugin, extensions: defaults[plugin.id] ?? []) { types in makeDefault(types) }
                }
            } header: {
                Text("Default app")
            } footer: {
                Text("Extensions without a system file type, such as conf, can only be set with Get Info in Finder.").foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .task {
            refreshDefaults()
            // Re-read every second while the pane is on screen; Settings may be open beside System Settings.
            while !Task.isCancelled {
                model.accessibility.refresh()
                refreshLogin()
                if let status = PermissionState(appleEventStatus: await Task.detached { PermissionChecks.finderStatus(asking: false) }.value) {
                    finder = status
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in refreshDefaults() }
    }

    private func refreshLogin() {
        loginEnabled = LoginItem.isEnabled
        loginNeedsApproval = LoginItem.needsApproval
    }

    private func refreshDefaults() {
        let config = model.store.config
        defaults = Dictionary(uniqueKeysWithValues: model.plugins.map { ($0.id, DefaultApps.check(config.effectiveExtensions(of: $0, among: model.plugins))) })
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
            refreshDefaults()
        }
    }
}

private struct PermissionRow: View {
    let title: String
    let detail: String
    let state: PermissionState?
    let grant: () -> Void

    var body: some View {
        LabeledContent {
            HStack {
                status
                Button(state == .granted ? "Open…" : "Grant Access…", action: grant)
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var status: some View {
        switch state {
        case .granted: Label("Granted", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .notGranted: Label("Not granted", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        case .notAsked: Label("Not asked yet", systemImage: "questionmark.circle").foregroundStyle(.secondary)
        case nil: Label("Checking…", systemImage: "ellipsis.circle").foregroundStyle(.secondary)
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
