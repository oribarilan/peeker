import AppKit

/// What to print: the table as shown.
nonisolated struct TablePrintContent: Sendable {
    let table: CSVTable
    /// Row 0 is the header row.
    let hasHeader: Bool
    /// File rows to print, in shown order, header row excluded.
    let rows: [Int]

    var repeatsHeader: Bool { hasHeader && table.rowCount > 0 }

    /// All columns but the hidden ones, or all of them when every one is hidden.
    func printedColumns(_ choices: TablePrintChoices) -> [Int] {
        let shown = (0..<table.columnCount).filter { !choices.hiddenColumns.contains($0) }
        return shown.isEmpty ? Array(0..<table.columnCount) : shown
    }

    /// The column's header cell, or Column 1, Column 2 and so on.
    func title(ofColumn column: Int) -> String {
        let header = repeatsHeader ? table.cell(row: 0, column: column) : ""
        return header.isEmpty ? "Column \(column + 1)" : header
    }

    /// The row's number as the table shows it.
    func rowNumber(_ fileRow: Int) -> Int { fileRow - (repeatsHeader ? 1 : 0) + 1 }
}

/// The print panel's choices; the document keeps the last ones while its window is open.
nonisolated struct TablePrintChoices: Equatable, Sendable {
    var showsRowNumbers = false
    var hiddenColumns: Set<Int> = []
}

/// Where a printout's rows fall: the grid shrunk to the page width, never enlarged, and whole rows on each page
/// under the repeated header row.
nonisolated struct TablePrintLayout: Equatable {
    /// A row's height at full size.
    static let rowHeight: CGFloat = 16
    /// The printed columns' widths at full size.
    let widths: [CGFloat]
    /// The printable part of a page.
    let page: CGSize
    let rowCount: Int
    let repeatsHeader: Bool

    var scale: CGFloat {
        let total = widths.reduce(0, +)
        return total > page.width ? page.width / total : 1
    }

    var rowsPerPage: Int {
        let lines = (page.height / (Self.rowHeight * scale) + 0.001).rounded(.down)
        return max(1, Int(lines) - (repeatsHeader ? 1 : 0))
    }

    var pageCount: Int { max(1, (rowCount + rowsPerPage - 1) / rowsPerPage) }

    /// The printed rows on a page counted from 0, as indexes into the rows to print.
    func rows(onPage index: Int) -> Range<Int> {
        let start = min(index * rowsPerPage, rowCount)
        return start..<min(start + rowsPerPage, rowCount)
    }
}

/// A table laid out for paper: it paginates itself, one band of whole rows per page, and draws black text on white
/// with light grid lines whatever the appearance.
final class TablePrintView: NSView {
    /// One printed row: its cells' text, row number first when shown.
    nonisolated struct Line: Equatable {
        var texts: [String]
        var isHeader: Bool
    }

    private static let font = NSFont.systemFont(ofSize: 10)
    private static let headerFont = NSFont.boldSystemFont(ofSize: 10)
    private static let numberFont = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
    private static let padding: CGFloat = 8
    private static let measuredRows = 1_000

    let content: TablePrintContent
    var choices: TablePrintChoices {
        didSet { paginate() }
    }
    private let printInfo: NSPrintInfo
    /// Each file column's width at full size, and the row number column's.
    private let naturalWidths: [CGFloat], numberWidth: CGFloat
    private var columns: [Int] = []
    private(set) var layout = TablePrintLayout(widths: [], page: .zero, rowCount: 0, repeatsHeader: false)

    init(content: TablePrintContent, choices: TablePrintChoices, info: NSPrintInfo) {
        self.content = content
        self.choices = choices
        printInfo = info
        (naturalWidths, numberWidth) = Self.measure(content)
        super.init(frame: .zero)
        appearance = NSAppearance(named: .aqua)
        paginate()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override var isFlipped: Bool { true }

    /// Lays out the pages for the paper and margins the print panel has now.
    func paginate() {
        let info = NSPrintOperation.current?.printInfo ?? printInfo
        let page = CGSize(width: info.paperSize.width - info.leftMargin - info.rightMargin,
                          height: info.paperSize.height - info.topMargin - info.bottomMargin)
        columns = content.printedColumns(choices)
        let widths = (choices.showsRowNumbers ? [numberWidth] : []) + columns.map { naturalWidths[$0] }
        layout = TablePrintLayout(widths: widths, page: page, rowCount: content.rows.count, repeatsHeader: content.repeatsHeader)
        setFrameSize(CGSize(width: page.width, height: page.height * CGFloat(layout.pageCount)))
        needsDisplay = true
    }

    override func knowsPageRange(_ range: NSRangePointer) -> Bool {
        paginate()
        range.pointee = NSRange(location: 1, length: layout.pageCount)
        return true
    }

    override func rectForPage(_ page: Int) -> NSRect {
        NSRect(x: 0, y: CGFloat(page - 1) * layout.page.height, width: layout.page.width, height: layout.page.height)
    }

    /// The lines page `index`, counted from 0, prints: the header row first when there is one.
    func lines(onPage index: Int) -> [Line] {
        let header = content.repeatsHeader ? [line(fileRow: 0, isHeader: true)] : []
        return header + layout.rows(onPage: index).map { line(fileRow: content.rows[$0], isHeader: false) }
    }

    private func line(fileRow: Int, isHeader: Bool) -> Line {
        let fields = content.table.fields(ofRow: fileRow)
        var texts = columns.map { $0 < fields.count ? Self.singleLine(fields[$0].text) : "" }
        if choices.showsRowNumbers { texts.insert(isHeader ? "" : "\(content.rowNumber(fileRow))", at: 0) }
        return Line(texts: texts, isHeader: isHeader)
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill()
        dirtyRect.fill()
        for page in 1...layout.pageCount where rectForPage(page).intersects(dirtyRect) { drawPage(page - 1) }
    }

    private func drawPage(_ index: Int) {
        let lines = lines(onPage: index), height = TablePrintLayout.rowHeight, scale = layout.scale
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        let transform = NSAffineTransform()
        transform.translateX(by: 0, yBy: CGFloat(index) * layout.page.height)
        transform.scale(by: scale)
        transform.concat()

        let numbered = choices.showsRowNumbers
        for (row, line) in lines.enumerated() {
            var x: CGFloat = 0
            for (column, text) in line.texts.enumerated() {
                let width = layout.widths[column]
                let rect = NSRect(x: x, y: CGFloat(row) * height, width: width, height: height)
                let style: [NSAttributedString.Key: Any] = numbered && column == 0 ? Self.numberStyle : line.isHeader ? Self.headerStyle : Self.cellStyle
                text.draw(in: rect.insetBy(dx: Self.padding / 2, dy: 2), withAttributes: style)
                x += width
            }
        }

        let grid = NSBezierPath(), right = layout.widths.reduce(0, +), bottom = CGFloat(lines.count) * height
        for row in 0...lines.count {
            grid.move(to: NSPoint(x: 0, y: CGFloat(row) * height))
            grid.line(to: NSPoint(x: right, y: CGFloat(row) * height))
        }
        var x: CGFloat = 0
        for width in [0] + layout.widths {
            x += width
            grid.move(to: NSPoint(x: x, y: 0))
            grid.line(to: NSPoint(x: x, y: bottom))
        }
        grid.lineWidth = 0.5 / scale
        NSColor(white: 0.8, alpha: 1).setStroke()
        grid.stroke()
    }

    private static func style(_ font: NSFont, color: NSColor = .black, alignment: NSTextAlignment = .natural) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        paragraph.alignment = alignment
        return [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
    }

    private static let cellStyle = style(font)
    private static let headerStyle = style(headerFont)
    private static let numberStyle = style(numberFont, color: NSColor(white: 0.4, alpha: 1), alignment: .right)

    // MARK: Measuring

    /// Column widths from the header row and the first rows to print, 30 to 300 points with padding.
    private static func measure(_ content: TablePrintContent) -> ([CGFloat], CGFloat) {
        let table = content.table
        var widths = [CGFloat](repeating: 0, count: table.columnCount)
        func fit(_ fields: [CSVField], font: NSFont) {
            for (column, field) in fields.enumerated() where !field.text.isEmpty && column < widths.count {
                // 200 characters are wider than the 300-point cap in any font this size, so the rest needn't be measured.
                let text = singleLine(String(field.text.prefix(200)))
                widths[column] = max(widths[column], (text as NSString).size(withAttributes: [.font: font]).width)
            }
        }
        if content.repeatsHeader { fit(table.fields(ofRow: 0), font: headerFont) }
        for row in content.rows.prefix(measuredRows) { fit(table.fields(ofRow: row), font: font) }
        let widest = "\(content.rows.map(content.rowNumber).max() ?? 0)" as NSString
        return (widths.map(clamped), clamped(widest.size(withAttributes: [.font: numberFont]).width))
    }

    private static func clamped(_ width: CGFloat) -> CGFloat { min(max((width + padding).rounded(.up), 30), 300) }

    private static func singleLine(_ text: String) -> String {
        text.contains(where: \.isNewline) ? text.split(whereSeparator: \.isNewline).joined(separator: " ") : text
    }
}

@MainActor enum TablePrinting {
    /// The print job, with the Table section in the print panel. `onChoicesChange` gets every change made there.
    static func job(_ content: TablePrintContent, choices: TablePrintChoices, info: NSPrintInfo,
                    onChoicesChange: @escaping (TablePrintChoices) -> Void) -> NSPrintOperation {
        info.isHorizontallyCentered = false
        info.isVerticallyCentered = false
        info.dictionary()[NSPrintInfo.AttributeKey.headerAndFooter] = true
        let options = TablePrintOptions(titles: (0..<content.table.columnCount).map(content.title(ofColumn:)), choices: choices)
        let view = TablePrintView(content: content, choices: options.choices, info: info)
        options.onChange = { [weak view] choices in
            view?.choices = choices
            onChoicesChange(choices)
        }
        let operation = NSPrintOperation(view: view, printInfo: info)
        operation.printPanel.addAccessoryController(options)
        return operation
    }
}
