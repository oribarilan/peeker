import AppKit
import PreviewPPKit

/// A plugin that is any executable. One process per open tab, newline-delimited JSON over stdio:
///
///     host   -> {"id": 1, "method": "open", "params": {"path": "/x.csv"}}
///     plugin -> {"id": 1, "result": {"view": <node>}}       or {"id": 1, "error": "..."}
///     host   -> {"id": 2, "method": "command", "params": {"id": "sort"}}
///
/// The plugin never draws: it returns a declarative view tree that the host renders natively.
struct ProcessPluginAdapter: ExternalPlugin {
    let folder: URL
    let manifest: ExternalManifest
    var runtime: Runtime { .process }

    func open(_ url: URL, host: any PluginHost) throws -> Viewer {
        let process = try PluginProcess(executable: manifest.entryURL(in: folder))
        let controller = DeclarativeViewController()
        weak let weakHost = host
        let show: (Result<[String: Any], PluginProcess.Failure>) -> Void = { result in
            switch result {
            case .success(let reply):
                controller.render(reply["view"] ?? [:])
                weakHost?.contentDidBecomeReady()
            case .failure(let failure):
                weakHost?.viewerDidFail(failure.message)
            }
        }
        process.onExit = { status in
            weakHost?.viewerDidFail("The plugin process exited (status \(status)). The rest of the app is unaffected.")
        }
        process.request("open", ["path": url.path], reply: show)
        return Viewer(
            content: controller,
            commands: manifest.commands { process.request("command", ["id": $0], reply: show) },
            readiness: .reportedByPlugin,
            onClose: { process.terminate() }
        )
    }
}

final class PluginProcess {
    struct Failure: Error {
        let message: String
    }

    var onExit: ((Int32) -> Void)?
    private let process = Process()
    private let stdin = Pipe()
    private let stdout = Pipe()
    private var buffer = Data()
    private var nextID = 1
    private var pending: [Int: (Result<[String: Any], Failure>) -> Void] = [:]
    private var stoppedByHost = false

    init(executable: URL) throws {
        process.executableURL = executable
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = FileHandle.standardError
        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            Task { @MainActor in self?.consume(data) }
        }
        process.terminationHandler = { [weak self] finished in
            let status = finished.terminationStatus
            Task { @MainActor in self?.exited(status) }
        }
        try process.run()
    }

    func request(_ method: String, _ params: [String: Any], reply: @escaping (Result<[String: Any], Failure>) -> Void) {
        let id = nextID
        nextID += 1
        pending[id] = reply
        guard var line = try? JSONSerialization.data(withJSONObject: ["id": id, "method": method, "params": params]) else { return }
        line.append(0x0A)
        do {
            try stdin.fileHandleForWriting.write(contentsOf: line)
        } catch {
            pending.removeValue(forKey: id)?(.failure(Failure(message: "Could not reach the plugin process.")))
        }
    }

    func terminate() {
        stoppedByHost = true
        stdout.fileHandleForReading.readabilityHandler = nil
        if process.isRunning { process.terminate() }
    }

    private func consume(_ data: Data) {
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer[buffer.startIndex..<newline]
            buffer.removeSubrange(buffer.startIndex...newline)
            guard let message = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any],
                  let id = message["id"] as? Int, let reply = pending.removeValue(forKey: id) else { continue }
            if let result = message["result"] as? [String: Any] {
                reply(.success(result))
            } else {
                reply(.failure(Failure(message: message["error"] as? String ?? "Malformed reply from plugin.")))
            }
        }
    }

    private func exited(_ status: Int32) {
        stdout.fileHandleForReading.readabilityHandler = nil
        guard !stoppedByHost else { return }
        onExit?(status)
    }
}

/// Renders the view tree a process plugin returns. Node types: text, table, vstack.
final class DeclarativeViewController: NSViewController {
    private var dataSources: [TableSource] = []

    override func loadView() {
        view = NSView()
    }

    func render(_ node: Any) {
        dataSources.removeAll()
        let content = makeView(node)
        view.subviews.forEach { $0.removeFromSuperview() }
        view.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            content.topAnchor.constraint(equalTo: view.topAnchor),
            content.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func makeView(_ node: Any) -> NSView {
        guard let node = node as? [String: Any], let type = node["type"] as? String else { return label("Invalid view node") }
        switch type {
        case "text":
            return label(node["text"] as? String ?? "")
        case "vstack":
            let stack = NSStackView(views: (node["children"] as? [Any] ?? []).map(makeView))
            stack.orientation = .vertical
            stack.alignment = .leading
            stack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
            return stack
        case "table":
            let source = TableSource(columns: node["columns"] as? [String] ?? [], rows: node["rows"] as? [[String]] ?? [])
            dataSources.append(source)
            return source.makeScrollView()
        default:
            return label("Unsupported view node '\(type)'")
        }
    }

    private func label(_ text: String) -> NSTextField {
        NSTextField(wrappingLabelWithString: text)
    }

    private final class TableSource: NSObject, NSTableViewDataSource {
        let columns: [String]
        let rows: [[String]]

        init(columns: [String], rows: [[String]]) {
            self.columns = columns
            self.rows = rows
        }

        func makeScrollView() -> NSScrollView {
            let table = NSTableView()
            for (index, title) in columns.enumerated() {
                let column = NSTableColumn(identifier: .init("\(index)"))
                column.title = title
                table.addTableColumn(column)
            }
            table.usesAlternatingRowBackgroundColors = true
            table.style = .fullWidth
            table.dataSource = self
            let scrollView = NSScrollView()
            scrollView.documentView = table
            scrollView.hasVerticalScroller = true
            scrollView.hasHorizontalScroller = true
            return scrollView
        }

        func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

        func tableView(_ tableView: NSTableView, objectValueFor column: NSTableColumn?, row: Int) -> Any? {
            guard let index = column.flatMap({ Int($0.identifier.rawValue) }), index < rows[row].count else { return nil }
            return rows[row][index]
        }
    }
}
