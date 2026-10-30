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

    /// Opens the same file `remaining` times in a row (closing it in between), recording each open.
    /// Run 0 is a cold app and a cold plugin, run 1 finds both warm, and before run 2 the plugin process is
    /// stopped, so run 2 minus run 1 is the cost of starting a plugin on demand.
    private func runBench(url: URL, remaining: Int, index: Int) {
        let bench = self.bench
        guard remaining > 0 else {
            NSApp.terminate(nil)
            return
        }
        guard let entry = catalog.defaultPlugin(for: url) else {
            bench.record(["file": url.lastPathComponent, "failure": "no plugin"])
            NSApp.terminate(nil)
            return
        }
        let process = catalog.process(for: entry)
        if index == 2 { process.stopAndWait() }
        let onReady: (DocumentViewController, Duration, Bool) -> Void = { [weak self] document, duration, wasRunning in
            bench.record([
                "file": url.lastPathComponent, "plugin": entry.id, "mode": bench.mode, "run": index,
                "pluginWasRunning": wasRunning, "openToReadyMs": Bench.ms(duration), "replyMs": Bench.ms(document.replyDuration), "launchMs": wasRunning ? NSNull() : Bench.ms(process.lastLaunch),
                "processToReadyMs": index == 0 ? Bench.msSinceProcessStart() : NSNull(),
                "hostFootprintMB": Bench.footprintMB(), "pluginFootprintMB": process.footprintMB ?? NSNull(),
            ])
            self?.closeBenchDocument()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self?.runBench(url: url, remaining: remaining - 1, index: index + 1) }
        }
        let onFailure: (DocumentViewController, String) -> Void = { _, message in
            bench.record(["file": url.lastPathComponent, "plugin": entry.id, "run": index, "failure": message])
            NSApp.terminate(nil)
        }
        if bench.mode == "panel" {
            let document = DocumentViewController(url: url, entry: entry, process: process, config: config, allowsEditing: false, recovery: nil)
            document.onReady = onReady
            document.onFailure = onFailure
            panel.show(document)
        } else {
            let controller = DocumentWindowController(url: url, catalog: catalog, config: config, allowsEditing: true, recovery: nil, recoveryClipboard: nil)
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
