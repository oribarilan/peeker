import AppKit

/// What a column's width and alignment come from: its title, its longest cells among the first rows, and whether
/// those cells are mostly numbers. Only the longest few cells are kept, so fitting 200 columns measures 600 strings
/// rather than 200,000.
nonisolated struct ColumnSample: Equatable, Sendable {
    /// How many rows below the header are looked at.
    static let sampledRows = 1_000
    /// How many of the longest cells are kept to measure.
    private static let kept = 3
    /// Cells are cut to this many characters before measuring: wider than any width cap at any size a table uses.
    private static let longestMeasured = 200

    var title = ""
    /// The longest cells by character count, on one line, longest first.
    var longest: [String] = []
    /// At least 80% of the non-empty cells sampled are numbers.
    var isNumeric = false

    /// One sample per column of `table`, from its header row (when `hasHeader`) and `rows`, the file rows below it
    /// in the order they're shown; at most `sampledRows` of them are read.
    static func sample(_ table: CSVTable, hasHeader: Bool, rows: some Sequence<Int>) -> [ColumnSample] {
        var samples = [ColumnSample](repeating: ColumnSample(), count: table.columnCount)
        var numbers = [Int](repeating: 0, count: table.columnCount), filled = numbers
        let locale = Locale.current, formatter = CSVTable.numberFormatter(locale)
        if hasHeader, table.rowCount > 0 {
            for (column, field) in table.fields(ofRow: 0).enumerated() where column < samples.count {
                samples[column].title = oneLine(field.text)
            }
        }
        for row in rows.prefix(sampledRows) {
            for (column, field) in table.fields(ofRow: row).enumerated() where column < samples.count && !field.text.isEmpty {
                filled[column] += 1
                if CSVTable.isNumber(field.text, locale: locale, formatter: formatter) { numbers[column] += 1 }
                samples[column].keep(oneLine(field.text))
            }
        }
        for column in samples.indices {
            samples[column].isNumeric = numbers[column] > 0 && numbers[column] * 5 >= filled[column] * 4
        }
        return samples
    }

    /// One sample per column, from the header row and the rows below it in file order.
    static func sample(_ table: CSVTable, hasHeader: Bool) -> [ColumnSample] {
        let first = hasHeader && table.rowCount > 0 ? 1 : 0
        return sample(table, hasHeader: hasHeader, rows: first..<min(table.rowCount, first + sampledRows))
    }

    /// The width that shows the kept cells whole, without padding.
    func cellsWidth(font: NSFont) -> CGFloat {
        longest.map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
    }

    func titleWidth(font: NSFont) -> CGFloat { (title as NSString).size(withAttributes: [.font: font]).width }

    /// Keeps `text` when it's among the longest seen.
    mutating func keep(_ text: String) {
        let length = text.utf16.count
        guard longest.count < Self.kept || length > longest[longest.count - 1].utf16.count else { return }
        let at = longest.firstIndex { $0.utf16.count < length } ?? longest.count
        longest.insert(text, at: at)
        if longest.count > Self.kept { longest.removeLast() }
    }

    /// A cell's text on one line, as a table draws it, cut to the most that's measured.
    private static func oneLine(_ text: String) -> String {
        let cut = String(text.prefix(longestMeasured))
        return cut.contains(where: \.isNewline) ? cut.split(whereSeparator: \.isNewline).joined(separator: " ") : cut
    }
}
