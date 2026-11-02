import SwiftUI

/// Open at Login, with a note while macOS still needs the user's approval. It doesn't change the config, so it stays
/// usable while the config is locked.
struct LoginSection: View {
    @State private var enabled = LoginItem.isEnabled
    @State private var needsApproval = LoginItem.needsApproval

    var body: some View {
        Section {
            Toggle("Open at Login", isOn: Binding(get: { enabled || needsApproval }, set: { _ in
                LoginItem.toggleReportingErrors()
                refresh()
            }))
            if needsApproval {
                LabeledContent {
                    Button("Open Login Items") { LoginItem.openSystemSettings() }
                } label: {
                    Text("macOS needs your approval in Login Items.").foregroundStyle(.secondary)
                }
            }
        } footer: {
            Text("The Peek panel works only while Peeker is running.").foregroundStyle(.secondary)
        }
        .task {
            // Re-read every second while it's on screen: the approval happens in System Settings.
            while !Task.isCancelled {
                refresh()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func refresh() {
        enabled = LoginItem.isEnabled
        needsApproval = LoginItem.needsApproval
    }
}
