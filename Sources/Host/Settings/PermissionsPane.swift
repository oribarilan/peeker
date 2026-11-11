import AppKit
import SwiftUI

/// What the Peek panel needs: Accessibility and control of Finder. These controls don't change the config, so they stay
/// usable while it's locked.
struct PermissionsPane: View {
    let model: SettingsModel

    @State private var finder: PermissionState?

    var body: some View {
        Form {
            Section {
                PermissionRow(
                    title: "Accessibility", detail: "Lets Peeker see the Peek panel key while you're in Finder.",
                    state: model.accessibility.isTrusted ? .granted : .notGranted
                ) {
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
                Text("Peek panel")
            }
        }
        .formStyle(.grouped)
        .task {
            // Re-read every second while the pane is on screen; Settings may be open beside System Settings.
            while !Task.isCancelled {
                model.accessibility.refresh()
                if let status = PermissionState(appleEventStatus: await Task.detached { PermissionChecks.finderStatus(asking: false) }.value) {
                    finder = status
                }
                try? await Task.sleep(for: .seconds(1))
            }
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
