import Foundation

/// The separators the table reads and writes.
nonisolated enum Delimiter: String, CaseIterable, Codable, Sendable {
    case comma = ",", semicolon = ";", tab = "\t", pipe = "|"

    var byte: UInt8 { rawValue.utf8.first! }
}

/// A cell as the file held it: its text, and whether it was quoted, so saving can quote it again.
nonisolated struct CSVField: Equatable, Sendable {
    var text: String
    var quoted = false
}

/// One record: still the range of the file's text it was read from, or fields that changed. A record is a line,
/// unless a quoted field holds a line break.
nonisolated struct CSVRow: Sendable {
    fileprivate enum Storage: Sendable {
        /// Byte offsets into the table's UTF-8 text.
        case original(Range<Int>, fieldCount: Int)
        case edited([CSVField])
    }
    fileprivate var storage: Storage

    fileprivate var fieldCount: Int {
        switch storage {
        case .original(_, let count): count
        case .edited(let fields): fields.count
        }
    }
}

/// A CSV file as a table. It keeps the file's text and the range of each record, and parses a record's fields only
/// when they're asked for, so a large file opens without building every cell; records that never change are written
/// back exactly as read.
nonisolated struct CSVTable: Sendable {
    let text: String
    let delimiter: Delimiter
    /// The records, in file order. Settable as a whole, for undoing a change that touched every row.
    var rows: [CSVRow] {
        didSet { columnCount = rows.lazy.map(\.fieldCount).max() ?? 0 }
    }
    /// The widest record's field count.
    private(set) var columnCount: Int
    /// Whether the text ended with a line break, kept when saving.
    let endsWithLineBreak: Bool

    init(text: String, delimiter: Delimiter) {
        self.text = text
        self.delimiter = delimiter
        let (rows, endsWithBreak) = Self.index(text, delimiter: delimiter.byte)
        self.rows = rows
        endsWithLineBreak = endsWithBreak
        columnCount = rows.lazy.map(\.fieldCount).max() ?? 0
    }

    var rowCount: Int { rows.count }

    /// An empty record, for adding a row.
    static let emptyRow = CSVRow(storage: .edited([]))

    func fields(ofRow row: Int) -> [CSVField] {
        switch rows[row].storage {
        case .original(let range, _): bytes { Self.parse(UnsafeBufferPointer(rebasing: $0[range]), delimiter: delimiter.byte) }
        case .edited(let fields): fields
        }
    }

    /// A cell's text; empty past the end of a short row.
    func cell(row: Int, column: Int) -> String {
        let fields = fields(ofRow: row)
        return column < fields.count ? fields[column].text : ""
    }

    // MARK: Changes

    mutating func setCell(_ value: String, row: Int, column: Int) {
        var fields = fields(ofRow: row)
        while fields.count <= column { fields.append(CSVField(text: "")) }
        fields[column].text = value
        rows[row].storage = .edited(fields)
    }

    /// Removes the records at `indexes`, returning them in order for `insertRows` to put back as they were.
    mutating func removeRows(at indexes: IndexSet) -> [CSVRow] {
        let removed = indexes.map { rows[$0] }
        rows = rows.indices.filter { !indexes.contains($0) }.map { rows[$0] }  // one assignment, however many rows
        return removed
    }

    /// Inserts `newRows` so they end up at `indexes`, one each, in order.
    mutating func insertRows(_ newRows: [CSVRow], at indexes: IndexSet) {
        var merged: [CSVRow] = [], old = rows[...], new = newRows[...]
        merged.reserveCapacity(rows.count + newRows.count)
        while !old.isEmpty || !new.isEmpty {
            if indexes.contains(merged.count), let next = new.popFirst() { merged.append(next) } else if let next = old.popFirst() { merged.append(next) } else { merged.append(new.removeFirst()) }
        }
        rows = merged
    }

    /// Moves the records at `indexes` to before the record now at `destination`, keeping their order.
    mutating func moveRows(from indexes: IndexSet, to destination: Int) {
        let moving = indexes.map { rows[$0] }
        var kept = rows.indices.filter { !indexes.contains($0) }.map { rows[$0] }
        kept.insert(contentsOf: moving, at: destination - indexes.count(in: 0..<destination))
        rows = kept
    }

    /// An empty column at `index` in every row, padding short rows up to it.
    mutating func insertColumn(at index: Int) {
        rows = (0..<rowCount).map { row in
            var fields = fields(ofRow: row)
            while fields.count < index { fields.append(CSVField(text: "")) }
            fields.insert(CSVField(text: ""), at: index)
            return CSVRow(storage: .edited(fields))
        }
    }

    /// Removes the columns at `indexes` from every row, in one pass.
    mutating func removeColumns(at indexes: IndexSet) {
        rows = (0..<rowCount).map { row in
            let fields = fields(ofRow: row)
            return CSVRow(storage: .edited(fields.indices.filter { !indexes.contains($0) }.map { fields[$0] }))
        }
    }

    /// Moves a column so it ends up at `destination`.
    mutating func moveColumn(from source: Int, to destination: Int) {
        let width = columnCount
        rows = (0..<rowCount).map { row in
            var fields = fields(ofRow: row)
            while fields.count < width { fields.append(CSVField(text: "")) }
            fields.insert(fields.remove(at: source), at: destination)
            return CSVRow(storage: .edited(fields))
        }
    }

    // MARK: Writing

    /// The table as CSV text: unchanged records as read, changed ones quoted where they need it or were quoted.
    func serialized(lineEnding: String) -> String {
        var out: [UInt8] = []
        out.reserveCapacity(text.utf8.count + 64)
        let separator = delimiter.rawValue, ending = Array(lineEnding.utf8)
        bytes { source in
            for (index, row) in rows.enumerated() {
                if index > 0 { out += ending }
                switch row.storage {
                case .original(let range, _): out += source[range]
                case .edited(let fields): out += fields.map { escaped($0, separator: separator) }.joined(separator: separator).utf8
                }
            }
        }
        // An empty last record needs its line break, or it's gone when the file is read again.
        if !rows.isEmpty, endsWithLineBreak || out.isEmpty || out.suffix(ending.count).elementsEqual(ending) { out += ending }
        return String(decoding: out, as: UTF8.self)
    }

    /// The text's UTF-8 bytes. `load` makes the text contiguous, so the copy is only for a table built otherwise.
    private func bytes<T>(_ body: (UnsafeBufferPointer<UInt8>) -> T) -> T {
        Self.bytes(of: text, body)
    }

    private static func bytes<T>(of text: String, _ body: (UnsafeBufferPointer<UInt8>) -> T) -> T {
        if let result = text.utf8.withContiguousStorageIfAvailable(body) { return result }
        return Array(text.utf8).withUnsafeBufferPointer(body)
    }

    private func escaped(_ field: CSVField, separator: String) -> String {
        let needs = field.quoted || field.text.contains(separator) || field.text.contains("\"")
            || field.text.contains("\n") || field.text.contains("\r")
        return needs ? "\"" + field.text.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : field.text
    }

    // MARK: Reading

    private static let quote = UInt8(ascii: "\""), newline = UInt8(ascii: "\n"), carriageReturn = UInt8(ascii: "\r")

    /// One pass over the bytes: each record's range (without its line break) and field count.
    private static func index(_ text: String, delimiter: UInt8) -> ([CSVRow], Bool) {
        bytes(of: text) { utf8 in
            var rows: [CSVRow] = []
            var start = 0, index = 0, inQuotes = false, atFieldStart = true, fields = 1
            let count = utf8.count
            while index < count {
                let byte = utf8[index]
                if inQuotes {
                    if byte == quote {
                        if index + 1 < count, utf8[index + 1] == quote {
                            index += 2  // a doubled quote stays inside
                            continue
                        }
                        inQuotes = false
                    }
                } else if byte == quote, atFieldStart {
                    inQuotes = true  // as `parse` reads it: only a quote opening a field starts quoting
                } else if byte == delimiter {
                    fields += 1
                    atFieldStart = true
                    index += 1
                    continue
                } else if byte == newline || byte == carriageReturn {
                    rows.append(CSVRow(storage: .original(start..<index, fieldCount: fields)))
                    index += byte == carriageReturn && index + 1 < count && utf8[index + 1] == newline ? 2 : 1
                    start = index
                    fields = 1
                    atFieldStart = true
                    continue
                }
                atFieldStart = false
                index += 1
            }
            let endsWithBreak = start == count && !rows.isEmpty
            if start < count { rows.append(CSVRow(storage: .original(start..<count, fieldCount: fields))) }
            return (rows, endsWithBreak)
        }
    }

    /// A record's fields. A quote opening a field starts a quoted field, where `""` is a quote and line breaks stay; a
    /// quote anywhere else is text, and a field missing its closing quote runs to the end of the record.
    static func parse(_ bytes: UnsafeBufferPointer<UInt8>, delimiter: UInt8) -> [CSVField] {
        var fields: [CSVField] = []
        var current: [UInt8] = [], quoted = false, inQuotes = false, atFieldStart = true
        var index = bytes.startIndex
        while index < bytes.endIndex {
            let byte = bytes[index]
            if inQuotes {
                if byte == quote {
                    let next = bytes.index(after: index)
                    if next < bytes.endIndex, bytes[next] == quote {
                        current.append(quote)
                        index = bytes.index(after: next)
                        continue
                    }
                    inQuotes = false
                } else {
                    current.append(byte)
                }
            } else if byte == delimiter {
                fields.append(CSVField(text: String(decoding: current, as: UTF8.self), quoted: quoted))
                current.removeAll(keepingCapacity: true)
                quoted = false
                atFieldStart = true
                index = bytes.index(after: index)
                continue
            } else if byte == quote, atFieldStart {
                quoted = true
                inQuotes = true
            } else {
                current.append(byte)
            }
            atFieldStart = false
            index = bytes.index(after: index)
        }
        fields.append(CSVField(text: String(decoding: current, as: UTF8.self), quoted: quoted))
        return fields
    }

    // MARK: Guesses

    /// The delimiter the first lines agree on: the candidate found on the most of them with the same non-zero count
    /// outside quotes, ties going in `Delimiter.allCases` order; comma when none is found.
    static func guessDelimiter(in text: String) -> Delimiter {
        var best: (delimiter: Delimiter, lines: Int) = (.comma, 0)
        for delimiter in Delimiter.allCases {
            let counts = index(String(text.prefix(64 * 1024)), delimiter: delimiter.byte).0.prefix(20).map { $0.fieldCount - 1 }
            let common = Dictionary(grouping: counts.filter { $0 > 0 }, by: { $0 }).values.map(\.count).max() ?? 0
            // A tie goes to the earlier delimiter, except that semicolons beat commas: a semicolon file writes decimal commas.
            if common > best.lines || (common == best.lines && common > 0 && delimiter == .semicolon && best.delimiter == .comma) { best = (delimiter, common) }
        }
        return best.delimiter
    }

    /// Whether the first row reads as a header: every field text, and a column below it mostly numbers; or a file of
    /// one row.
    func guessHeader(locale: Locale = .current) -> Bool {
        guard rowCount > 0 else { return false }
        guard rowCount > 1 else { return true }
        let formatter = Self.numberFormatter(locale)
        let first = fields(ofRow: 0).map(\.text)
        guard first.allSatisfy({ !$0.isEmpty && !Self.isNumber($0, locale: locale, formatter: formatter) }) else { return false }
        let sample = (1..<min(rowCount, 50)).map { fields(ofRow: $0).map(\.text) }
        return (0..<columnCount).contains { column in
            let values = sample.compactMap { column < $0.count && !$0[column].isEmpty ? $0[column] : nil }
            return !values.isEmpty && values.filter { Self.isNumber($0, locale: locale, formatter: formatter) }.count * 2 >= values.count
        }
    }

    /// A number in POSIX form, with a decimal comma, or in the locale's form; `formatter` is reused across many calls.
    static func isNumber(_ text: String, locale: Locale, formatter: NumberFormatter? = nil) -> Bool {
        number(text, locale: locale, formatter: formatter) != nil
    }

    static func number(_ text: String, locale: Locale, formatter: NumberFormatter? = nil) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let value: Double?
        if let plain = Double(trimmed) {
            value = plain
        } else if trimmed.filter({ $0 == "," }).count == 1, !trimmed.contains(".") {
            // A decimal comma, as semicolon-separated files write numbers, whatever the Mac's own locale.
            value = Double(trimmed.replacingOccurrences(of: ",", with: "."))
        } else {
            value = (formatter ?? numberFormatter(locale)).number(from: trimmed)?.doubleValue
        }
        return value.flatMap { $0.isFinite ? $0 : nil }  // "nan" and "inf" read as text
    }

    static func numberFormatter(_ locale: Locale) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        return formatter
    }
}
