import AppKit

/// Drives benchmark mode: one file, opened repeatedly, each open recorded.
final class BenchRunner {
    private let bench: Bench
    private let catalog: PluginCatalog
    private let config: Config
    private let panel: QuickLookPanel
    private var controller: DocumentWindowController?

    init(bench: Bench, catalog: PluginCatalog, config: Config, panel: QuickLookPanel) {
        self.bench = bench
        self.catalog = catalog
        self.config = config
        self.panel = panel
    }

    func start(url: URL) {
        runBench(url: url, remaining: bench.repeats, index: 0)
    }

    /// Opens the same file `remaining` times in a row (closing it in between), recording each open. Run 0 is a cold
    /// app; the later runs find it warm.
    private func runBench(url: URL, remaining: Int, index: Int) {
        let bench = self.bench
        guard remaining > 0 else {
            NSApp.terminate(nil)
            return
        }
        guard let entry = catalog.owner(for: url) else {
            bench.record(["file": url.lastPathComponent, "failure": "no plugin"])
            NSApp.terminate(nil)
            return
        }
        let onReady: (DocumentViewController, Duration) -> Void = { [weak self] document, duration in
            bench.record([
                "file": url.lastPathComponent, "plugin": entry.id, "mode": bench.mode, "run": index,
                "openToReadyMs": Bench.ms(duration), "openMs": Bench.ms(document.openDuration),
                "processToReadyMs": index == 0 ? Bench.msSinceProcessStart() : NSNull(),
                "appFootprintMB": Bench.footprintMB(),
            ])
            self?.closeBenchDocument()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self?.runBench(url: url, remaining: remaining - 1, index: index + 1) }
        }
        let onFailure: (DocumentViewController, String) -> Void = { _, message in
            bench.record(["file": url.lastPathComponent, "plugin": entry.id, "run": index, "failure": message])
            NSApp.terminate(nil)
        }
        if bench.mode == "panel" {
            let document = DocumentViewController(url: url, entry: entry, config: config, allowsEditing: false, recovery: nil)
            document.onReady = onReady
            document.onFailure = onFailure
            panel.show(document)
        } else {
            // As when the user opens a file: Peeker turns into a regular app with its first window.
            Presence.update(documentWindows: 1, settingsOpen: false)
            let controller = DocumentWindowController(url: url, catalog: catalog, config: config, recovery: nil, recoveryClipboard: nil)
            controller.onDocument = { $0.onReady = onReady; $0.onFailure = onFailure }
            self.controller = controller
            controller.showWindow(nil)
            controller.show(with: entry)
        }
    }

    private func closeBenchDocument() {
        if bench.mode == "panel" {
            panel.dismiss()
        } else {
            controller?.close()
            controller = nil
        }
    }
}
