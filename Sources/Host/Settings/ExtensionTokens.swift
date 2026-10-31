import SwiftUI

/// A plugin's extensions as removable tokens, a field to add one, and Reset. Adding one another plugin has asks to
/// move it.
struct ExtensionTokens: View {
    let model: SettingsModel
    let plugin: PluginEntry

    @State private var draft = ""
    @State private var message: String?
    @State private var move: Move?

    private struct Move {
        let ext: String
        let owner: PluginEntry
    }

    private var plugins: [PluginEntry] { model.plugins }
    private var list: [String] { model.store.config.effectiveExtensions(of: plugin, among: plugins) }

    private var isDefault: Bool {
        var defaults = model.store.config
        defaults.resetExtensions(of: plugin, among: plugins)
        return defaults.effectiveExtensions(of: plugin, among: plugins) == list
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if list.isEmpty {
                Text("\(plugin.name) opens no files.").foregroundStyle(.secondary)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(list, id: \.self) { ext in token(ext) }
                }
            }
            HStack {
                TextField("Add an extension", text: $draft)
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                    .onSubmit(add)
                Button("Add", action: add).disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                Spacer()
                Button("Reset to Defaults") { model.save { $0.resetExtensions(of: plugin, among: plugins) } }
                    .disabled(isDefault)
                    .help(plugin.defaultExtensions.joined(separator: ", "))
            }
            if let message { Text(message).font(.caption).foregroundStyle(.red) }
        }
        .confirmationDialog(move.map { "“\($0.ext)” opens in \($0.owner.name)" } ?? "", isPresented: Binding(get: { move != nil }, set: { if !$0 { move = nil } })) {
            if let move {
                Button("Move to \(plugin.name)") {
                    model.save { $0.moveExtension(move.ext, to: plugin, among: plugins) }
                    draft = ""
                }
                Button("Cancel", role: .cancel) {}
            }
        } message: {
            if let move { Text("Move it, and \(move.owner.name) stops opening .\(move.ext) files.") }
        }
    }

    private func token(_ ext: String) -> some View {
        HStack(spacing: 4) {
            Text(ext).font(.callout.monospaced())
            Button { model.save { $0.removeExtension(ext, from: plugin, among: plugins) } } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(ext)")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.quaternary, in: Capsule())
    }

    private func add() {
        let text = draft.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        guard let ext = Config.extensionEntry(text) else {
            message = "“\(text)” isn't an extension. Type one like md, without the dot, or noExtension."
            return
        }
        message = nil
        if let owner = model.store.config.owner(of: ext, among: plugins), owner.id != plugin.id {
            move = Move(ext: ext, owner: owner)
            return
        }
        model.save { $0.addExtension(ext, to: plugin, among: plugins) }
        draft = ""
    }
}

/// Lays out views in rows, wrapping to the next row when one is full.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func rows(width: CGFloat, subviews: Subviews) -> [(indices: [Int], width: CGFloat, height: CGFloat)] {
        var rows: [(indices: [Int], width: CGFloat, height: CGFloat)] = []
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if let last = rows.last, last.width + spacing + size.width <= width {
                rows[rows.count - 1] = (last.indices + [index], last.width + spacing + size.width, max(last.height, size.height))
            } else {
                rows.append(([index], size.width, size.height))
            }
        }
        return rows
    }
}
