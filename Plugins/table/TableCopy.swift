import Foundation

/// Selected cells as text in the format the copy sheet offers.
nonisolated enum TableCopy {
    enum Format: String, CaseIterable, Sendable {
        case tabs, commas, semicolons, markdown

        var title: String {
            switch self {
            case .tabs: "Tabs"
            case .commas: "Commas"
            case .semicolons: "Semicolons"
            case .markdown: "Markdown table"
            }
        }
    }

    /// `rows` of cells, with `header`'s titles first when given, one line per row.
    static func text(rows: [[String]], header: [String]?, format: Format) -> String {
        if format == .markdown { return markdown(rows: rows, header: header) }
        let separator = format == .tabs ? "\t" : format == .commas ? "," : ";"
        var out = ""
        out.reserveCapacity(rows.count * 32)
        for (index, line) in ((header.map { [$0] } ?? []) + rows).enumerated() {
            if index > 0 { out += "\n" }
            for (column, cell) in line.enumerated() {
                if column > 0 { out += separator }
                out += CSVTable.quoted(cell, separator: separator)
            }
        }
        return out
    }

    /// A Markdown table: the titles (empty without a header), a `---` row, then the rows, with `|` escaped and line
    /// breaks turned into spaces, since a cell is one line.
    private static func markdown(rows: [[String]], header: [String]?) -> String {
        let columns = header?.count ?? rows.first?.count ?? 0
        var out = ""
        out.reserveCapacity(rows.count * 40)
        func add(_ cells: [String]) {
            out += "|"
            for cell in cells {
                out += " "
                // Most cells need nothing; checking the bytes first keeps a large copy fast.
                let plain = !cell.utf8.contains { $0 == UInt8(ascii: "|") || $0 == UInt8(ascii: "\n") || $0 == UInt8(ascii: "\r") }
                out += plain ? cell : cell.replacingOccurrences(of: "|", with: "\\|").split(whereSeparator: \.isNewline).joined(separator: " ")
                out += " |"
            }
        }
        add(header ?? Array(repeating: "", count: columns))
        out += "\n"
        add(Array(repeating: "---", count: columns))
        for row in rows {
            out += "\n"
            add(row)
        }
        return out
    }
}
