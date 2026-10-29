import AppKit
import PreviewPPKit
import UniformTypeIdentifiers

/// The bake-off format: the same CSV viewer also exists as a web plugin and a process plugin.
public final class CSVPlugin: Plugin {
    public static let manifest = PluginManifest(id: "csv", name: "CSV (native)", fileTypes: [.commaSeparatedText])

    public init() {}

    public func open(_ url: URL, host: any PluginHost) throws -> Viewer {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { throw PluginError.unreadable(url) }
        let rows = CSV.parse(text)
        let controller = CSVTableViewController(header: rows.first ?? [], rows: Array(rows.dropFirst()))
        return Viewer(content: controller, commands: [
            Command(id: "sort", title: "Sort by First Column", symbolName: "arrow.up.arrow.down") { controller.sortByFirstColumn() },
            Command(id: "simulate-crash", title: "Simulate Crash", symbolName: "ant") { fatalError("CSV plugin simulated crash") },
        ])
    }
}

final class CSVTableViewController: NSViewController, NSTableViewDataSource {
    private let header: [String]
    private var rows: [[String]]
    private let table = NSTableView()

    init(header: [String], rows: [[String]]) {
        self.header = header
        self.rows = rows
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func loadView() {
        for (index, title) in header.enumerated() {
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
        view = scrollView
    }

    func sortByFirstColumn() {
        rows.sort { ($0.first ?? "").localizedStandardCompare($1.first ?? "") == .orderedAscending }
        table.reloadData()
    }

    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, objectValueFor column: NSTableColumn?, row: Int) -> Any? {
        guard let index = column.flatMap({ Int($0.identifier.rawValue) }), index < rows[row].count else { return nil }
        return rows[row][index]
    }
}

enum CSV {
    /// RFC 4180: quoted fields may contain commas, newlines and doubled quotes.
    static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var quoted = false
        var iterator = text.makeIterator()
        while let char = iterator.next() {
            switch (char, quoted) {
            case ("\"", true):
                if let next = iterator.next() {
                    if next == "\"" { field.append("\"") } else {
                        quoted = false
                        handle(next, &field, &row, &rows, &quoted)
                    }
                } else { quoted = false }
            case (_, true): field.append(char)
            default: handle(char, &field, &row, &rows, &quoted)
            }
        }
        if !field.isEmpty || !row.isEmpty { row.append(field); rows.append(row) }
        return rows
    }

    private static func handle(_ char: Character, _ field: inout String, _ row: inout [String], _ rows: inout [[String]], _ quoted: inout Bool) {
        switch char {
        case "\"": quoted = true
        case ",": row.append(field); field = ""
        case "\n", "\r\n": row.append(field); rows.append(row); row = []; field = ""
        case "\r": break
        default: field.append(char)
        }
    }
}
