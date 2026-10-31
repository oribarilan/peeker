import SwiftUI

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
