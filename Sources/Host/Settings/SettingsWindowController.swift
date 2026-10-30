import AppKit
import SwiftUI

/// The Settings window. One pane for now, Config file; later changes add panes beside it.
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    var onClose: (() -> Void)?

    init(store: ConfigStore) {
        let window = NSWindow(contentViewController: NSHostingController(rootView: ConfigFilePane(store: store)))
        window.title = "Settings"
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 560, height: 420))
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func windowWillClose(_ notification: Notification) { onClose?() }
}

/// Where the config file is, a way to open it, and what's wrong with it, kept current as the file is saved.
struct ConfigFilePane: View {
    let store: ConfigStore

    var body: some View {
        Form {
            Section("Config file") {
                LabeledContent("Location") {
                    Text((store.url.path as NSString).abbreviatingWithTildeInPath)
                        .textSelection(.enabled)
                        .truncationMode(.middle)
                }
                Button("Open in Editor") { ConfigFile.openInEditor(store.url, plugins: store.plugins) }
            }
            Section("Problems") {
                if store.problems.isEmpty {
                    Text("No problems.").foregroundStyle(.secondary)
                } else {
                    ForEach(store.problems, id: \.self) { problem in
                        VStack(alignment: .leading, spacing: 2) {
                            if !problem.path.isEmpty { Text(problem.path).font(.body.monospaced()) }
                            Text(problem.message).foregroundStyle(.secondary)
                        }
                        .textSelection(.enabled)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
