import AppKit
import PeekerKit

/// The sheet Copy shows for more than one cell: a format, Include header row when the table has one, and a preview
/// of the text. The choices it copies with are remembered for the next time.
final class TableCopySheet: NSObject {
    /// How many rows the preview shows before an ellipsis.
    static let previewRows = 20

    let rows: [[String]]
    let header: [String]?
    private let preferences: PluginPreferences?
    private(set) var format: TableCopy.Format
    private(set) var includesHeader: Bool
    let formatPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    /// Include header row; nil when the table shows no header row.
    let headerBox: NSButton?
    let previewText = NSTextView()

    init(rows: [[String]], header: [String]?, preferences: PluginPreferences?) {
        self.rows = rows
        self.header = header
        self.preferences = preferences
        format = preferences?.string("copyFormat").flatMap(TableCopy.Format.init(rawValue:)) ?? .tabs
        includesHeader = preferences?.bool("copyHeader") ?? true
        headerBox = header == nil ? nil : NSButton(checkboxWithTitle: "Include header row", target: nil, action: nil)
        super.init()
        formatPopUp.addItems(withTitles: TableCopy.Format.allCases.map(\.title))
        formatPopUp.selectItem(withTitle: format.title)
        formatPopUp.target = self
        formatPopUp.action = #selector(formatChosen(_:))
        headerBox?.state = includesHeader ? .on : .off
        headerBox?.target = self
        headerBox?.action = #selector(headerToggled(_:))
        previewText.isEditable = false
        previewText.font = .monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        // Tabs line up as columns; the default stops sit so close that "name<tab>price" reads as one word.
        let columns = NSMutableParagraphStyle()
        columns.tabStops = []
        columns.defaultTabInterval = 88
        previewText.defaultParagraphStyle = columns
        previewText.string = preview
    }

    /// The text Copy puts on the clipboard with the current choices.
    var text: String { TableCopy.text(rows: rows, header: includesHeader ? header : nil, format: format) }

    /// The text's first rows, with an ellipsis when there are more.
    var preview: String {
        let shown = TableCopy.text(rows: Array(rows.prefix(Self.previewRows)), header: includesHeader ? header : nil, format: format)
        return rows.count > Self.previewRows ? shown + "\n…" : shown
    }

    func choose(_ format: TableCopy.Format) {
        self.format = format
        formatPopUp.selectItem(withTitle: format.title)
        previewText.string = preview
    }

    func setIncludesHeader(_ on: Bool) {
        includesHeader = on
        headerBox?.state = on ? .on : .off
        previewText.string = preview
    }

    /// Remembers the choices and returns the text to copy.
    func copy() -> String {
        preferences?.set(format.rawValue, for: "copyFormat")
        preferences?.set(includesHeader, for: "copyHeader")
        return text
    }

    /// Shows the sheet on `window`; `completion` gets the text when the user clicks Copy (or presses Return).
    func begin(on window: NSWindow, completion: @escaping (String) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Copy \(rows.count == 1 ? "1 row" : "\(rows.count) rows")"
        alert.addButton(withTitle: "Copy")
        alert.addButton(withTitle: "Cancel")
        alert.accessoryView = accessory()
        alert.beginSheetModal(for: window) { response in
            if response == .alertFirstButtonReturn { completion(self.copy()) }
        }
    }

    /// The format pop-up, the header checkbox and the preview, stacked.
    private func accessory() -> NSView {
        let label = NSTextField(labelWithString: "Format:")
        let formatRow = NSStackView(views: [label, formatPopUp])
        let scroll = NSScrollView()
        scroll.documentView = previewText
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.borderType = .bezelBorder
        previewText.isHorizontallyResizable = true
        previewText.textContainer?.widthTracksTextView = false
        previewText.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.widthAnchor.constraint(equalToConstant: 380).isActive = true
        scroll.heightAnchor.constraint(equalToConstant: 140).isActive = true
        let stack = NSStackView(views: [formatRow] + (headerBox.map { [$0] } ?? []) + [scroll])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.frame.size = stack.fittingSize
        previewText.frame = NSRect(x: 0, y: 0, width: 380, height: 140)
        return stack
    }

    @objc private func formatChosen(_ sender: NSPopUpButton) {
        choose(TableCopy.Format.allCases[max(sender.indexOfSelectedItem, 0)])
    }

    @objc private func headerToggled(_ sender: NSButton) {
        setIncludesHeader(sender.state == .on)
    }
}
