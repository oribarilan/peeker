import AppKit
import SwiftUI

/// The "Updated to Peeker 0.4.0" window: the notes of each version since the one last run, newest first, and Done.
final class WhatsNewWindowController: NSWindowController {
    let releases: [Changelog.Release]

    init(version: String, releases: [Changelog.Release]) {
        self.releases = releases
        let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Updated to Peeker \(version)"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.contentViewController = NSHostingController(rootView: WhatsNewView(releases: releases) { [weak self] in self?.done() })
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func done() { close() }
}

private struct WhatsNewView: View {
    let releases: [Changelog.Release]
    let done: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(releases, id: \.version) { release in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Version \(release.version)").font(.headline)
                            ForEach(Array(release.notes.enumerated()), id: \.offset) { _, note in
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text("•")
                                    Text((try? AttributedString(markdown: note)) ?? AttributedString(note))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            }
            .frame(minHeight: 120, maxHeight: 360)
            HStack {
                Spacer()
                Button("Done", action: done).keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 480)
    }
}
